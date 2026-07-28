/** All model-facing strings for the delegate tools. */

export const DELEGATE_SPAWN_TOOL_DESCRIPTION =
    "Spawn a background delegate job: a headless coding agent (Codex, Claude Code, Cursor Agent, or Antigravity) with its own process and context. Fire-and-forget: this returns immediately with a job id. The result is delivered when the job settles, or collect it explicitly with delegate_wait. The task must be self-contained — delegates receive only the task text, not this conversation. Only use trusted working directories. At most 4 delegate jobs run at once (maxConcurrent), and only one implementation-profile job runs per working directory at a time — additional implementation jobs for the same directory queue until it finishes.";

export const DELEGATE_SPAWN_PROMPT_SNIPPET =
    "Spawn a background delegate on a chosen harness (codex, claude, agent, or agy) for a self-contained task; max 4 running, one implementation job per directory";

export const DELEGATE_SPAWN_PROMPT_GUIDELINES = [
    "Use delegate_spawn for self-contained tasks that can run in the background while you keep working.",
    "Pick the delegate deliberately: codex, claude, agent, or agy — match the harness to the task or user preference.",
    "After delegate_spawn, keep working rather than blocking on delegate_wait. Use delegate_wait only when you cannot proceed without the result.",
    "Do not delegate trivial work (a few file reads, a quick fix you can finish inline). Delegate wide investigations and independent tracks.",
    "Scheduling: at most 4 jobs run concurrently; implementation-profile jobs for the same working directory serialize to one at a time. Do not fan out many implementation jobs in one repo expecting parallel edits.",
];

export const DELEGATE_SPAWN_PARAMETER_DESCRIPTIONS = {
    task: "Task prompt for the delegate. Must be self-contained: include all needed context, file paths, and what to report back.",
    delegate:
        'Harness to run: "codex", "claude", "agent" (Cursor Agent), or "agy" (Antigravity). Choose deliberately per task.',
    profile:
        'Execution profile: "plan" (read-only, default) or "implementation" (may edit files). Antigravity implementation is not available via tools.',
    workingDir:
        "Working directory for the delegate (default: current working directory). Must exist and be trusted.",
};

export function buildDelegateSpawnResult(options: {
    id: string;
    delegate: string;
    profile: string;
    cwd: string;
    artifactDir: string;
}) {
    return (
        `Spawned delegate ${options.id} (${options.delegate}: ${options.profile}, ${options.cwd}).\n` +
        `Artifacts: ${options.artifactDir}\n` +
        `It runs in the background. Use delegate_wait(ids: ["${options.id}"]) to block for it, ` +
        `delegate_cancel to stop it, delegate_check to peek, delegate_list to see all.`
    );
}

export const DELEGATE_WAIT_TOOL_DESCRIPTION =
    "Block until all listed delegate jobs have settled, then return their final outputs. Prefer keeping working after delegate_spawn; use this only when you need a result before continuing.";

export const DELEGATE_WAIT_PARAMETER_DESCRIPTIONS = {
    ids: 'Delegate job ids to wait for, e.g. ["dlg-abc123", "dlg-def456"]',
};

export const DELEGATE_CANCEL_TOOL_DESCRIPTION =
    "Cancel one or more queued or running delegate jobs. Stopped jobs keep their partial artifacts on disk.";

export const DELEGATE_CANCEL_PARAMETER_DESCRIPTIONS = {
    ids: 'Delegate job ids to cancel, e.g. ["dlg-abc123"]',
};

export const DELEGATE_CHECK_TOOL_DESCRIPTION =
    "Peek at a delegate job's status and recent output without blocking. Does not consume its result.";

export const DELEGATE_CHECK_PARAMETER_DESCRIPTIONS = {
    id: "Delegate job id",
};

export const DELEGATE_LIST_TOOL_DESCRIPTION =
    "List all tracked delegate jobs (queued, running, and settled) with harness and status.";

export function buildDelegateWaitSection(options: {
    id: string;
    delegate: string;
    profile: string;
    status: string;
    error?: string;
    output: string;
}) {
    const verb =
        options.status === "error"
            ? "failed"
            : options.status === "stopped"
              ? "was stopped"
              : "finished";
    let section = `## ${options.id} · ${options.delegate} · ${options.profile} ${verb}`;
    if (options.error) section += `\nError: ${options.error}`;
    section += `\n\n${options.output}`;
    return section;
}
