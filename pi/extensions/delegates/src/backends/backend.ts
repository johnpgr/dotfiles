import type { DelegateBackend, DelegateName, DelegateOutcome } from "../types.ts";
import type { ProcessResult } from "../process.ts";

export abstract class BaseBackend implements DelegateBackend {
    abstract readonly name: DelegateName;

    constructor(protected readonly executable: string) {}

    protected outcome(result: ProcessResult, error?: string): DelegateOutcome {
        return {
            ...(result.exitCode !== undefined ? { exitCode: result.exitCode } : {}),
            ...(result.signal ? { signal: result.signal } : {}),
            ...(error || result.error ? { error: error ?? result.error } : {}),
        };
    }

    abstract start(
        task: Parameters<DelegateBackend["start"]>[0],
        signal: AbortSignal,
        onSpawn?: (pid: number | undefined) => void,
    ): Promise<DelegateOutcome>;
}
