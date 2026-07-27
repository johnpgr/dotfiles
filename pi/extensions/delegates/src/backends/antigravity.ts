import { ensurePrivateFile } from "../artifacts.js";
import { spawnDelegateProcess } from "../process.js";
import type { DelegateCapabilities, DelegateTask } from "../types.js";
import { BaseBackend } from "./backend.js";

export class AntigravityBackend extends BaseBackend {
    readonly name = "agy" as const;
    readonly capabilities: DelegateCapabilities = {
        structuredEvents: false,
        liveText: false,
        toolEvents: false,
        tokenUsage: false,
        cancellation: true,
        resume: false,
        steering: false,
    };

    async start(
        task: DelegateTask,
        signal: AbortSignal,
        onSpawn?: (pid: number | undefined) => void,
    ) {
        await ensurePrivateFile(task.artifacts.final);
        const args = [
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
            ...(task.dangerousBypass ? ["--dangerously-skip-permissions"] : []),
        ];
        const result = await spawnDelegateProcess({
            executable: this.executable,
            args,
            cwd: task.cwd,
            stdoutPath: task.artifacts.final,
            stderrPath: task.artifacts.log,
            signal,
            ...(onSpawn ? { onSpawn } : {}),
        });
        return this.outcome(result);
    }
}
