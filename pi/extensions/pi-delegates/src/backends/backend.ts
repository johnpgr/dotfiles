import type { DelegateBackend, DelegateName } from "../types.ts";

export abstract class BaseBackend implements DelegateBackend {
    abstract readonly name: DelegateName;

    constructor(protected readonly executable: string) {}

    abstract start(
        task: Parameters<DelegateBackend["start"]>[0],
        signal: AbortSignal,
        onSpawn?: (pid: number | undefined) => void,
    ): ReturnType<DelegateBackend["start"]>;
}
