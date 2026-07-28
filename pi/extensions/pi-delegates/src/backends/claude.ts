import { ensurePrivateFile } from "../artifacts.ts";
import { spawnDelegateProcess } from "../process.ts";
import type { DelegateTask } from "../types.ts";
import { BaseBackend } from "./backend.ts";

export class ClaudeBackend extends BaseBackend {
    readonly name = "claude" as const;

    async start(
        task: DelegateTask,
        signal: AbortSignal,
        onSpawn?: (pid: number | undefined) => void,
    ) {
        const ensured = await ensurePrivateFile(task.artifacts.final);
        if (!ensured.ok) return ensured;
        const permissionArgs = task.dangerousBypass
            ? ["--dangerously-skip-permissions"]
            : [
                  "--permission-mode",
                  task.profile === "plan" ? "plan" : "acceptEdits",
                  ...(task.profile === "implementation"
                      ? ["--allowedTools", "Edit,Write,NotebookEdit"]
                      : []),
              ];
        return spawnDelegateProcess({
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
    }
}
