import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { spawnDelegateProcess } from "../src/process.ts";

const fixture = path.join(process.cwd(), "tests", "fixtures", "delegate-stub.mjs");

async function eventually<T>(read: () => Promise<T>, timeoutMs = 3000): Promise<T> {
    const deadline = Date.now() + timeoutMs;
    while (true) {
        try {
            return await read();
        } catch (error) {
            if (Date.now() >= deadline) throw error;
            await new Promise((resolve) => setTimeout(resolve, 20));
        }
    }
}

test("large output goes directly to files", async () => {
    const directory = await mkdtemp(path.join(os.tmpdir(), "delegates-process-"));
    try {
        const stdout = path.join(directory, "stdout");
        const stderr = path.join(directory, "stderr");
        const result = await spawnDelegateProcess({
            executable: process.execPath,
            args: [fixture, "large"],
            cwd: directory,
            stdoutPath: stdout,
            stderrPath: stderr,
            signal: new AbortController().signal,
        });
        assert.equal(result.exitCode, 0);
        assert.equal((await readFile(stdout)).length, 128 * 1024);
        assert.equal((await readFile(stderr)).length, 128 * 1024);
    } finally {
        await rm(directory, { recursive: true, force: true });
    }
});

test("abort terminates descendants that ignore SIGTERM", async () => {
    const directory = await mkdtemp(path.join(os.tmpdir(), "delegates-tree-"));
    const pidFile = path.join(directory, "child.pid");
    const previous = process.env.STUB_PID_FILE;
    process.env.STUB_PID_FILE = pidFile;
    try {
        const controller = new AbortController();
        const running = spawnDelegateProcess({
            executable: process.execPath,
            args: [fixture, "tree"],
            cwd: directory,
            stdoutPath: path.join(directory, "stdout"),
            stderrPath: path.join(directory, "stderr"),
            signal: controller.signal,
        });
        const pid = Number(await eventually(() => readFile(pidFile, "utf8")));
        controller.abort();
        await running;
        await eventually(async () => {
            try {
                process.kill(pid, 0);
            } catch {
                return true;
            }
            throw new Error(`descendant ${pid} is still alive`);
        }, 5000);
        assert.ok(pid > 0);
    } finally {
        if (previous === undefined) delete process.env.STUB_PID_FILE;
        else process.env.STUB_PID_FILE = previous;
        await rm(directory, { recursive: true, force: true });
    }
});
