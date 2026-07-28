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
import { exitFailure } from "./process.ts";
import {
    Err,
    Ok,
    Success,
    Try,
    TryResult,
    ignore,
    type DelegateError,
    type Result,
    type Unit,
} from "./result.ts";
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
    private readonly jobs = new Map<string, ManagedJob>();
    private readonly queue: string[] = [];
    private readonly config: DelegatesConfig;
    private readonly backends: Record<DelegateName, DelegateBackend>;
    private readonly onChange: (() => void) | undefined;
    private readonly afterSettle: DelegateManagerOptions["afterSettle"] | undefined;
    private readonly onSettled: DelegateManagerOptions["onSettled"] | undefined;
    private shuttingDown = false;
    private submissions = 0;
    private readonly waiters = new Map<string, Set<() => void>>();

    constructor(options: DelegateManagerOptions) {
        this.config = options.config;
        this.backends = options.backends;
        this.onChange = options.onChange;
        this.afterSettle = options.afterSettle;
        this.onSettled = options.onSettled;
    }

    async recover(cwd: string): Promise<Result<Unit>> {
        const canonical = await canonicalizeCwd(cwd);
        if (!canonical.ok) return canonical;
        const projectId = projectIdFor(canonical.path);
        const retention = await cleanupRetention(projectId, this.config.artifactRetentionDays);
        if (!retention.ok) return retention;
        const loaded = await loadProjectMetadata(projectId, this.config.maxTracked);
        if (!loaded.ok) return loaded;
        for (const item of loaded.jobs.reverse()) {
            if (item.status === "queued" || item.status === "running") {
                item.status = "stopped";
                item.settledAt = Date.now();
                item.error = "Interrupted before Pi could record a clean shutdown.";
                const written = await writeMetadataAtomic(
                    artifactPaths(projectId, item.id).metadata,
                    item,
                );
                if (!written.ok) return written;
            }
            this.jobs.set(item.id, {
                metadata: item,
                artifacts: artifactPaths(projectId, item.id),
                backend: this.backends[item.delegate],
                delivered: true,
            });
        }
        this.pruneSettled();
        this.notify();
        return Success;
    }

    list() {
        return [...this.jobs.values()]
            .map((job) => ({ ...job.metadata }))
            .sort((left, right) => right.createdAt - left.createdAt);
    }

    get(id: string) {
        const job = this.jobs.get(id);
        return job ? { metadata: { ...job.metadata }, artifacts: { ...job.artifacts } } : undefined;
    }

    require(id: string): Result<{ metadata: DelegateJobMetadata; artifacts: ArtifactPaths }> {
        const job = this.jobs.get(id);
        if (!job) return Err({ message: `Unknown delegate job: ${id}` });
        return Ok({ metadata: { ...job.metadata }, artifacts: { ...job.artifacts } });
    }

    async submit(input: SubmitJob): Promise<Result<{ metadata: DelegateJobMetadata }>> {
        if (this.shuttingDown) {
            return Err({ message: "Delegate manager is shutting down." });
        }
        this.pruneSettled();
        if (this.jobs.size + this.submissions >= this.config.maxTracked) {
            return Err({
                message: `All ${this.config.maxTracked} tracked delegate slots are unsettled.`,
            });
        }
        // Reserve before the first await so concurrent command handlers cannot
        // race past maxTracked while canonicalizing paths or creating artifacts.
        this.submissions++;
        try {
            const canonical = await canonicalizeCwd(input.cwd);
            if (!canonical.ok) return canonical;
            if (this.shuttingDown) {
                return Err({ message: "Delegate manager is shutting down." });
            }
            const id = newJobId();
            const projectId = projectIdFor(canonical.path);
            const artifacts = artifactPaths(projectId, id);
            const created = await createArtifacts(artifacts, input.task);
            if (!created.ok) return created;
            const metadata: DelegateJobMetadata = {
                id,
                delegate: input.delegate,
                profile: input.profile,
                dangerousBypass: input.dangerousBypass,
                task: input.task,
                cwd: canonical.path,
                projectId,
                status: "queued",
                createdAt: Date.now(),
                warnings: [],
                contextSources: [],
            };
            const written = await writeMetadataAtomic(artifacts.metadata, metadata);
            if (!written.ok) return written;
            const job: ManagedJob = {
                metadata,
                artifacts,
                backend: this.backends[input.delegate],
                delivered: false,
            };
            this.jobs.set(id, job);
            this.queue.push(id);
            this.notify();
            this.pump();
            return Ok({ metadata: { ...metadata } });
        } finally {
            this.submissions--;
        }
    }

    async waitFor(
        ids: string[],
        onProgress?: (pending: string[]) => void,
        signal?: AbortSignal,
    ): Promise<Result<Unit>> {
        const unique = [...new Set(ids)];
        if (unique.length === 0) {
            return Err({ message: "Provide at least one delegate job id." });
        }
        for (const id of unique) {
            if (!this.jobs.has(id)) {
                const known = [...this.jobs.keys()];
                return Err({
                    message: `Unknown delegate job: ${id}. Known: ${known.join(", ") || "none"}.`,
                });
            }
        }

        const pending = () =>
            unique.filter((id) => {
                const job = this.jobs.get(id);
                return job && !this.isTerminal(job.metadata.status);
            });

        if (pending().length === 0) return Success;
        if (signal?.aborted) {
            return Err({ message: "Wait aborted. Delegate jobs keep running." });
        }

        try {
            await new Promise<void>((resolve, reject) => {
                const detachWaiters = () => {
                    for (const id of unique) {
                        const set = this.waiters.get(id);
                        if (set) {
                            set.delete(onSettle);
                            if (set.size === 0) this.waiters.delete(id);
                        }
                    }
                };

                const onAbort = () => {
                    detachWaiters();
                    signal?.removeEventListener("abort", onAbort);
                    reject(new Error("Wait aborted. Delegate jobs keep running."));
                };

                const onSettle = () => {
                    const stillPending = pending();
                    if (stillPending.length > 0) onProgress?.(stillPending);
                    if (stillPending.length === 0) {
                        detachWaiters();
                        signal?.removeEventListener("abort", onAbort);
                        resolve();
                    }
                };

                signal?.addEventListener("abort", onAbort);

                for (const id of unique) {
                    let set = this.waiters.get(id);
                    if (!set) {
                        set = new Set();
                        this.waiters.set(id, set);
                    }
                    set.add(onSettle);
                }

                onSettle();
            });
        } catch (error) {
            return Err({
                message: error instanceof Error ? error.message : String(error),
            });
        }

        return Success;
    }

    async stop(id: string): Promise<Result<Unit>> {
        const job = this.jobs.get(id);
        if (!job) return Err({ message: `Unknown delegate job: ${id}` });
        if (job.metadata.status === "queued") {
            job.stopReason = "user";
            this.removeFromQueue(id);
            await this.settleStopped(job, "Stopped before launch.");
            this.pump();
            return Success;
        }
        if (job.metadata.status !== "running") return Success;
        job.stopReason = "user";
        job.controller?.abort();
        await job.runPromise;
        return Success;
    }

    async shutdown() {
        if (this.shuttingDown) return;
        this.shuttingDown = true;
        const queued = this.queue.splice(0);
        await Promise.all(
            queued.map(async (id) => {
                const job = this.jobs.get(id);
                if (!job || job.metadata.status !== "queued") return;
                job.stopReason = "shutdown";
                await this.settleStopped(job, "Stopped during Pi session shutdown.");
            }),
        );
        const running = [...this.jobs.values()].filter((job) => job.metadata.status === "running");
        for (const job of running) {
            job.stopReason = "shutdown";
            job.controller?.abort();
        }
        await Promise.allSettled(running.map((job) => job.runPromise));
        this.notify();
    }

    private runningJobs() {
        return [...this.jobs.values()].filter((job) => job.metadata.status === "running");
    }

    private eligible(job: ManagedJob) {
        if (job.metadata.profile !== "implementation") return true;
        return !this.runningJobs().some(
            (running) =>
                running.metadata.profile === "implementation" &&
                running.metadata.cwd === job.metadata.cwd,
        );
    }

    private pump() {
        if (this.shuttingDown) return;
        while (this.runningJobs().length < this.config.maxConcurrent) {
            const queueIndex = this.queue.findIndex((id) => {
                const job = this.jobs.get(id);
                return job?.metadata.status === "queued" && this.eligible(job);
            });
            if (queueIndex < 0) return;
            const [id] = this.queue.splice(queueIndex, 1);
            const job = id ? this.jobs.get(id) : undefined;
            if (!job) continue;
            job.metadata.status = "running";
            job.metadata.startedAt = Date.now();
            job.controller = new AbortController();
            this.notify();
            job.runPromise = this.run(job);
        }
    }

    private async run(job: ManagedJob) {
        const controller = job.controller;
        if (!controller) return;
        const delegateConfig = this.config.delegates[job.metadata.delegate];
        const timeout = setTimeout(() => {
            if (job.metadata.status !== "running") return;
            job.stopReason = "timeout";
            controller.abort();
        }, delegateConfig.timeoutMinutes * 60_000);
        timeout.unref();
        try {
            // Both fallible steps reduce to one failure reason, so the settle
            // decision below is written once rather than per failure path.
            let failure: DelegateError | undefined;
            const persisted = await writeMetadataAtomic(job.artifacts.metadata, job.metadata);
            if (!persisted.ok) {
                failure = persisted.error;
            } else {
                const outcome = await TryResult(() =>
                    job.backend.start(
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
                    ),
                );
                failure = exitFailure(outcome);
                if (outcome.ok) {
                    if (outcome.exitCode !== undefined) job.metadata.exitCode = outcome.exitCode;
                    if (outcome.signal) job.metadata.signal = outcome.signal;
                }
            }

            // A stop or timeout outranks whatever the backend reported.
            if (job.stopReason) {
                const settled = settleFromStopReason(job.stopReason);
                job.metadata.status = settled.status;
                job.metadata.error = settled.error;
            } else if (failure) {
                job.metadata.status = "error";
                job.metadata.error = failure.message;
            } else {
                job.metadata.status = "done";
            }
        } finally {
            clearTimeout(timeout);
            job.metadata.settledAt = Date.now();
            ignore(await writeMetadataAtomic(job.artifacts.metadata, job.metadata));
            const afterSettle = this.afterSettle;
            if (!this.shuttingDown && afterSettle) {
                // Job abort (stop/timeout) must not skip indexing of artifacts
                // already on disk; use a fresh signal independent of the run.
                const indexed = await Try(
                    afterSettle(job.metadata, job.artifacts, new AbortController().signal),
                );
                if (!indexed.ok) {
                    job.metadata.warnings.push(`Post-processing failed: ${indexed.error.message}`);
                }
                ignore(await writeMetadataAtomic(job.artifacts.metadata, job.metadata));
            }
            if (!this.shuttingDown && !job.delivered) {
                job.delivered = true;
                const onSettled = this.onSettled;
                if (onSettled) {
                    ignore(Try(() => onSettled({ ...job.metadata }, { ...job.artifacts })));
                }
            }
            this.releaseWaiters(job.metadata.id);
            this.notify();
            this.pump();
        }
    }

    private async settleStopped(job: ManagedJob, message: string) {
        if (job.metadata.status !== "queued") return;
        job.metadata.status = "stopped";
        job.metadata.error = message;
        job.metadata.settledAt = Date.now();
        ignore(await writeMetadataAtomic(job.artifacts.metadata, job.metadata));
        if (!this.shuttingDown && !job.delivered) {
            job.delivered = true;
            const onSettled = this.onSettled;
            if (onSettled) {
                ignore(Try(() => onSettled({ ...job.metadata }, { ...job.artifacts })));
            }
        }
        this.releaseWaiters(job.metadata.id);
        this.notify();
    }

    private isTerminal(status: DelegateJobMetadata["status"]) {
        return status === "done" || status === "error" || status === "stopped";
    }

    private releaseWaiters(id: string) {
        const waiters = this.waiters.get(id);
        if (!waiters) return;
        this.waiters.delete(id);
        for (const resolve of waiters) resolve();
    }

    private removeFromQueue(id: string) {
        const index = this.queue.indexOf(id);
        if (index >= 0) this.queue.splice(index, 1);
    }

    private pruneSettled() {
        if (this.jobs.size < this.config.maxTracked) return;
        const settled = [...this.jobs.values()]
            .filter((job) => job.metadata.settledAt !== undefined)
            .sort(
                (left, right) => (left.metadata.settledAt ?? 0) - (right.metadata.settledAt ?? 0),
            );
        while (this.jobs.size >= this.config.maxTracked && settled.length > 0) {
            const job = settled.shift();
            if (job) this.jobs.delete(job.metadata.id);
        }
    }

    private notify() {
        this.onChange?.();
    }
}

export function artifactForMetadata(metadata: DelegateJobMetadata) {
    return artifactPaths(metadata.projectId, metadata.id);
}
