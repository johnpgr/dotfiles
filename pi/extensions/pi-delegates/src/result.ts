export interface DelegateError {
    readonly message: string;
    readonly code?: string | undefined;
    readonly cause?: unknown;
}

export type Result<T extends object, E = DelegateError> =
    | (T & { readonly ok: true })
    | { readonly ok: false; readonly error: E };

export type Unit = Record<string, never>;

export type WithoutOk<T> = T extends { ok: unknown } ? never : T;

/** Shared singleton for void success — `return Success;` */
export const Success = Ok({}) as Result<Unit>;

/**
 * Stamp a fresh object literal as success. The argument MUST be a new object
 * literal created at the return site — never reuse a parsed or validated payload
 * (TypeBox additionalProperties:false treats a stamped object as invalid, and
 * `ok` is non-configurable so it cannot be removed).
 */
export function Ok<T extends object>(result: WithoutOk<T>): Result<T, never> {
    if (typeof result !== "object" || result === null) {
        throw new Error("Ok() must be passed an object");
    }

    Object.defineProperty(result, "ok", {
        value: true,
        enumerable: false,
        writable: false,
    });

    return result as Result<T, never>;
}

export function Err<E = DelegateError>(error: E): Result<never, E> {
    const result = { error };
    Object.defineProperty(result, "ok", {
        value: false,
        enumerable: false,
        writable: false,
    });
    return result as Result<never, E>;
}

export function toError(value: unknown): DelegateError {
    if (value instanceof Error) {
        return {
            message: value.message,
            code: (value as NodeJS.ErrnoException).code,
            cause: value,
        };
    }
    return { message: String(value), cause: value };
}

// `() => Promise<T>` must precede `() => T`: TypeScript picks the first matching
// overload, and the sync one would otherwise bind T = Promise<X> and declare a
// synchronous Result while this returns a Promise at runtime.
export function Try<T>(promise: Promise<T>): Promise<Result<{ value: T }, DelegateError>>;
export function Try<T>(fn: () => Promise<T>): Promise<Result<{ value: T }, DelegateError>>;
export function Try<T>(fn: () => T): Result<{ value: T }, DelegateError>;
export function Try<T>(
    fnOrPromise: Promise<T> | (() => T | Promise<T>),
): Result<{ value: T }, DelegateError> | Promise<Result<{ value: T }, DelegateError>> {
    if (isPromise(fnOrPromise)) {
        return fnOrPromise.then((value) => Ok({ value })).catch((error) => Err(toError(error)));
    }

    try {
        const result = fnOrPromise();
        if (isPromise(result)) {
            return (result as Promise<T>)
                .then((value) => Ok({ value }))
                .catch((error) => Err(toError(error)));
        }
        return Ok({ value: result as T });
    } catch (error) {
        return Err(toError(error));
    }
}

export function TryResult<T extends object>(promise: Promise<Result<T>>): Promise<Result<T>>;
export function TryResult<T extends object>(fn: () => Result<T>): Result<T>;
export function TryResult<T extends object>(fn: () => Promise<Result<T>>): Promise<Result<T>>;
export function TryResult<T extends object>(
    fnOrPromise: Promise<Result<T>> | (() => Result<T> | Promise<Result<T>>),
): Result<T> | Promise<Result<T>> {
    if (isPromise(fnOrPromise)) {
        return fnOrPromise.catch((error) => Err(toError(error)));
    }

    try {
        const result = fnOrPromise();
        if (isPromise(result)) {
            return (result as Promise<Result<T>>).catch((error) => Err(toError(error)));
        }
        return result;
    } catch (error) {
        return Err(toError(error));
    }
}

export function unwrapOr<T extends object>(result: Result<T>, fallback: T): T {
    return result.ok ? result : fallback;
}

export function context<T extends object>(result: Result<T>, prefix: string): Result<T> {
    if (result.ok) return result;
    return Err({
        ...result.error,
        message: `${prefix}: ${result.error.message}`,
    });
}

/** Deliberately discard a Result — greppable replacement for `.catch(() => {})`. */
export function ignore(_result: Result<object>): void {}

function isPromise(x: unknown): x is Promise<unknown> {
    if (x instanceof Promise) return true;
    if (typeof x !== "object" || x === null || !("then" in x)) return false;
    const tag = (x as { [Symbol.toStringTag]?: string })[Symbol.toStringTag];
    return tag === "PrismaPromise" || tag === "Promise";
}
