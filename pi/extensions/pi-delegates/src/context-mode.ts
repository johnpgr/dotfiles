import { stat } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { findOnPath, isExecutable } from "./config.ts";
import { exitFailure, spawnDelegateProcess } from "./process.ts";
import type { ArtifactPaths, DelegateJobMetadata, DelegatesConfig, SearchResult } from "./types.ts";

export async function resolveContextMode() {
    const override = process.env.CONTEXT_MODE_BIN;
    if (override) return (await isExecutable(override)) ? override : undefined;
    const local = path.join(
        os.homedir(),
        ".pi",
        "agent",
        "npm",
        "node_modules",
        ".bin",
        process.platform === "win32" ? "context-mode.cmd" : "context-mode",
    );
    if (await isExecutable(local)) return local;
    const names =
        process.platform === "win32" ? ["context-mode.cmd", "context-mode.exe"] : ["context-mode"];
    return findOnPath(names);
}

async function exists(filePath: string) {
    try {
        return (await stat(filePath)).isFile();
    } catch {
        return false;
    }
}

function linkedTimeout(parent: AbortSignal, timeoutMs: number) {
    const controller = new AbortController();
    const abort = () => controller.abort();
    parent.addEventListener("abort", abort, { once: true });
    const timer = setTimeout(abort, timeoutMs);
    timer.unref();
    return {
        signal: controller.signal,
        dispose() {
            clearTimeout(timer);
            parent.removeEventListener("abort", abort);
        },
    };
}

export async function indexDelegateArtifacts(
    executablePath: string | undefined,
    config: DelegatesConfig,
    metadata: DelegateJobMetadata,
    artifacts: ArtifactPaths,
    signal: AbortSignal,
) {
    if (!executablePath) {
        metadata.warnings.push(
            "Context Mode executable was not found; artifacts were not indexed.",
        );
        return;
    }
    const candidates = [
        ...(config.indexFinalOutput ? [{ path: artifacts.final, suffix: "final" }] : []),
        ...(config.indexExecutionLog
            ? [
                  { path: artifacts.log, suffix: "log" },
                  { path: artifacts.events, suffix: "events" },
              ]
            : []),
    ];
    for (const candidate of candidates) {
        if (signal.aborted || !(await exists(candidate.path))) continue;
        const source = `delegate:${metadata.id}:${candidate.suffix}`;
        const timeout = linkedTimeout(signal, 30_000);
        const contextLog = path.join(artifacts.directory, ".context-mode.log");
        const result = await spawnDelegateProcess({
            executable: executablePath,
            args: ["index", candidate.path, "--project", metadata.cwd, "--source", source],
            cwd: metadata.cwd,
            stdoutPath: contextLog,
            stderrPath: contextLog,
            signal: timeout.signal,
        });
        timeout.dispose();
        if (exitFailure(result)) {
            metadata.warnings.push(
                `Context Mode could not index ${candidate.suffix}: ${!result.ok ? result.error.message : `exit ${result.exitCode}`}`,
            );
            continue;
        }
        metadata.contextSources.push(source);
    }
}

export async function searchDelegateArtifacts(
    executablePath: string | undefined,
    metadata: DelegateJobMetadata,
    artifacts: ArtifactPaths,
    query: string,
    maxBytes: number,
    parentSignal = new AbortController().signal,
): Promise<SearchResult> {
    if (!executablePath) {
        return {
            output: "",
            truncated: false,
            warning: "Context Mode executable was not found.",
        };
    }
    const timeout = linkedTimeout(parentSignal, 15_000);
    const chunks: Buffer[] = [];
    let retained = 0;
    let truncated = false;
    const result = await spawnDelegateProcess({
        executable: executablePath,
        args: [
            "search",
            query,
            "--project",
            metadata.cwd,
            "--source",
            `delegate:${metadata.id}`,
            "--limit",
            "5",
        ],
        cwd: metadata.cwd,
        stderrPath: path.join(artifacts.directory, ".context-mode.log"),
        signal: timeout.signal,
        onStdout: async (stream) => {
            for await (const chunk of stream) {
                const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(String(chunk));
                const remaining = maxBytes - retained;
                if (remaining > 0) {
                    const kept = bytes.subarray(0, remaining);
                    chunks.push(kept);
                    retained += kept.length;
                }
                if (bytes.length > remaining) truncated = true;
            }
        },
    });
    timeout.dispose();
    return {
        output: Buffer.concat(chunks).toString("utf8"),
        truncated,
        ...(exitFailure(result)
            ? {
                  warning: !result.ok
                      ? result.error.message
                      : `Context Mode exited with ${result.exitCode}.`,
              }
            : {}),
    };
}
