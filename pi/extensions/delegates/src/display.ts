import type { Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import type { DelegateJobMetadata, DelegateResultEntryData } from "./types.js";

export function formatDuration(milliseconds: number) {
    if (milliseconds < 1000) return `${milliseconds}ms`;
    const seconds = Math.round(milliseconds / 1000);
    if (seconds < 60) return `${seconds}s`;
    return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
}

export function formatJob(metadata: DelegateJobMetadata) {
    const elapsed =
        (metadata.settledAt ?? Date.now()) -
        (metadata.startedAt ?? metadata.createdAt);
    const danger = metadata.dangerousBypass ? " · DANGEROUS BYPASS" : "";
    return `${metadata.id} · ${metadata.delegate} · ${metadata.profile}${danger} · ${metadata.status} · ${formatDuration(elapsed)}`;
}

export function statusCounts(jobs: DelegateJobMetadata[]) {
    const count = (status: DelegateJobMetadata["status"]) =>
        jobs.filter((job) => job.status === status).length;
    return {
        queued: count("queued"),
        running: count("running"),
        done: count("done"),
        error: count("error"),
        stopped: count("stopped"),
    };
}

export function renderDelegateEntry(
    entry: { data?: DelegateResultEntryData },
    options: { expanded: boolean },
    theme: Theme,
) {
    const data = entry.data;
    if (!data)
        return new Text(theme.fg("error", "Invalid delegate result entry"), 0, 0);
    const failed = data.status === "error" || data.status === "stopped";
    const icon = failed ? theme.fg("error", "x") : theme.fg("success", "■");
    const header = `${icon} ${theme.fg("accent", theme.bold(`${data.delegate} · ${data.id}`))}${theme.fg("muted", ` · ${data.profile} · ${data.status} · ${formatDuration(data.elapsedMs)}`)}`;
    const details = [
        data.preview || "(no final output)",
        data.truncated ? "[preview truncated]" : "",
        data.warnings.map((warning) => `Warning: ${warning}`).join("\n"),
        data.changedFiles.length > 0
            ? `Changed: ${data.changedFiles.join(", ")}`
            : "",
        options.expanded ? `Artifacts: ${data.artifactPath}` : "",
        options.expanded && data.contextSources.length > 0
            ? `Context sources: ${data.contextSources.join(", ")}`
            : "",
    ].filter(Boolean);
    const visible = options.expanded ? details : details.slice(0, 2);
    return new Text(`${header}\n${visible.join("\n")}`, 0, 0);
}
