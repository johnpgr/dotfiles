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
import { piAgentDir } from "./config.js";
import type { ArtifactPaths, DelegateJobMetadata } from "./types.js";
import { parseMetadata, stringifyMetadata } from "./validators.js";

const DIRECTORY_MODE = 0o700;
const FILE_MODE = 0o600;
const MAX_METADATA_BYTES = 128 * 1024;

export async function canonicalizeCwd(cwd: string) {
    return realpath(cwd);
}

export function projectIdFor(canonicalCwd: string) {
    const name =
        path.basename(canonicalCwd).replace(/[^a-zA-Z0-9._-]+/gu, "-") || "project";
    const hash = createHash("sha256")
        .update(canonicalCwd)
        .digest("hex")
        .slice(0, 12);
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

export async function createArtifacts(paths: ArtifactPaths, prompt: string) {
    await mkdir(paths.directory, { recursive: true, mode: DIRECTORY_MODE });
    await writeFile(paths.prompt, prompt, { mode: FILE_MODE, flag: "wx" });
}

export async function ensurePrivateFile(filePath: string) {
    const handle = await open(filePath, "a", FILE_MODE);
    await handle.close();
}

export async function writeMetadataAtomic(
    filePath: string,
    metadata: DelegateJobMetadata,
) {
    const temporary = `${filePath}.${process.pid}.${randomBytes(4).toString("hex")}.tmp`;
    await writeFile(temporary, stringifyMetadata(metadata), {
        mode: FILE_MODE,
        flag: "wx",
    });
    await rename(temporary, filePath);
}

export async function readBoundedFile(filePath: string, maxBytes: number) {
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
        return { text, truncated, size: info.size };
    } finally {
        await handle.close();
    }
}

export async function readMetadata(filePath: string) {
    const info = await stat(filePath);
    if (info.size > MAX_METADATA_BYTES) {
        return { success: false as const, error: "metadata exceeds 128 KiB" };
    }
    return parseMetadata(await readFile(filePath, "utf8"));
}

export async function loadProjectMetadata(
    projectId: string,
    maxTracked: number,
) {
    const projectRoot = path.join(artifactRoot(), projectId);
    let entries;
    try {
        entries = await readdir(projectRoot, { withFileTypes: true });
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code === "ENOENT") return [];
        throw error;
    }
    const loaded: DelegateJobMetadata[] = [];
    for (const entry of entries) {
        if (!entry.isDirectory() || !entry.name.startsWith("dlg-")) continue;
        const result = await readMetadata(
            path.join(projectRoot, entry.name, "metadata.json"),
        ).catch(() => undefined);
        if (result?.success) loaded.push(result.data);
    }
    return loaded
        .sort((left, right) => right.createdAt - left.createdAt)
        .slice(0, maxTracked);
}

export async function cleanupRetention(
    projectId: string,
    retentionDays: number,
) {
    const projectRoot = path.join(artifactRoot(), projectId);
    let entries;
    try {
        entries = await readdir(projectRoot, { withFileTypes: true });
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code === "ENOENT") return;
        throw error;
    }
    const cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000;
    await Promise.all(
        entries
            .filter((entry) => entry.isDirectory() && entry.name.startsWith("dlg-"))
            .map(async (entry) => {
                const directory = path.join(projectRoot, entry.name);
                const info = await stat(directory);
                if (info.mtimeMs < cutoff)
                    await rm(directory, { recursive: true, force: true });
            }),
    );
}
