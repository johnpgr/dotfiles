import { Err, Ok, type Result } from "./result.ts";
import type { DelegateProfile } from "./types.ts";

export interface LaunchArguments {
    profile: DelegateProfile;
    dangerousBypass: boolean;
    task: string;
}

export interface SearchArguments {
    id: string;
    query: string;
}

function isWhitespace(character: string) {
    return /\s/u.test(character);
}

export function parseLaunchArguments(raw: string): Result<LaunchArguments> {
    let profile: DelegateProfile = "plan";
    let explicitProfile = false;
    let dangerousBypass = false;
    let pos = 0;

    const skipWhitespace = () => {
        while (pos < raw.length && isWhitespace(raw[pos]!)) pos++;
    };

    const readToken = () => {
        const start = pos;
        while (pos < raw.length && !isWhitespace(raw[pos]!)) pos++;
        return raw.slice(start, pos);
    };

    for (;;) {
        skipWhitespace();
        if (pos >= raw.length) break;
        if (!raw.startsWith("--", pos)) break;

        const token = readToken();
        if (token === "--") {
            skipWhitespace();
            break;
        }
        if (token === "--plan" || token === "--implementation") {
            const next = token.slice(2) as DelegateProfile;
            if (explicitProfile && profile !== next) {
                return Err({ message: "Choose only one of --plan or --implementation." });
            }
            profile = next;
            explicitProfile = true;
            continue;
        }
        if (token === "--dangerous") {
            dangerousBypass = true;
            continue;
        }
        return Err({ message: `Unknown option: ${token}` });
    }

    // Slice the raw input so task newlines, blank lines, and indentation survive.
    const task = raw.slice(pos).replace(/\s+$/u, "");
    if (!task) return Err({ message: "A delegate task is required." });
    if (Buffer.byteLength(task, "utf8") > 32 * 1024) {
        return Err({ message: "Delegate task exceeds the 32 KiB limit." });
    }
    if (dangerousBypass && profile !== "implementation") {
        return Err({ message: "--dangerous requires --implementation." });
    }
    return Ok({ profile, dangerousBypass, task });
}

export function parseJobId(raw: string): Result<{ id: string }> {
    const id = raw.trim();
    if (!/^dlg-[a-z0-9-]+$/u.test(id)) {
        return Err({ message: "A valid job ID is required." });
    }
    return Ok({ id });
}

export function parseSearchArguments(raw: string): Result<SearchArguments> {
    const match = raw.trim().match(/^(dlg-[a-z0-9-]+)\s+(.+)$/su);
    if (!match?.[1] || !match[2]?.trim()) {
        return Err({ message: "Usage: /delegate-search <job-id> <query>" });
    }
    return Ok({ id: match[1], query: match[2].trim() });
}
