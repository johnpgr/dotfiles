import {
    artifactPaths,
    canonicalizeCwd,
    cleanupRetention,
    createArtifacts,
    loadProjectMetadata,
    newJobId,
    projectIdFor,
    writeMetadataAtomic,
} from "./artifacts.ts";
import type {
    ArtifactPaths,
    DelegateBackend,
    DelegateJobMetadata,
    DelegateName,
    DelegateProfile,
    DelegatesConfig,
} from "./types.ts";

interface ManagedJob {
    metadata: DelegateJobMetadata;
    artifacts: ArtifactPaths;
    backend: DelegateBackend;
    controller?: AbortController;
    runPromise?: Promise<void>;
    stopReason?: "user" | "timeout" | "shutdown";
    delivered: boolean;
}

export interface SubmitJob {
    delegate: DelegateName;
    profile: DelegateProfile;
    dangerousBypass: boolean;
    task: string;
    cwd: string;
}

export interface DelegateManagerOptions {
    config: DelegatesConfig;
    backends: Record<DelegateName, DelegateBackend>;
    onChange?: () => void;
    afterSettle?: (
        metadata: DelegateJobMetadata,
        artifacts: ArtifactPaths,
        signal: AbortSignal,
    ) => Promise<void>;
    onSettled?: (metadata: DelegateJobMetadata, artifacts: ArtifactPaths) => void;
}

function settleFromStopReason(stopReason: "user" | "timeout" | "shutdown") {
    if (stopReason === "timeout") {
        return { status: "error" as const, error: "Delegate timed out." };
    }
    if (stopReason === "shutdown") {
        return { status: "stopped" as const, error: "Stopped during Pi session shutdown." };
    }
    return { status: "stopped" as const, error: "Delegate was stopped." };
}

export class DelegateManager {
    readonly #jobs = new Map<string, ManagedJob>();
    readonly #queue: string[] = [];
    readonly #config: DelegatesConfig;
    readonly #backends: Record<DelegateName, DelegateBackend>;
    readonly #onChange: (() => void) | undefined;
    readonly #afterSettle: DelegateManagerOptions["afterSettle"] | undefined;
    readonly #onSettled: DelegateManagerOptions["onSettled"] | undefined;
    #shuttingDown = false;
    #submissions = 0;

    constructor(options: DelegateManagerOptions) {
        this.#config = options.config;
        this.#backends = options.backends;
        this.#onChange = options.onChange;
        this.#afterSettle = options.afterSettle;
        this.#onSettled = options.onSettled;
    }

    async recover(cwd: string) {
        const canonicalCwd = await canonicalizeCwd(cwd);
        const projectId = projectIdFor(canonicalCwd);
        await cleanupRetention(projectId, this.#config.artifactRetentionDays);
        const metadata = await loadProjectMetadata(projectId, this.#config.maxTracked);
        for (const item of metadata.reverse()) {
            if (item.status === "queued" || item.status === "running") {
                item.status = "stopped";
                item.settledAt = Date.now();
                item.error = "Interrupted before Pi could record a clean shutdown.";
                await writeMetadataAtomic(artifactPaths(projectId, item.id).metadata, item);
            }
            this.#jobs.set(item.id, {
                metadata: item,
                artifacts: artifactPaths(projectId, item.id),
                backend: this.#backends[item.delegate],
                delivered: true,
            });
        }
        this.#pruneSettled();
        this.#notify();
    }

    list() {
        return [...this.#jobs.values()]
            .map((job) => ({ ...job.metadata }))
            .sort((left, right) => right.createdAt - left.createdAt);
    }

    get(id: string) {
        const job = this.#jobs.get(id);
        return job ? { metadata: { ...job.metadata }, artifacts: { ...job.artifacts } } : undefined;
    }

    async submit(input: SubmitJob) {
        if (this.#shuttingDown) throw new Error("Delegate manager is shutting down.");
        this.#pruneSettled();
        if (this.#jobs.size + this.#submissions >= this.#config.maxTracked) {
            throw new Error(`All ${this.#config.maxTracked} tracked delegate slots are unsettled.`);
        }
        // Reserve before the first await so concurrent command handlers cannot
        // race past maxTracked while canonicalizing paths or creating artifacts.
        this.#submissions++;
        try {
            const canonicalCwd = await canonicalizeCwd(input.cwd);
            if (this.#shuttingDown) throw new Error("Delegate manager is shutting down.");
            const id = newJobId();
            const projectId = projectIdFor(canonicalCwd);
            const artifacts = artifactPaths(projectId, id);
            await createArtifacts(artifacts, input.task);
            const metadata: DelegateJobMetadata = {
                id,
                delegate: input.delegate,
                profile: input.profile,
                dangerousBypass: input.dangerousBypass,
                task: input.task,
                cwd: canonicalCwd,
                projectId,
                status: "queued",
                createdAt: Date.now(),
                warnings: [],
                contextSources: [],
            };
            await writeMetadataAtomic(artifacts.metadata, metadata);
            const job: ManagedJob = {
                metadata,
                artifacts,
                backend: this.#backends[input.delegate],
                delivered: false,
            };
            this.#jobs.set(id, job);
            this.#queue.push(id);
            this.#notify();
            this.#pump();
            return { ...metadata };
        } finally {
            this.#submissions--;
        }
    }

    async stop(id: string) {
        const job = this.#jobs.get(id);
        if (!job) throw new Error(`Unknown delegate job: ${id}`);
        if (job.metadata.status === "queued") {
            job.stopReason = "user";
            this.#removeFromQueue(id);
            await this.#settleStopped(job, "Stopped before launch.");
            this.#pump();
            return;
        }
        if (job.metadata.status !== "running") return;
        job.stopReason = "user";
        job.controller?.abort();
        await job.runPromise;
    }

    async shutdown() {
        if (this.#shuttingDown) return;
        this.#shuttingDown = true;
        const queued = this.#queue.splice(0);
        await Promise.all(
            queued.map(async (id) => {
                const job = this.#jobs.get(id);
                if (!job || job.metadata.status !== "queued") return;
                job.stopReason = "shutdown";
                await this.#settleStopped(job, "Stopped during Pi session shutdown.");
            }),
        );
        const running = [...this.#jobs.values()].filter((job) => job.metadata.status === "running");
        for (const job of running) {
            job.stopReason = "shutdown";
            job.controller?.abort();
        }
        await Promise.allSettled(running.map((job) => job.runPromise));
        this.#notify();
    }

    #runningJobs() {
        return [...this.#jobs.values()].filter((job) => job.metadata.status === "running");
    }

    #eligible(job: ManagedJob) {
        if (job.metadata.profile !== "implementation") return true;
        return !this.#runningJobs().some(
            (running) =>
                running.metadata.profile === "implementation" &&
                running.metadata.cwd === job.metadata.cwd,
        );
    }

    #pump() {
        if (this.#shuttingDown) return;
        while (this.#runningJobs().length < this.#config.maxConcurrent) {
            const queueIndex = this.#queue.findIndex((id) => {
                const job = this.#jobs.get(id);
                return job?.metadata.status === "queued" && this.#eligible(job);
            });
            if (queueIndex < 0) return;
            const [id] = this.#queue.splice(queueIndex, 1);
            const job = id ? this.#jobs.get(id) : undefined;
            if (!job) continue;
            job.metadata.status = "running";
            job.metadata.startedAt = Date.now();
            job.controller = new AbortController();
            this.#notify();
            job.runPromise = this.#run(job);
        }
    }

    async #run(job: ManagedJob) {
        const controller = job.controller;
        if (!controller) return;
        const delegateConfig = this.#config.delegates[job.metadata.delegate];
        const timeout = setTimeout(() => {
            if (job.metadata.status !== "running") return;
            job.stopReason = "timeout";
            controller.abort();
        }, delegateConfig.timeoutMinutes * 60_000);
        timeout.unref();
        try {
            await writeMetadataAtomic(job.artifacts.metadata, job.metadata);
            const outcome = await job.backend.start(
                {
                    id: job.metadata.id,
                    task: job.metadata.task,
                    cwd: job.metadata.cwd,
                    profile: job.metadata.profile,
                    dangerousBypass: job.metadata.dangerousBypass,
                    timeoutMs: delegateConfig.timeoutMinutes * 60_000,
                    artifacts: job.artifacts,
                },
                controller.signal,
                (pid) => {
                    if (pid) job.metadata.pid = pid;
                },
            );
            if (job.stopReason) {
                const settled = settleFromStopReason(job.stopReason);
                job.metadata.status = settled.status;
                job.metadata.error = settled.error;
            } else if (outcome.error || (outcome.exitCode ?? 0) !== 0) {
                job.metadata.status = "error";
                job.metadata.error =
                    outcome.error ?? `Delegate exited with code ${outcome.exitCode}.`;
            } else {
                job.metadata.status = "done";
            }
            if (outcome.exitCode !== undefined) job.metadata.exitCode = outcome.exitCode;
            if (outcome.signal) job.metadata.signal = outcome.signal;
        } catch (error) {
            if (job.stopReason) {
                const settled = settleFromStopReason(job.stopReason);
                job.metadata.status = settled.status;
                job.metadata.error = settled.error;
            } else {
                job.metadata.status = "error";
                job.metadata.error = error instanceof Error ? error.message : String(error);
            }
        } finally {
            clearTimeout(timeout);
            job.metadata.settledAt = Date.now();
            await writeMetadataAtomic(job.artifacts.metadata, job.metadata).catch(() => {});
            if (!this.#shuttingDown && this.#afterSettle) {
                try {
                    // Job abort (stop/timeout) must not skip indexing of artifacts
                    // already on disk; use a fresh signal independent of the run.
                    await this.#afterSettle(
                        job.metadata,
                        job.artifacts,
                        new AbortController().signal,
                    );
                } catch (error) {
                    job.metadata.warnings.push(
                        `Post-processing failed: ${error instanceof Error ? error.message : String(error)}`,
                    );
                }
                await writeMetadataAtomic(job.artifacts.metadata, job.metadata).catch(() => {});
            }
            if (!this.#shuttingDown && !job.delivered) {
                job.delivered = true;
                this.#onSettled?.({ ...job.metadata }, { ...job.artifacts });
            }
            this.#notify();
            this.#pump();
        }
    }

    async #settleStopped(job: ManagedJob, message: string) {
        if (job.metadata.status !== "queued") return;
        job.metadata.status = "stopped";
        job.metadata.error = message;
        job.metadata.settledAt = Date.now();
        await writeMetadataAtomic(job.artifacts.metadata, job.metadata).catch(() => {});
        if (!this.#shuttingDown && !job.delivered) {
            job.delivered = true;
            this.#onSettled?.({ ...job.metadata }, { ...job.artifacts });
        }
        this.#notify();
    }

    #removeFromQueue(id: string) {
        const index = this.#queue.indexOf(id);
        if (index >= 0) this.#queue.splice(index, 1);
    }

    #pruneSettled() {
        if (this.#jobs.size < this.#config.maxTracked) return;
        const settled = [...this.#jobs.values()]
            .filter((job) => job.metadata.settledAt !== undefined)
            .sort(
                (left, right) => (left.metadata.settledAt ?? 0) - (right.metadata.settledAt ?? 0),
            );
        while (this.#jobs.size >= this.#config.maxTracked && settled.length > 0) {
            const job = settled.shift();
            if (job) this.#jobs.delete(job.metadata.id);
        }
    }

    #notify() {
        this.#onChange?.();
    }
}

export function artifactForMetadata(metadata: DelegateJobMetadata) {
    return artifactPaths(metadata.projectId, metadata.id);
}
