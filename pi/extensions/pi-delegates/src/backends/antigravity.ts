import { ensurePrivateFile } from "../artifacts.ts";
import { spawnDelegateProcess } from "../process.ts";
import type { DelegateTask } from "../types.ts";
import { BaseBackend } from "./backend.ts";

/**
 * Headless `--print` mode has no way to answer a tool permission prompt: agy
 * auto-denies the tool, then exits 0 having written nothing to stdout (the
 * explanation goes to stderr). Plan runs are read-oriented and still bounded by
 * --sandbox, so auto-approve there rather than fail silently. Edits stay behind
 * the explicit --dangerous opt-in.
 */
export function buildAntigravityArgs(task: DelegateTask): string[] {
    const autoApprove = task.dangerousBypass || task.profile === "plan";
    return [
        "--print",
        task.task,
        "--print-timeout",
        `${Math.max(1, Math.ceil(task.timeoutMs / 1000))}s`,
        "--new-project",
        "--mode",
        task.profile === "plan" ? "plan" : "accept-edits",
        "--log-file",
        task.artifacts.log,
        "--sandbox",
        ...(autoApprove ? ["--dangerously-skip-permissions"] : []),
    ];
}

export class AntigravityBackend extends BaseBackend {
    readonly name = "agy" as const;

    async start(
        task: DelegateTask,
        signal: AbortSignal,
        onSpawn?: (pid: number | undefined) => void,
    ) {
        const ensured = await ensurePrivateFile(task.artifacts.final);
        if (!ensured.ok) return ensured;
        const args = buildAntigravityArgs(task);
        return spawnDelegateProcess({
            executable: this.executable,
            args,
            cwd: task.cwd,
            stdoutPath: task.artifacts.final,
            stderrPath: task.artifacts.log,
            signal,
            ...(onSpawn ? { onSpawn } : {}),
        });
    }
}
