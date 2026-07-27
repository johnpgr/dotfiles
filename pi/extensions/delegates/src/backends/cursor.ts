import { appendFile, open, writeFile } from "node:fs/promises";
import type { Readable } from "node:stream";
import { spawnDelegateProcess } from "../process.js";
import type {
    DelegateCapabilities,
    DelegateOutcome,
    DelegateTask,
    KnownCursorEvent,
} from "../types.js";
import { parseCursorEvent } from "../validators.js";
import { BaseBackend } from "./backend.js";

const MAX_PARSE_BUFFER = 1024 * 1024;

function assistantText(event: KnownCursorEvent) {
    if (event.type !== "assistant") return "";
    return (event.message?.content ?? [])
        .filter(
            (content) => content.type === "text" && typeof content.text === "string",
        )
        .map((content) => content.text ?? "")
        .join("");
}

interface CursorParseState {
    final?: string;
    assistant: string;
    resultError?: string;
    diagnostics: string[];
}

function parseLine(line: string, state: CursorParseState) {
    if (!line.trim()) return;
    const parsed = parseCursorEvent(line);
    if (parsed.kind === "malformed") {
        state.diagnostics.push(`Malformed Cursor event: ${parsed.error}`);
        return;
    }
    if (parsed.kind === "unknown") {
        state.diagnostics.push(
            "Unknown Cursor event variant preserved in events.jsonl.",
        );
        return;
    }
    const event = parsed.event;
    if (event.type === "assistant") state.assistant += assistantText(event);
    if (event.type === "result") {
        if (typeof event.result === "string") state.final = event.result;
        if (event.is_error)
            state.resultError = event.result || "Cursor reported an error result.";
    }
}

async function consumeCursorStream(
    stream: Readable,
    eventsPath: string,
    state: CursorParseState,
) {
    const output = await open(eventsPath, "a", 0o600);
    let buffer = "";
    try {
        for await (const chunk of stream) {
            const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(String(chunk));
            await output.write(bytes);
            buffer += bytes.toString("utf8");
            let newline = buffer.indexOf("\n");
            while (newline >= 0) {
                parseLine(buffer.slice(0, newline).replace(/\r$/u, ""), state);
                buffer = buffer.slice(newline + 1);
                newline = buffer.indexOf("\n");
            }
            if (Buffer.byteLength(buffer, "utf8") > MAX_PARSE_BUFFER) {
                state.diagnostics.push(
                    "Cursor event exceeded the 1 MiB parser limit; raw bytes were preserved.",
                );
                buffer = "";
            }
        }
        if (buffer) parseLine(buffer, state);
    } finally {
        await output.close();
    }
}

export class CursorBackend extends BaseBackend {
    readonly name = "agent" as const;
    readonly capabilities: DelegateCapabilities = {
        structuredEvents: true,
        liveText: true,
        toolEvents: true,
        tokenUsage: false,
        cancellation: true,
        resume: false,
        steering: false,
    };

    async start(
        task: DelegateTask,
        signal: AbortSignal,
        onSpawn?: (pid: number | undefined) => void,
    ): Promise<DelegateOutcome> {
        const state: CursorParseState = { assistant: "", diagnostics: [] };
        const args = [
            "--print",
            "--output-format",
            "stream-json",
            "--stream-partial-output",
            "--workspace",
            task.cwd,
            "--trust",
            "--sandbox",
            task.dangerousBypass ? "disabled" : "enabled",
            ...(task.profile === "plan" ? ["--mode", "plan"] : []),
            ...(task.dangerousBypass ? ["--force"] : []),
            task.task,
        ];
        const result = await spawnDelegateProcess({
            executable: this.executable,
            args,
            cwd: task.cwd,
            stderrPath: task.artifacts.log,
            signal,
            onStdout: (stream) =>
                consumeCursorStream(stream, task.artifacts.events, state),
            ...(onSpawn ? { onSpawn } : {}),
        });
        const final = state.final ?? state.assistant;
        await writeFile(task.artifacts.final, final, { mode: 0o600 });
        if (state.diagnostics.length > 0) {
            await appendFile(
                task.artifacts.log,
                `\n${state.diagnostics.join("\n")}\n`,
                { mode: 0o600 },
            );
        }
        return this.outcome(result, state.resultError);
    }
}
