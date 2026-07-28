import type { DelegateName } from "../types.ts";
import { AntigravityBackend } from "./antigravity.ts";
import { ClaudeBackend } from "./claude.ts";
import { CodexBackend } from "./codex.ts";
import { CursorBackend } from "./cursor.ts";

export function createBackends(executables: Record<DelegateName, string>) {
    return {
        codex: new CodexBackend(executables.codex),
        claude: new ClaudeBackend(executables.claude),
        agent: new CursorBackend(executables.agent),
        agy: new AntigravityBackend(executables.agy),
    };
}
