import { constants } from "node:fs";
import { access, readFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import type { DelegateName, DelegatesConfig } from "./types.js";
import { validateConfig } from "./validators.js";

export const DEFAULT_CONFIG: DelegatesConfig = {
    maxConcurrent: 4,
    maxTracked: 64,
    maxPreviewBytes: 4096,
    maxAttachBytes: 6144,
    indexFinalOutput: true,
    indexExecutionLog: false,
    artifactRetentionDays: 14,
    delegates: {
        codex: { enabled: true, timeoutMinutes: 60 },
        claude: { enabled: true, timeoutMinutes: 60 },
        agent: { enabled: true, timeoutMinutes: 30 },
        agy: {
            enabled: true,
            timeoutMinutes: 30,
            allowDangerousBypass: true,
        },
    },
};

export function piAgentDir() {
    return process.env.PI_AGENT_DIR ?? path.join(os.homedir(), ".pi", "agent");
}

export async function loadConfig(
    warn: (message: string) => void = () => { },
): Promise<DelegatesConfig> {
    const configPath = path.join(piAgentDir(), "delegates.json");
    let text: string;
    try {
        text = await readFile(configPath, "utf8");
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code === "ENOENT")
            return DEFAULT_CONFIG;
        warn(`Could not read ${configPath}; using safe defaults: ${String(error)}`);
        return DEFAULT_CONFIG;
    }
    let value: unknown;
    try {
        value = JSON.parse(text);
    } catch (error) {
        warn(
            `Invalid JSON in ${configPath}; using safe defaults: ${String(error)}`,
        );
        return DEFAULT_CONFIG;
    }
    const result = validateConfig(value);
    if (!result.success) {
        warn(`Invalid ${configPath}; using safe defaults: ${result.error}`);
        return DEFAULT_CONFIG;
    }
    for (const [name, delegate] of Object.entries(result.data.delegates)) {
        if (delegate.executable && !path.isAbsolute(delegate.executable)) {
            warn(
                `Invalid executable for ${name}; overrides must be absolute. Using safe defaults.`,
            );
            return DEFAULT_CONFIG;
        }
    }
    return result.data;
}

const DEFAULT_EXECUTABLES: Record<DelegateName, string> = {
    codex: "codex",
    claude: "claude",
    agent: "agent",
    agy: "agy",
};

async function isExecutable(candidate: string) {
    try {
        await access(
            candidate,
            process.platform === "win32" ? constants.F_OK : constants.X_OK,
        );
        return true;
    } catch {
        return false;
    }
}

export async function resolveExecutable(
    name: DelegateName,
    override?: string,
): Promise<string | undefined> {
    if (override) return (await isExecutable(override)) ? override : undefined;
    const command = DEFAULT_EXECUTABLES[name];
    const directories = (process.env.PATH ?? "")
        .split(path.delimiter)
        .filter(Boolean);
    const extensions =
        process.platform === "win32"
            ? (process.env.PATHEXT ?? ".EXE;.CMD;.BAT;.COM").split(";")
            : [""];
    for (const directory of directories) {
        for (const extension of extensions) {
            const candidate = path.join(directory, `${command}${extension}`);
            if (await isExecutable(candidate)) return candidate;
        }
    }
    return undefined;
}
