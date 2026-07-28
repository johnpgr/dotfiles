import type {
    ExtensionAPI,
    ExtensionCommandContext,
    ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { parseJobId, parseLaunchArguments, parseSearchArguments } from "./src/args.ts";
import { readBoundedFile, type BoundedRead } from "./src/artifacts.ts";
import { createBackends } from "./src/backends/index.ts";
import { loadConfig, resolveExecutable } from "./src/config.ts";
import {
    indexDelegateArtifacts,
    resolveContextMode,
    searchDelegateArtifacts,
} from "./src/context-mode.ts";
import { formatJob, renderDelegateEntry, statusCounts } from "./src/display.ts";
import { artifactForMetadata, DelegateManager } from "./src/manager.ts";
import { Err, Ok, Success, Try, TryResult, type Result, type Unit } from "./src/result.ts";
import { registerDelegateTools } from "./src/tools.ts";
import type { DelegateName, DelegateResultEntryData, DelegatesConfig } from "./src/types.ts";

const COMMANDS: Record<DelegateName, string> = {
    codex: "delegate-codex",
    claude: "delegate-claude",
    agent: "delegate-agent",
    agy: "delegate-agy",
};

interface ManagerBundle {
    manager: DelegateManager;
    config: DelegatesConfig;
    executables: Record<DelegateName, string | undefined>;
    contextMode: string | undefined;
}

async function readFinalOrFallback(
    filePath: string,
    maxBytes: number,
    fallback: string,
): Promise<BoundedRead> {
    const result = await readBoundedFile(filePath, maxBytes);
    if (!result.ok) {
        return { text: fallback, truncated: false };
    }

    return { text: result.text, truncated: result.truncated };
}

export default function delegatesExtension(pi: ExtensionAPI) {
    let sessionContext: ExtensionContext | undefined;
    let managerPromise: Promise<Result<ManagerBundle>> | undefined;
    const toolDeliveredIds = new Set<string>();
    const waitingIds = new Set<string>();
    const deferredCompletions = new Map<string, ReturnType<DelegateManager["list"]>[number]>();

    const updateStatus = (manager: DelegateManager) => {
        const ui = sessionContext?.hasUI ? sessionContext.ui : undefined;
        if (!ui) return;
        const counts = statusCounts(manager.list());
        if (counts.queued + counts.running + counts.done + counts.error + counts.stopped === 0) {
            ui.setStatus("delegates", undefined);
            return;
        }
        ui.setStatus(
            "delegates",
            `delegates ${counts.running} running · ${counts.queued} queued · ${counts.done} done · ${counts.error} failed`,
        );
    };

    const appendCompletion = async (
        metadata: ReturnType<DelegateManager["list"]>[number],
        bundle: ManagerBundle,
    ): Promise<Result<Unit>> => {
        if (!sessionContext) return Success;
        if (toolDeliveredIds.has(metadata.id) || waitingIds.has(metadata.id)) return Success;
        // appendEntry is UI-only; it never enters the parent model's context.
        const artifacts = artifactForMetadata(metadata);
        const result = await readFinalOrFallback(
            artifacts.final,
            bundle.config.maxPreviewBytes,
            metadata.error ?? "(no final output)",
        );
        if (!sessionContext) return Success;
        const elapsedMs =
            (metadata.settledAt ?? Date.now()) - (metadata.startedAt ?? metadata.createdAt);
        const appended = Try(() => {
            pi.appendEntry<DelegateResultEntryData>("delegate-result", {
                id: metadata.id,
                delegate: metadata.delegate,
                profile: metadata.profile,
                status: metadata.status,
                elapsedMs,
                preview: result.text,
                truncated: result.truncated,
                artifactPath: artifacts.directory,
                contextSources: [...metadata.contextSources],
                warnings: [...metadata.warnings],
            });
        });
        if (!appended.ok) return appended;
        sessionContext.ui.notify(
            `${metadata.delegate} ${metadata.id} ${metadata.status}. Use /delegate-result ${metadata.id}.`,
            metadata.status === "done" ? "info" : "warning",
        );
        return Success;
    };

    const flushCompletions = async (bundle: ManagerBundle) => {
        if (!sessionContext) return;
        for (const [id, metadata] of [...deferredCompletions.entries()]) {
            if (toolDeliveredIds.has(id)) {
                deferredCompletions.delete(id);
                continue;
            }
            if (waitingIds.has(id)) continue;
            deferredCompletions.delete(id);
            const result = await appendCompletion(metadata, bundle);
            if (!result.ok) sessionContext.ui.notify(result.error.message, "error");
        }
    };

    const buildManager = async (
        ctx: ExtensionContext | ExtensionCommandContext,
    ): Promise<Result<ManagerBundle>> => {
        const config = await loadConfig((message) => ctx.ui.notify(message, "warning"));
        const pairs = await Promise.all(
            (Object.keys(COMMANDS) as DelegateName[]).map(
                async (name) =>
                    [
                        name,
                        await resolveExecutable(name, config.delegates[name].executable),
                    ] as const,
            ),
        );
        const executables = Object.fromEntries(pairs) as Record<DelegateName, string | undefined>;
        const contextMode = await resolveContextMode();
        const backendExecutables = Object.fromEntries(
            pairs.map(([name, executable]) => [name, executable ?? ""]),
        ) as Record<DelegateName, string>;
        let instance: DelegateManager;
        const bundle: ManagerBundle = {
            manager: (instance = new DelegateManager({
                config,
                backends: createBackends(backendExecutables),
                onChange: () => updateStatus(instance),
                afterSettle: (metadata, artifacts, signal) =>
                    indexDelegateArtifacts(contextMode, config, metadata, artifacts, signal),
                onSettled: (metadata) => {
                    if (toolDeliveredIds.has(metadata.id)) return;
                    deferredCompletions.set(metadata.id, { ...metadata });
                    if (sessionContext?.isIdle()) {
                        void flushCompletions(bundle);
                    }
                },
            })),
            config,
            executables,
            contextMode,
        };
        const recovered = await bundle.manager.recover(ctx.cwd);
        if (!recovered.ok) return recovered;
        updateStatus(bundle.manager);
        return Ok(bundle);
    };

    const getManager = async (
        ctx: ExtensionContext | ExtensionCommandContext,
    ): Promise<Result<ManagerBundle>> => {
        managerPromise ??= buildManager(ctx);
        const result = await managerPromise;
        if (!result.ok) managerPromise = undefined;
        return result;
    };

    const guarded =
        (body: (raw: string, ctx: ExtensionCommandContext) => Promise<Result<Unit>>) =>
        async (raw: string, ctx: ExtensionCommandContext): Promise<void> => {
            const result = await TryResult(() => body(raw, ctx));
            if (!result.ok) ctx.ui.notify(result.error.message, "error");
        };

    pi.registerEntryRenderer<DelegateResultEntryData>("delegate-result", renderDelegateEntry);

    for (const [name, command] of Object.entries(COMMANDS) as [DelegateName, string][]) {
        pi.registerCommand(command, {
            description: `Run ${name} explicitly outside parent model context`,
            handler: guarded(async (rawArgs, ctx) => {
                const parsed = parseLaunchArguments(rawArgs);
                if (!parsed.ok) return parsed;
                if (!ctx.isProjectTrusted()) {
                    return Err({ message: "Delegate commands require a trusted Pi project." });
                }
                const bundle = await getManager(ctx);
                if (!bundle.ok) return bundle;
                const delegateConfig = bundle.config.delegates[name];
                if (!delegateConfig.enabled) {
                    return Err({ message: `${name} delegation is disabled.` });
                }
                if (!bundle.executables[name]) {
                    return Err({ message: `${name} executable was not found.` });
                }
                if (
                    name === "agy" &&
                    parsed.profile === "implementation" &&
                    !parsed.dangerousBypass
                ) {
                    return Err({
                        message:
                            "Antigravity implementation requires explicit --dangerous because headless edit permissions cannot prompt.",
                    });
                }
                const dangerousBypass = parsed.dangerousBypass;
                if (dangerousBypass && delegateConfig.allowDangerousBypass !== true) {
                    return Err({
                        message: `${name} requires a dangerous permission bypass for this launch. Set allowDangerousBypass in global pi-delegates.json to opt in.`,
                    });
                }
                const submitted = await bundle.manager.submit({
                    delegate: name,
                    profile: parsed.profile,
                    dangerousBypass,
                    task: parsed.task,
                    cwd: ctx.cwd,
                });
                if (!submitted.ok) return submitted;
                ctx.ui.notify(
                    `${name} queued as ${submitted.metadata.id} (${parsed.profile}${dangerousBypass ? ", DANGEROUS BYPASS" : ""}).`,
                    dangerousBypass ? "warning" : "info",
                );
                return Success;
            }),
        });
    }

    pi.registerCommand("delegate-status", {
        description: "Show queued, running, and recent delegate jobs",
        handler: guarded(async (raw, ctx) => {
            const bundle = await getManager(ctx);
            if (!bundle.ok) return bundle;
            if (raw.trim()) {
                const parsed = parseJobId(raw);
                if (!parsed.ok) return parsed;
                const job = bundle.manager.require(parsed.id);
                if (!job.ok) return job;
                ctx.ui.notify(formatJob(job.metadata), "info");
                return Success;
            }
            const jobs = bundle.manager.list().slice(0, 12);
            ctx.ui.notify(
                jobs.length > 0
                    ? jobs.map(formatJob).join("\n")
                    : "No delegate jobs for this project.",
                "info",
            );
            return Success;
        }),
    });

    pi.registerCommand("delegate-result", {
        description: "Show a bounded delegate result in the TUI",
        handler: guarded(async (raw, ctx) => {
            const parsed = parseJobId(raw);
            if (!parsed.ok) return parsed;
            const bundle = await getManager(ctx);
            if (!bundle.ok) return bundle;
            const job = bundle.manager.require(parsed.id);
            if (!job.ok) return job;
            const result = await readFinalOrFallback(
                job.artifacts.final,
                bundle.config.maxPreviewBytes,
                job.metadata.error ?? "(no final output)",
            );
            ctx.ui.notify(
                `${formatJob(job.metadata)}\n\n${result.text}${result.truncated ? "\n[truncated]" : ""}\n\nArtifacts: ${job.artifacts.directory}`,
                job.metadata.status === "done" ? "info" : "warning",
            );
            return Success;
        }),
    });

    pi.registerCommand("delegate-search", {
        description: "Search Context Mode artifacts for one delegate job",
        handler: guarded(async (raw, ctx) => {
            const parsed = parseSearchArguments(raw);
            if (!parsed.ok) return parsed;
            const bundle = await getManager(ctx);
            if (!bundle.ok) return bundle;
            const job = bundle.manager.require(parsed.id);
            if (!job.ok) return job;
            const result = await searchDelegateArtifacts(
                bundle.contextMode,
                job.metadata,
                job.artifacts,
                parsed.query,
                bundle.config.maxPreviewBytes,
            );
            ctx.ui.notify(
                `${result.output || "(no matches)"}${result.truncated ? "\n[truncated]" : ""}${result.warning ? `\nWarning: ${result.warning}` : ""}`,
                result.warning ? "warning" : "info",
            );
            return Success;
        }),
    });

    pi.registerCommand("delegate-stop", {
        description: "Stop a queued or running delegate job",
        handler: guarded(async (raw, ctx) => {
            const parsed = parseJobId(raw);
            if (!parsed.ok) return parsed;
            const bundle = await getManager(ctx);
            if (!bundle.ok) return bundle;
            const stopped = await bundle.manager.stop(parsed.id);
            if (!stopped.ok) return stopped;
            ctx.ui.notify(`Stopped ${parsed.id}.`, "info");
            return Success;
        }),
    });

    pi.registerCommand("delegate-attach", {
        description: "Attach a bounded result to the next parent-model turn",
        handler: guarded(async (raw, ctx) => {
            const parsed = parseJobId(raw);
            if (!parsed.ok) return parsed;
            const bundle = await getManager(ctx);
            if (!bundle.ok) return bundle;
            const job = bundle.manager.require(parsed.id);
            if (!job.ok) return job;
            const result = await readFinalOrFallback(
                job.artifacts.final,
                bundle.config.maxAttachBytes,
                job.metadata.error ?? "(no final output)",
            );
            const source = `delegate:${parsed.id}`;
            const attached = Try(() => {
                pi.sendMessage(
                    {
                        customType: "delegate-attachment",
                        content: [
                            `Explicitly attached delegate result`,
                            `Job: ${parsed.id}`,
                            `Backend: ${job.metadata.delegate}`,
                            `Status: ${job.metadata.status}`,
                            `Artifacts: ${job.artifacts.directory}`,
                            `Context source: ${source}`,
                            ...(result.truncated ? ["Result was truncated."] : []),
                            "",
                            result.text,
                        ].join("\n"),
                        display: true,
                        details: { id: parsed.id, source, truncated: result.truncated },
                    },
                    { deliverAs: "nextTurn" },
                );
            });
            if (!attached.ok) return attached;
            ctx.ui.notify(`${parsed.id} attached for the next user turn.`, "info");
            return Success;
        }),
    });

    registerDelegateTools(pi, {
        getManager,
        onWaitStart: (ids) => {
            for (const id of ids) waitingIds.add(id);
        },
        onWaitEnd: (ids, { consumed }) => {
            for (const id of ids) {
                waitingIds.delete(id);
                if (consumed) {
                    toolDeliveredIds.add(id);
                    deferredCompletions.delete(id);
                }
            }
        },
    });

    pi.on("agent_settled", async () => {
        const built = managerPromise ? await managerPromise : undefined;
        if (built?.ok) await flushCompletions(built);
    });

    pi.on("session_start", async (_event, ctx) => {
        sessionContext = ctx;
        const result = await getManager(ctx);
        if (!result.ok) ctx.ui.notify(result.error.message, "error");
    });

    pi.on("session_shutdown", async () => {
        const built = managerPromise ? await managerPromise : undefined;
        sessionContext = undefined;
        deferredCompletions.clear();
        toolDeliveredIds.clear();
        waitingIds.clear();
        if (built?.ok) await built.manager.shutdown();
        managerPromise = undefined;
    });
}
