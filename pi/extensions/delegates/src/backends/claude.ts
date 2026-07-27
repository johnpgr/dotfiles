import { ensurePrivateFile } from "../artifacts.js";
import { spawnDelegateProcess } from "../process.js";
import type { DelegateCapabilities, DelegateTask } from "../types.js";
import { BaseBackend } from "./backend.js";

export class ClaudeBackend extends BaseBackend {
    readonly name = "claude" as const;
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
        const permissionArgs = task.dangerousBypass
            ? ["--dangerously-skip-permissions"]
            : [
                "--permission-mode",
                task.profile === "plan" ? "plan" : "acceptEdits",
                ...(task.profile === "implementation"
                    ? ["--allowedTools", "Edit,Write,NotebookEdit"]
                    : []),
            ];
        const result = await spawnDelegateProcess({
            executable: this.executable,
            args: [
                "--print",
                "--output-format",
                "text",
                "--no-session-persistence",
                ...permissionArgs,
            ],
            cwd: task.cwd,
            stdin: task.task,
            stdoutPath: task.artifacts.final,
            stderrPath: task.artifacts.log,
            signal,
            ...(onSpawn ? { onSpawn } : {}),
        });
        return this.outcome(result);
    }
}
