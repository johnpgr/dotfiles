import { constants } from "node:fs";
import { access, readFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { Try } from "./result.ts";
import type { DelegateName, DelegatesConfig } from "./types.ts";
import { validateConfig } from "./validators.ts";

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
    warn: (message: string) => void = () => {},
): Promise<DelegatesConfig> {
    const configPath = path.join(piAgentDir(), "pi-delegates.json");
    const text = await Try(readFile(configPath, "utf8"));
    if (!text.ok) {
        if (text.error.code === "ENOENT") return DEFAULT_CONFIG;
        warn(`Could not read ${configPath}; using safe defaults: ${text.error.message}`);
        return DEFAULT_CONFIG;
    }
    const parsed = Try(() => JSON.parse(text.value) as unknown);
    if (!parsed.ok) {
        warn(`Invalid JSON in ${configPath}; using safe defaults: ${parsed.error.message}`);
        return DEFAULT_CONFIG;
    }
    const result = validateConfig(parsed.value);
    if (!result.ok) {
        warn(`Invalid ${configPath}; using safe defaults: ${result.error.message}`);
        return DEFAULT_CONFIG;
    }
    for (const [name, delegate] of Object.entries(result.config.delegates)) {
        if (delegate.executable && !path.isAbsolute(delegate.executable)) {
            warn(
                `Invalid executable for ${name}; overrides must be absolute. Using safe defaults.`,
            );
            return DEFAULT_CONFIG;
        }
    }
    return result.config;
}

const DEFAULT_EXECUTABLES: Record<DelegateName, string> = {
    codex: "codex",
    claude: "claude",
    agent: "agent",
    agy: "agy",
};

export async function isExecutable(candidate: string) {
    try {
        await access(candidate, process.platform === "win32" ? constants.F_OK : constants.X_OK);
        return true;
    } catch {
        return false;
    }
}

export async function findOnPath(names: string[]) {
    const directories = (process.env.PATH ?? "").split(path.delimiter).filter(Boolean);
    for (const directory of directories) {
        for (const name of names) {
            const candidate = path.join(directory, name);
            if (await isExecutable(candidate)) return candidate;
        }
    }
    return undefined;
}

export async function resolveExecutable(
    name: DelegateName,
    override?: string,
): Promise<string | undefined> {
    if (override) return (await isExecutable(override)) ? override : undefined;
    const command = DEFAULT_EXECUTABLES[name];
    const extensions =
        process.platform === "win32"
            ? (process.env.PATHEXT ?? ".EXE;.CMD;.BAT;.COM").split(";")
            : [""];
    return findOnPath(extensions.map((extension) => `${command}${extension}`));
}
