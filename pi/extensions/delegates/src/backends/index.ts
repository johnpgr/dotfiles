import type { DelegateName } from "../types.js";
import { AntigravityBackend } from "./antigravity.js";
import { ClaudeBackend } from "./claude.js";
import { CodexBackend } from "./codex.js";
import { CursorBackend } from "./cursor.js";

export function createBackends(executables: Record<DelegateName, string>) {
    return {
        codex: new CodexBackend(executables.codex),
        claude: new ClaudeBackend(executables.claude),
        agent: new CursorBackend(executables.agent),
        agy: new AntigravityBackend(executables.agy),
    };
}
