import type { DelegateProfile } from "./types.js";

export interface LaunchArguments {
    profile: DelegateProfile;
    dangerousBypass: boolean;
    task: string;
}

export function parseLaunchArguments(raw: string): LaunchArguments {
    const tokens = raw.trim().split(/\s+/u).filter(Boolean);
    let profile: DelegateProfile = "plan";
    let explicitProfile = false;
    let dangerousBypass = false;
    let index = 0;
    for (; index < tokens.length; index++) {
        const token = tokens[index];
        if (token === "--") {
            index++;
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
        if (token?.startsWith("--")) throw new Error(`Unknown option: ${token}`);
        break;
    }
    const task = tokens.slice(index).join(" ").trim();
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
    if (!/^dlg-[a-z0-9-]+$/u.test(id))
        throw new Error("A valid job ID is required.");
    return id;
}

export function parseSearchArguments(raw: string) {
    const match = raw.trim().match(/^(dlg-[a-z0-9-]+)\s+(.+)$/su);
    if (!match?.[1] || !match[2]?.trim()) {
        throw new Error("Usage: /delegate-search <job-id> <query>");
    }
    return { id: match[1], query: match[2].trim() };
}
