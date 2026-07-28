import { spawn, type ChildProcess } from "node:child_process";
import { open, type FileHandle } from "node:fs/promises";
import type { Readable } from "node:stream";
import { Err, Ok, toError, type DelegateError, type Result } from "./result.ts";
import type { ProcessExit } from "./types.ts";

const FORCE_KILL_AFTER_MS = 1500;
const CLOSE_AFTER_KILL_MS = 750;
const closedChildren = new WeakSet<ChildProcess>();

/**
 * A nonzero exit is a successful run with a failing result, not an `Err` — the
 * exit code is recorded in metadata. This folds both into one reason, or
 * `undefined` when the delegate exited cleanly.
 */
export function exitFailure(result: Result<ProcessExit>): DelegateError | undefined {
    if (!result.ok) return result.error;
    const code = result.exitCode ?? 0;
    if (code !== 0) return { message: `Delegate exited with code ${result.exitCode}.` };
    return undefined;
}

function waitForClose(child: ChildProcess, timeoutMs: number) {
    return new Promise<boolean>((resolve) => {
        if (closedChildren.has(child)) {
            resolve(true);
            return;
        }
        const onClose = () => {
            clearTimeout(timer);
            resolve(true);
        };
        const timer = setTimeout(() => {
            child.off("close", onClose);
            resolve(false);
        }, timeoutMs);
        timer.unref();
        child.once("close", onClose);
    });
}

async function taskkill(pid: number, force: boolean) {
    await new Promise<void>((resolve) => {
        const killer = spawn("taskkill", ["/pid", String(pid), "/T", ...(force ? ["/F"] : [])], {
            stdio: "ignore",
            windowsHide: true,
        });
        killer.once("error", () => resolve());
        killer.once("close", () => resolve());
    });
}

export function signalProcessTree(child: ChildProcess, signal: NodeJS.Signals) {
    if (!child.pid) return;
    if (process.platform === "win32") {
        void taskkill(child.pid, signal === "SIGKILL");
        return;
    }
    try {
        process.kill(-child.pid, signal);
        return;
    } catch {
        try {
            child.kill(signal);
        } catch {
            // The process has already exited.
        }
    }
}

export async function terminateProcessTree(child: ChildProcess) {
    // `exit` is not enough: descendants may keep inherited stdio and the process
    // group alive. Only `close` proves the tree's inherited streams are gone.
    if (closedChildren.has(child)) return;
    if (process.platform === "win32" && child.pid) await taskkill(child.pid, false);
    else signalProcessTree(child, "SIGTERM");
    if (await waitForClose(child, FORCE_KILL_AFTER_MS)) return;
    if (process.platform === "win32" && child.pid) await taskkill(child.pid, true);
    else signalProcessTree(child, "SIGKILL");
    await waitForClose(child, CLOSE_AFTER_KILL_MS);
}

export interface SpawnDelegateOptions {
    executable: string;
    args: string[];
    cwd: string;
    stdin?: string;
    stdoutPath?: string;
    stderrPath: string;
    signal: AbortSignal;
    onSpawn?: (pid: number | undefined) => void;
    onStdout?: (stream: Readable) => Promise<void> | void;
}

export async function spawnDelegateProcess(
    options: SpawnDelegateOptions,
): Promise<Result<ProcessExit>> {
    if (options.signal.aborted) {
        return Err({ message: "Delegate was cancelled before launch." });
    }
    const handles: FileHandle[] = [];
    try {
        const stderr = await open(options.stderrPath, "a", 0o600);
        handles.push(stderr);
        const stdout = options.stdoutPath ? await open(options.stdoutPath, "a", 0o600) : undefined;
        if (stdout) handles.push(stdout);
        if (options.signal.aborted) {
            return Err({ message: "Delegate was cancelled before launch." });
        }

        const child = spawn(options.executable, options.args, {
            cwd: options.cwd,
            env: process.env,
            shell: false,
            detached: process.platform !== "win32",
            windowsHide: true,
            stdio: [
                options.stdin === undefined ? "ignore" : "pipe",
                stdout?.fd ?? "pipe",
                stderr.fd,
            ],
        });
        child.once("close", () => closedChildren.add(child));
        options.onSpawn?.(child.pid);
        let processError: string | undefined;
        let closed = false;
        let exitCleanup: NodeJS.Timeout | undefined;
        const abort = () => void terminateProcessTree(child);
        options.signal.addEventListener("abort", abort, { once: true });
        // Close the spawn-to-listener race: an abort that landed after the
        // pre-spawn check but before listener registration must still tear down
        // the newly created process group.
        if (options.signal.aborted) abort();

        let stdoutError: string | undefined;
        const stdoutWork =
            child.stdout && options.onStdout
                ? Promise.resolve()
                      .then(() => options.onStdout?.(child.stdout!))
                      .catch(async (error: unknown) => {
                          stdoutError = toError(error).message;
                          await terminateProcessTree(child);
                      })
                : Promise.resolve();
        if (options.stdin !== undefined) {
            child.stdin?.on("error", () => {
                // Early child exit can close stdin before the prompt is fully written.
            });
            child.stdin?.end(options.stdin);
        }

        const exit = await new Promise<ProcessExit>((resolve) => {
            child.once("error", (error) => {
                processError = toError(error).message;
            });
            child.once("exit", () => {
                exitCleanup = setTimeout(() => {
                    if (!closed) void terminateProcessTree(child);
                }, 500);
                exitCleanup.unref();
            });
            child.once("close", (code, signal) => {
                closed = true;
                if (exitCleanup) clearTimeout(exitCleanup);
                resolve({
                    ...(code !== null ? { exitCode: code } : {}),
                    ...(signal ? { signal } : {}),
                });
            });
        });
        options.signal.removeEventListener("abort", abort);
        await stdoutWork;
        if (processError) return Err({ message: processError });
        if (stdoutError) return Err({ message: stdoutError });
        return Ok({ ...exit });
    } catch (error) {
        return Err(toError(error));
    } finally {
        await Promise.allSettled(handles.map((handle) => handle.close()));
    }
}
