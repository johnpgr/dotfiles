import { createHash, randomBytes } from "node:crypto";
import {
    mkdir,
    open,
    readdir,
    readFile,
    realpath,
    rename,
    rm,
    stat,
    writeFile,
} from "node:fs/promises";
import path from "node:path";
import { StringDecoder } from "node:string_decoder";
import { piAgentDir } from "./config.ts";
import { Err, Ok, Success, Try, type Result, type Unit } from "./result.ts";
import type { ArtifactPaths, DelegateJobMetadata } from "./types.ts";
import { parseMetadata, stringifyMetadata } from "./validators.ts";

const DIRECTORY_MODE = 0o700;
const FILE_MODE = 0o600;
const MAX_METADATA_BYTES = 128 * 1024;

export interface BoundedRead {
    text: string;
    truncated: boolean;
}

export async function canonicalizeCwd(cwd: string): Promise<Result<{ path: string }>> {
    const result = await Try(realpath(cwd));
    if (!result.ok) return result;
    return Ok({ path: result.value });
}

export function projectIdFor(canonicalCwd: string) {
    const name = path.basename(canonicalCwd).replace(/[^a-zA-Z0-9._-]+/gu, "-") || "project";
    const hash = createHash("sha256").update(canonicalCwd).digest("hex").slice(0, 12);
    return `${name.slice(0, 80)}-${hash}`;
}

export function newJobId(now = Date.now()) {
    return `dlg-${now.toString(36)}-${randomBytes(5).toString("hex")}`;
}

export function artifactRoot() {
    return path.join(piAgentDir(), "delegate-runs");
}

export function artifactPaths(projectId: string, jobId: string): ArtifactPaths {
    const directory = path.join(artifactRoot(), projectId, jobId);
    return {
        directory,
        metadata: path.join(directory, "metadata.json"),
        prompt: path.join(directory, "prompt.txt"),
        final: path.join(directory, "final.md"),
        log: path.join(directory, "execution.log"),
        events: path.join(directory, "events.jsonl"),
    };
}

export async function createArtifacts(paths: ArtifactPaths, prompt: string): Promise<Result<Unit>> {
    const directory = await Try(mkdir(paths.directory, { recursive: true, mode: DIRECTORY_MODE }));
    if (!directory.ok) return directory;
    const written = await Try(writeFile(paths.prompt, prompt, { mode: FILE_MODE, flag: "wx" }));
    if (!written.ok) return written;
    return Success;
}

export async function ensurePrivateFile(filePath: string): Promise<Result<Unit>> {
    const opened = await Try(async () => {
        const handle = await open(filePath, "a", FILE_MODE);
        await handle.close();
    });
    if (!opened.ok) return opened;
    return Success;
}

export async function writeMetadataAtomic(
    filePath: string,
    metadata: DelegateJobMetadata,
): Promise<Result<Unit>> {
    const text = stringifyMetadata(metadata);
    if (!text.ok) return text;
    const temporary = `${filePath}.${process.pid}.${randomBytes(4).toString("hex")}.tmp`;
    const written = await Try(
        writeFile(temporary, text.text, {
            mode: FILE_MODE,
            flag: "wx",
        }),
    );
    if (!written.ok) return written;
    const renamed = await Try(rename(temporary, filePath));
    if (!renamed.ok) return renamed;
    return Success;
}

export async function readBoundedFile(
    filePath: string,
    maxBytes: number,
): Promise<Result<BoundedRead>> {
    const result = await Try(
        (async (): Promise<BoundedRead> => {
            const handle = await open(filePath, "r");
            try {
                const info = await handle.stat();
                const length = Math.min(info.size, maxBytes + 1);
                const buffer = Buffer.alloc(length);
                const { bytesRead } = await handle.read(buffer, 0, length, 0);
                const truncated = info.size > maxBytes;
                const used = buffer.subarray(
                    0,
                    truncated ? Math.min(bytesRead, maxBytes) : bytesRead,
                );
                const decoder = new StringDecoder("utf8");
                const text = decoder.write(used) + (truncated ? "" : decoder.end());
                return { text, truncated };
            } finally {
                await handle.close();
            }
        })(),
    );
    if (!result.ok) return result;
    return Ok({ text: result.value.text, truncated: result.value.truncated });
}

export async function readBoundedTailFile(
    filePath: string,
    maxBytes: number,
): Promise<Result<BoundedRead>> {
    const result = await Try(
        (async (): Promise<BoundedRead> => {
            const handle = await open(filePath, "r");
            try {
                const info = await handle.stat();
                const truncated = info.size > maxBytes;
                const start = Math.max(0, info.size - maxBytes);
                const length = info.size - start;
                const buffer = Buffer.alloc(length);
                const { bytesRead } = await handle.read(buffer, 0, length, start);
                let used = buffer.subarray(0, bytesRead);
                if (truncated && start > 0) {
                    let offset = 0;
                    while (offset < used.length && offset < 4) {
                        const byte = used[offset]!;
                        if (byte < 0x80 || byte >= 0xc0) break;
                        offset++;
                    }
                    used = used.subarray(offset);
                }
                const decoder = new StringDecoder("utf8");
                const text = decoder.write(used) + decoder.end();
                return { text, truncated };
            } finally {
                await handle.close();
            }
        })(),
    );
    if (!result.ok) return result;
    return Ok({ text: result.value.text, truncated: result.value.truncated });
}

export async function readMetadata(
    filePath: string,
): Promise<Result<{ metadata: DelegateJobMetadata }>> {
    const info = await Try(stat(filePath));
    if (!info.ok) return info;
    if (info.value.size > MAX_METADATA_BYTES) {
        return Err({ message: "metadata exceeds 128 KiB" });
    }
    const text = await Try(readFile(filePath, "utf8"));
    if (!text.ok) return text;
    return parseMetadata(text.value);
}

export async function loadProjectMetadata(
    projectId: string,
    maxTracked: number,
): Promise<Result<{ jobs: DelegateJobMetadata[] }>> {
    const projectRoot = path.join(artifactRoot(), projectId);
    const entries = await Try(readdir(projectRoot, { withFileTypes: true }));
    if (!entries.ok) return entries.error.code === "ENOENT" ? Ok({ jobs: [] }) : entries;

    const loaded: DelegateJobMetadata[] = [];
    for (const entry of entries.value) {
        if (!entry.isDirectory() || !entry.name.startsWith("dlg-")) continue;
        const result = await readMetadata(path.join(projectRoot, entry.name, "metadata.json"));
        if (result.ok) loaded.push(result.metadata);
    }
    return Ok({
        jobs: loaded.sort((left, right) => right.createdAt - left.createdAt).slice(0, maxTracked),
    });
}

export async function cleanupRetention(
    projectId: string,
    retentionDays: number,
): Promise<Result<Unit>> {
    const projectRoot = path.join(artifactRoot(), projectId);
    const entries = await Try(readdir(projectRoot, { withFileTypes: true }));
    if (!entries.ok) return entries.error.code === "ENOENT" ? Success : entries;

    const cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000;
    const outcomes = await Promise.all(
        entries.value
            .filter((entry) => entry.isDirectory() && entry.name.startsWith("dlg-"))
            .map(async (entry) => {
                const directory = path.join(projectRoot, entry.name);
                const info = await Try(stat(directory));
                if (!info.ok) return info.error.code === "ENOENT" ? Success : info;
                if (info.value.mtimeMs < cutoff) {
                    const removed = await Try(rm(directory, { recursive: true, force: true }));
                    if (!removed.ok) return removed;
                }
                return Success;
            }),
    );
    const failure = outcomes.find((outcome) => !outcome.ok);
    return failure ?? Success;
}
