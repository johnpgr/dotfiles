import type { ChildProcess } from "node:child_process";
import type { Static } from "typebox";
import type {
    DelegateJobMetadataSchema,
    DelegateNameSchema,
    DelegateProfileSchema,
    DelegateStatusSchema,
    DelegatesConfigSchema,
    KnownCursorEventSchema,
} from "./schema.js";

export type DelegateName = Static<typeof DelegateNameSchema>;
export type DelegateProfile = Static<typeof DelegateProfileSchema>;
export type DelegateStatus = Static<typeof DelegateStatusSchema>;
export type DelegatesConfig = Static<typeof DelegatesConfigSchema>;
export type DelegateJobMetadata = Static<typeof DelegateJobMetadataSchema>;
export type KnownCursorEvent = Static<typeof KnownCursorEventSchema>;

export interface ArtifactPaths {
    directory: string;
    metadata: string;
    prompt: string;
    final: string;
    log: string;
    events: string;
}

export interface DelegateTask {
    id: string;
    task: string;
    cwd: string;
    profile: DelegateProfile;
    dangerousBypass: boolean;
    timeoutMs: number;
    artifacts: ArtifactPaths;
}

export interface DelegateCapabilities {
    structuredEvents: boolean;
    liveText: boolean;
    toolEvents: boolean;
    tokenUsage: boolean;
    cancellation: boolean;
    resume: boolean;
    steering: boolean;
}

export interface DelegateOutcome {
    exitCode?: number;
    signal?: NodeJS.Signals;
    error?: string;
    changedFiles: string[];
}

export interface RunningProcess {
    child: ChildProcess;
    closed: Promise<void>;
    terminate(): Promise<void>;
}

export interface DelegateBackend {
    readonly name: DelegateName;
    readonly capabilities: DelegateCapabilities;
    available(): boolean;
    start(
        task: DelegateTask,
        signal: AbortSignal,
        onSpawn?: (pid: number | undefined) => void,
    ): Promise<DelegateOutcome>;
}

export interface DelegateResultEntryData {
    id: string;
    delegate: DelegateName;
    profile: DelegateProfile;
    status: DelegateStatus;
    elapsedMs: number;
    preview: string;
    truncated: boolean;
    artifactPath: string;
    contextSources: string[];
    warnings: string[];
    changedFiles: string[];
}

export interface SearchResult {
    output: string;
    truncated: boolean;
    warning?: string;
}
