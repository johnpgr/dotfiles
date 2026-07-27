import type {
    DelegateBackend,
    DelegateCapabilities,
    DelegateName,
    DelegateOutcome,
} from "../types.js";
import type { ProcessResult } from "../process.js";

export abstract class BaseBackend implements DelegateBackend {
    abstract readonly name: DelegateName;
    abstract readonly capabilities: DelegateCapabilities;

    constructor(protected readonly executable: string) { }

    available() {
        return Boolean(this.executable);
    }

    protected outcome(result: ProcessResult, error?: string): DelegateOutcome {
        return {
            ...(result.exitCode !== undefined ? { exitCode: result.exitCode } : {}),
            ...(result.signal ? { signal: result.signal } : {}),
            ...(error || result.error ? { error: error ?? result.error } : {}),
            changedFiles: [],
        };
    }

    abstract start(
        task: Parameters<DelegateBackend["start"]>[0],
        signal: AbortSignal,
        onSpawn?: (pid: number | undefined) => void,
    ): Promise<DelegateOutcome>;
}
