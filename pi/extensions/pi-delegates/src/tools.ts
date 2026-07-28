import * as fs from "node:fs";
import * as path from "node:path";
import type {
    ExtensionAPI,
    ExtensionCommandContext,
    ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { DEFAULT_MAX_LINES, truncateHead } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { readBoundedFile, readBoundedTailFile } from "./artifacts.ts";
import { formatJob } from "./display.ts";
import type { DelegateManager } from "./manager.ts";
import {
    buildDelegateSpawnResult,
    buildDelegateWaitSection,
    DELEGATE_CANCEL_PARAMETER_DESCRIPTIONS,
    DELEGATE_CANCEL_TOOL_DESCRIPTION,
    DELEGATE_CHECK_PARAMETER_DESCRIPTIONS,
    DELEGATE_CHECK_TOOL_DESCRIPTION,
    DELEGATE_LIST_TOOL_DESCRIPTION,
    DELEGATE_SPAWN_PARAMETER_DESCRIPTIONS,
    DELEGATE_SPAWN_PROMPT_GUIDELINES,
    DELEGATE_SPAWN_PROMPT_SNIPPET,
    DELEGATE_SPAWN_TOOL_DESCRIPTION,
    DELEGATE_WAIT_PARAMETER_DESCRIPTIONS,
    DELEGATE_WAIT_TOOL_DESCRIPTION,
} from "./prompt.ts";
import { type Result } from "./result.ts";
import type { DelegateName, DelegateProfile, DelegatesConfig } from "./types.ts";

export const WAIT_OUTPUT_MAX_BYTES = 48 * 1024;
export const WAIT_PER_JOB_MAX_BYTES = 16 * 1024;
export const CHECK_PREVIEW_MAX_BYTES = 2048;

const DELEGATE_NAMES = ["codex", "claude", "agent", "agy"] as const;
const DELEGATE_PROFILES = ["plan", "implementation"] as const;

const DelegateNameParam = Type.Union(
    DELEGATE_NAMES.map((name) => Type.Literal(name)),
    { description: DELEGATE_SPAWN_PARAMETER_DESCRIPTIONS.delegate },
);

const DelegateProfileParam = Type.Union(
    DELEGATE_PROFILES.map((profile) => Type.Literal(profile)),
    { description: DELEGATE_SPAWN_PARAMETER_DESCRIPTIONS.profile },
);

export interface ManagerBundle {
    manager: DelegateManager;
    config: DelegatesConfig;
    executables: Record<DelegateName, string | undefined>;
}

export interface DelegateToolsOptions {
    getManager: (ctx: ExtensionContext | ExtensionCommandContext) => Promise<Result<ManagerBundle>>;
    onWaitStart: (ids: string[]) => void;
    onWaitEnd: (ids: string[], options: { consumed: boolean }) => void;
}

function unwrap<T extends object>(result: Result<T>): T {
    if (!result.ok) throw new Error(result.error.message);
    return result;
}

function isTerminal(status: string) {
    return status === "done" || status === "error" || status === "stopped";
}

async function readOutputPreview(
    finalPath: string,
    logPath: string,
    fallback: string,
    maxBytes: number,
): Promise<string> {
    const final = await readBoundedFile(finalPath, maxBytes);
    if (final.ok && final.text.trim()) return final.text;
    const log = await readBoundedTailFile(logPath, maxBytes);
    if (log.ok && log.text.trim()) return log.text;
    return fallback;
}

async function readCheckPreview(
    finalPath: string,
    logPath: string,
    terminal: boolean,
    maxBytes: number,
): Promise<string> {
    if (terminal) {
        return readOutputPreview(finalPath, logPath, "", maxBytes);
    }
    const log = await readBoundedTailFile(logPath, maxBytes);
    if (log.ok && log.text.trim()) return log.text;
    const final = await readBoundedFile(finalPath, maxBytes);
    if (final.ok && final.text.trim()) return final.text;
    return "";
}

function unknownIdsError(unknown: string[], known: string[]) {
    return new Error(
        `Unknown delegate job id(s): ${unknown.join(", ")}. Known: ${known.join(", ") || "none"}.`,
    );
}

export function registerDelegateTools(pi: ExtensionAPI, options: DelegateToolsOptions) {
    const { getManager, onWaitStart, onWaitEnd } = options;

    pi.registerTool({
        name: "delegate_spawn",
        label: "Spawn Delegate",
        description: DELEGATE_SPAWN_TOOL_DESCRIPTION,
        promptSnippet: DELEGATE_SPAWN_PROMPT_SNIPPET,
        promptGuidelines: DELEGATE_SPAWN_PROMPT_GUIDELINES,
        parameters: Type.Object({
            task: Type.String({
                description: DELEGATE_SPAWN_PARAMETER_DESCRIPTIONS.task,
            }),
            delegate: DelegateNameParam,
            profile: Type.Optional(DelegateProfileParam),
            working_dir: Type.Optional(
                Type.String({
                    description: DELEGATE_SPAWN_PARAMETER_DESCRIPTIONS.workingDir,
                }),
            ),
        }),
        async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
            if (!ctx.isProjectTrusted()) {
                throw new Error("Delegate tools require a trusted Pi project.");
            }
            const bundle = unwrap(await getManager(ctx));
            const delegate = params.delegate as DelegateName;
            const profile = (params.profile ?? "plan") as DelegateProfile;

            if (delegate === "agy" && profile === "implementation") {
                throw new Error(
                    "Antigravity implementation is not available via tools. Headless edit permissions require explicit --dangerous on /delegate-agy.",
                );
            }

            const delegateConfig = bundle.config.delegates[delegate];
            if (!delegateConfig.enabled) {
                throw new Error(`${delegate} delegation is disabled.`);
            }
            if (!bundle.executables[delegate]) {
                throw new Error(`${delegate} executable was not found.`);
            }

            const cwd = path.resolve(ctx.cwd, params.working_dir ?? ".");
            if (!fs.existsSync(cwd) || !fs.statSync(cwd).isDirectory()) {
                throw new Error(`working_dir is not a directory: ${cwd}`);
            }

            const submitted = unwrap(
                await bundle.manager.submit({
                    delegate,
                    profile,
                    dangerousBypass: false,
                    task: params.task,
                    cwd,
                }),
            );
            const job = bundle.manager.get(submitted.metadata.id);
            const artifactDir = job?.artifacts.directory ?? "(unknown)";

            return {
                content: [
                    {
                        type: "text" as const,
                        text: buildDelegateSpawnResult({
                            id: submitted.metadata.id,
                            delegate,
                            profile,
                            cwd: submitted.metadata.cwd,
                            artifactDir,
                        }),
                    },
                ],
                details: {
                    id: submitted.metadata.id,
                    delegate,
                    profile,
                    cwd: submitted.metadata.cwd,
                    artifactDir,
                },
            };
        },
    });

    pi.registerTool({
        name: "delegate_wait",
        label: "Wait for Delegates",
        description: DELEGATE_WAIT_TOOL_DESCRIPTION,
        parameters: Type.Object({
            ids: Type.Array(Type.String(), {
                maxItems: 32,
                description: DELEGATE_WAIT_PARAMETER_DESCRIPTIONS.ids,
            }),
        }),
        async execute(_toolCallId, params, signal, onUpdate, ctx) {
            if (!ctx.isProjectTrusted()) {
                throw new Error("Delegate tools require a trusted Pi project.");
            }
            const bundle = unwrap(await getManager(ctx));
            const ids = [...new Set(params.ids)];
            if (ids.length === 0) throw new Error("Provide at least one delegate job id.");

            const known = bundle.manager.list().map((job) => job.id);
            const unknown = ids.filter((id) => !bundle.manager.get(id));
            if (unknown.length > 0) throw unknownIdsError(unknown, known);

            onWaitStart(ids);
            try {
                unwrap(
                    await bundle.manager.waitFor(
                        ids,
                        (pending) => {
                            if (pending.length === 0) return;
                            onUpdate?.({
                                content: [
                                    {
                                        type: "text" as const,
                                        text: `Waiting for ${pending.join(", ")}...`,
                                    },
                                ],
                                details: { pending },
                            });
                        },
                        signal,
                    ),
                );
            } catch (error) {
                onWaitEnd(ids, { consumed: false });
                throw error;
            }

            try {
                const sections: string[] = [];
                let remainingBytes = WAIT_OUTPUT_MAX_BYTES;
                for (const id of ids) {
                    const job = bundle.manager.get(id);
                    if (!job) {
                        sections.push(`## ${id}\n\n(no longer tracked)`);
                        continue;
                    }
                    const { metadata, artifacts } = job;
                    const output = await readOutputPreview(
                        artifacts.final,
                        artifacts.log,
                        metadata.error ?? "(no final output)",
                        WAIT_PER_JOB_MAX_BYTES,
                    );
                    let section = buildDelegateWaitSection({
                        id: metadata.id,
                        delegate: metadata.delegate,
                        profile: metadata.profile,
                        status: metadata.status,
                        ...(metadata.error ? { error: metadata.error } : {}),
                        output: "",
                    });
                    const headerBytes = Buffer.byteLength(section, "utf8") + 2;
                    const outputBudget = Math.max(
                        512,
                        Math.min(WAIT_PER_JOB_MAX_BYTES, remainingBytes - headerBytes),
                    );
                    const bounded = truncateHead(output, {
                        maxBytes: outputBudget,
                        maxLines: Math.min(600, DEFAULT_MAX_LINES),
                    });
                    section = buildDelegateWaitSection({
                        id: metadata.id,
                        delegate: metadata.delegate,
                        profile: metadata.profile,
                        status: metadata.status,
                        ...(metadata.error ? { error: metadata.error } : {}),
                        output: bounded.content + (bounded.truncated ? "\n[output truncated]" : ""),
                    });
                    const sectionBytes = Buffer.byteLength(section, "utf8");
                    if (sectionBytes > remainingBytes) {
                        sections.push(
                            `## ${metadata.id} · ${metadata.delegate}\n\n[omitted: total wait output limit reached]`,
                        );
                        break;
                    }
                    sections.push(section);
                    remainingBytes -= sectionBytes;
                }

                const combined = sections.join("\n\n---\n\n");
                const bounded = truncateHead(combined, {
                    maxBytes: WAIT_OUTPUT_MAX_BYTES - 128,
                    maxLines: DEFAULT_MAX_LINES,
                });
                const text = bounded.truncated
                    ? `${bounded.content}\n\n[wait output truncated at the total output limit]`
                    : bounded.content;

                return {
                    content: [{ type: "text" as const, text }],
                    details: {
                        results: ids.map((id) => {
                            const job = bundle.manager.get(id);
                            return {
                                id,
                                delegate: job?.metadata.delegate,
                                status: job?.metadata.status,
                            };
                        }),
                    },
                };
            } finally {
                onWaitEnd(ids, { consumed: true });
            }
        },
    });

    pi.registerTool({
        name: "delegate_check",
        label: "Check Delegate",
        description: DELEGATE_CHECK_TOOL_DESCRIPTION,
        parameters: Type.Object({
            id: Type.String({
                description: DELEGATE_CHECK_PARAMETER_DESCRIPTIONS.id,
            }),
        }),
        async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
            if (!ctx.isProjectTrusted()) {
                throw new Error("Delegate tools require a trusted Pi project.");
            }
            const bundle = unwrap(await getManager(ctx));
            const job = bundle.manager.get(params.id);
            if (!job) {
                const known = bundle.manager.list().map((j) => j.id);
                throw new Error(
                    `Unknown delegate job id "${params.id}". Known: ${known.join(", ") || "none"}.`,
                );
            }

            let text = formatJob(job.metadata);
            if (job.metadata.error) text += `\nError: ${job.metadata.error}`;

            const preview = await readCheckPreview(
                job.artifacts.final,
                job.artifacts.log,
                isTerminal(job.metadata.status),
                CHECK_PREVIEW_MAX_BYTES,
            );
            if (preview) {
                const bounded = truncateHead(preview, {
                    maxBytes: CHECK_PREVIEW_MAX_BYTES,
                    maxLines: 20,
                });
                text += `\n\nLatest output:\n${bounded.content}`;
                if (bounded.truncated) text += "\n[...]";
            } else if (!isTerminal(job.metadata.status)) {
                text += "\n\n(no output yet)";
            }

            return {
                content: [{ type: "text" as const, text }],
                details: { id: job.metadata.id, status: job.metadata.status },
            };
        },
    });

    pi.registerTool({
        name: "delegate_cancel",
        label: "Cancel Delegates",
        description: DELEGATE_CANCEL_TOOL_DESCRIPTION,
        parameters: Type.Object({
            ids: Type.Array(Type.String(), {
                description: DELEGATE_CANCEL_PARAMETER_DESCRIPTIONS.ids,
            }),
        }),
        async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
            if (!ctx.isProjectTrusted()) {
                throw new Error("Delegate tools require a trusted Pi project.");
            }
            const bundle = unwrap(await getManager(ctx));
            const ids = [...new Set(params.ids)];
            if (ids.length === 0) throw new Error("Provide at least one delegate job id.");

            const known = bundle.manager.list().map((job) => job.id);
            const unknown = ids.filter((id) => !bundle.manager.get(id));
            if (unknown.length > 0) throw unknownIdsError(unknown, known);

            const lines: string[] = [];
            for (const id of ids) {
                const before = bundle.manager.get(id);
                const wasActive =
                    before?.metadata.status === "queued" || before?.metadata.status === "running";
                unwrap(await bundle.manager.stop(id));
                const after = bundle.manager.get(id);
                if (wasActive && after && isTerminal(after.metadata.status)) {
                    lines.push(`Cancelled ${id}.`);
                } else {
                    lines.push(`${id} was already ${after?.metadata.status ?? "unknown"}.`);
                }
            }

            return {
                content: [{ type: "text" as const, text: lines.join("\n") }],
                details: {
                    results: ids.map((id) => ({
                        id,
                        status: bundle.manager.get(id)?.metadata.status,
                    })),
                },
            };
        },
    });

    pi.registerTool({
        name: "delegate_list",
        label: "List Delegates",
        description: DELEGATE_LIST_TOOL_DESCRIPTION,
        parameters: Type.Object({}),
        async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
            if (!ctx.isProjectTrusted()) {
                throw new Error("Delegate tools require a trusted Pi project.");
            }
            const bundle = unwrap(await getManager(ctx));
            const jobs = bundle.manager.list();
            const text =
                jobs.length === 0
                    ? "No delegate jobs."
                    : jobs.map((job) => formatJob(job)).join("\n");

            return {
                content: [{ type: "text" as const, text }],
                details: {
                    jobs: jobs.map((job) => ({
                        id: job.id,
                        delegate: job.delegate,
                        profile: job.profile,
                        status: job.status,
                    })),
                },
            };
        },
    });
}
