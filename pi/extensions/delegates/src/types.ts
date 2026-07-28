import type { Static } from "typebox";
import type {
    DelegateJobMetadataSchema,
    DelegateNameSchema,
    DelegateProfileSchema,
    DelegateStatusSchema,
    DelegatesConfigSchema,
    KnownCursorEventSchema,
} from "./schema.ts";

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

export interface DelegateOutcome {
    exitCode?: number;
    signal?: NodeJS.Signals;
    error?: string;
}

export interface DelegateBackend {
    readonly name: DelegateName;
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
}

export interface SearchResult {
    output: string;
    truncated: boolean;
    warning?: string;
}
