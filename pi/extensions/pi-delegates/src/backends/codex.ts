import { ensurePrivateFile } from "../artifacts.ts";
import { spawnDelegateProcess } from "../process.ts";
import type { DelegateTask } from "../types.ts";
import { BaseBackend } from "./backend.ts";

export class CodexBackend extends BaseBackend {
    readonly name = "codex" as const;

    async start(
        task: DelegateTask,
        signal: AbortSignal,
        onSpawn?: (pid: number | undefined) => void,
    ) {
        const ensured = await ensurePrivateFile(task.artifacts.final);
        if (!ensured.ok) return ensured;
        const permissionArgs = task.dangerousBypass
            ? ["--dangerously-bypass-approvals-and-sandbox"]
            : ["--sandbox", task.profile === "plan" ? "read-only" : "workspace-write"];
        return spawnDelegateProcess({
            executable: this.executable,
            args: [
                "exec",
                "--ephemeral",
                "--color",
                "never",
                "--cd",
                task.cwd,
                ...permissionArgs,
                "--output-last-message",
                task.artifacts.final,
                "-",
            ],
            cwd: task.cwd,
            stdin: task.task,
            stdoutPath: task.artifacts.log,
            stderrPath: task.artifacts.log,
            signal,
            ...(onSpawn ? { onSpawn } : {}),
        });
    }
}
