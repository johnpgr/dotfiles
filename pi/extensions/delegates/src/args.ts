import type { DelegateProfile } from "./types.ts";

export interface LaunchArguments {
    profile: DelegateProfile;
    dangerousBypass: boolean;
    task: string;
}

function isWhitespace(character: string) {
    return /\s/u.test(character);
}

export function parseLaunchArguments(raw: string): LaunchArguments {
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
                throw new Error("Choose only one of --plan or --implementation.");
            }
            profile = next;
            explicitProfile = true;
            continue;
        }
        if (token === "--dangerous") {
            dangerousBypass = true;
            continue;
        }
        throw new Error(`Unknown option: ${token}`);
    }

    // Slice the raw input so task newlines, blank lines, and indentation survive.
    const task = raw.slice(pos).replace(/\s+$/u, "");
    if (!task) throw new Error("A delegate task is required.");
    if (Buffer.byteLength(task, "utf8") > 32 * 1024) {
        throw new Error("Delegate task exceeds the 32 KiB limit.");
    }
    if (dangerousBypass && profile !== "implementation") {
        throw new Error("--dangerous requires --implementation.");
    }
    return { profile, dangerousBypass, task };
}

export function parseJobId(raw: string) {
    const id = raw.trim();
    if (!/^dlg-[a-z0-9-]+$/u.test(id)) throw new Error("A valid job ID is required.");
    return id;
}

export function parseSearchArguments(raw: string) {
    const match = raw.trim().match(/^(dlg-[a-z0-9-]+)\s+(.+)$/su);
    if (!match?.[1] || !match[2]?.trim()) {
        throw new Error("Usage: /delegate-search <job-id> <query>");
    }
    return { id: match[1], query: match[2].trim() };
}
