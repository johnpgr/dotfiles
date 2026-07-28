import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { DEFAULT_CONFIG } from "../src/config.ts";
import { DelegateManager } from "../src/manager.ts";
import type { DelegateBackend, DelegateName, DelegateTask } from "../src/types.ts";

async function eventually(check: () => boolean, timeoutMs = 5000) {
    const deadline = Date.now() + timeoutMs;
    while (!check()) {
        if (Date.now() >= deadline) throw new Error("condition did not become true");
        await new Promise((resolve) => setTimeout(resolve, 10));
    }
}

class FakeBackend implements DelegateBackend {
    readonly name: DelegateName = "codex";
    running = 0;
    peak = 0;
    implementationByCwd = new Map<string, number>();
    implementationPeakByCwd = new Map<string, number>();

    async start(task: DelegateTask, signal: AbortSignal) {
        this.running++;
        this.peak = Math.max(this.peak, this.running);
        if (task.profile === "implementation") {
            const count = (this.implementationByCwd.get(task.cwd) ?? 0) + 1;
            this.implementationByCwd.set(task.cwd, count);
            this.implementationPeakByCwd.set(
                task.cwd,
                Math.max(count, this.implementationPeakByCwd.get(task.cwd) ?? 0),
            );
        }
        await new Promise<void>((resolve) => {
            const timer = setTimeout(resolve, 80);
            signal.addEventListener(
                "abort",
                () => {
                    clearTimeout(timer);
                    resolve();
                },
                { once: true },
            );
        });
        this.running--;
        if (task.profile === "implementation") {
            this.implementationByCwd.set(
                task.cwd,
                (this.implementationByCwd.get(task.cwd) ?? 1) - 1,
            );
        }
        return { exitCode: 0 };
    }
}

function backends(backend: FakeBackend) {
    return {
        codex: backend,
        claude: backend,
        agent: backend,
        agy: backend,
    };
}

test("scheduler enforces global concurrency and per-cwd implementation serialization", async () => {
    const directory = await mkdtemp(path.join(os.tmpdir(), "delegates-manager-"));
    const previous = process.env.PI_AGENT_DIR;
    process.env.PI_AGENT_DIR = path.join(directory, "agent-state");
    const backend = new FakeBackend();
    const completions = new Map<string, number>();
    const manager = new DelegateManager({
        config: { ...DEFAULT_CONFIG, maxConcurrent: 2 },
        backends: backends(backend),
        onSettled: (metadata) =>
            completions.set(metadata.id, (completions.get(metadata.id) ?? 0) + 1),
    });
    try {
        const jobs = await Promise.all([
            manager.submit({
                delegate: "codex",
                profile: "implementation",
                dangerousBypass: false,
                task: "one",
                cwd: directory,
            }),
            manager.submit({
                delegate: "codex",
                profile: "implementation",
                dangerousBypass: false,
                task: "two",
                cwd: directory,
            }),
            manager.submit({
                delegate: "codex",
                profile: "plan",
                dangerousBypass: false,
                task: "three",
                cwd: directory,
            }),
            manager.submit({
                delegate: "codex",
                profile: "plan",
                dangerousBypass: false,
                task: "four",
                cwd: directory,
            }),
        ]);
        await eventually(() => manager.list().every((job) => job.settledAt !== undefined));
        assert.equal(backend.peak, 2);
        const canonical = await import("node:fs/promises").then(({ realpath }) =>
            realpath(directory),
        );
        assert.equal(backend.implementationPeakByCwd.get(canonical), 1);
        assert.equal(jobs.length, 4);
        assert.ok([...completions.values()].every((count) => count === 1));
    } finally {
        await manager.shutdown();
        if (previous === undefined) delete process.env.PI_AGENT_DIR;
        else process.env.PI_AGENT_DIR = previous;
        await rm(directory, { recursive: true, force: true });
    }
});

test("stopping a queued job settles it exactly once", async () => {
    const directory = await mkdtemp(path.join(os.tmpdir(), "delegates-stop-"));
    const previous = process.env.PI_AGENT_DIR;
    process.env.PI_AGENT_DIR = path.join(directory, "agent-state");
    const backend = new FakeBackend();
    const completed: string[] = [];
    const manager = new DelegateManager({
        config: { ...DEFAULT_CONFIG, maxConcurrent: 1 },
        backends: backends(backend),
        onSettled: (metadata) => completed.push(metadata.id),
    });
    try {
        const first = await manager.submit({
            delegate: "codex",
            profile: "plan",
            dangerousBypass: false,
            task: "first",
            cwd: directory,
        });
        const second = await manager.submit({
            delegate: "codex",
            profile: "plan",
            dangerousBypass: false,
            task: "second",
            cwd: directory,
        });
        await manager.stop(second.id);
        await eventually(() => manager.get(first.id)?.metadata.settledAt !== undefined);
        assert.equal(manager.get(second.id)?.metadata.status, "stopped");
        assert.equal(completed.filter((id) => id === second.id).length, 1);
    } finally {
        await manager.shutdown();
        if (previous === undefined) delete process.env.PI_AGENT_DIR;
        else process.env.PI_AGENT_DIR = previous;
        await rm(directory, { recursive: true, force: true });
    }
});
