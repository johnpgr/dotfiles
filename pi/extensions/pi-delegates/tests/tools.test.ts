import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { DEFAULT_CONFIG } from "../src/config.ts";
import { DelegateManager } from "../src/manager.ts";
import { buildDelegateWaitSection } from "../src/prompt.ts";
import { Err, Ok, type Result } from "../src/result.ts";
import {
    CHECK_PREVIEW_MAX_BYTES,
    registerDelegateTools,
    WAIT_OUTPUT_MAX_BYTES,
    WAIT_PER_JOB_MAX_BYTES,
    type ManagerBundle,
} from "../src/tools.ts";
import type { DelegateBackend, DelegateName, DelegateTask } from "../src/types.ts";

async function eventually(check: () => boolean, timeoutMs = 5000) {
    const deadline = Date.now() + timeoutMs;
    while (!check()) {
        if (Date.now() >= deadline) throw new Error("condition did not become true");
        await new Promise((resolve) => setTimeout(resolve, 10));
    }
}

interface RegisteredTool {
    name: string;
    execute: (
        toolCallId: string,
        params: Record<string, unknown>,
        signal: AbortSignal,
        onUpdate?: (update: { content: { type: string; text: string }[] }) => void,
        ctx?: ToolContext,
    ) => Promise<{ content: { type: string; text: string }[]; details?: unknown }>;
}

interface ToolContext {
    cwd: string;
    isProjectTrusted: () => boolean;
}

function expectOk<T extends object>(result: Result<T>): T {
    assert.equal(result.ok, true);
    if (!result.ok) throw new Error("expected success");
    return result;
}

class OutputBackend implements DelegateBackend {
    readonly name: DelegateName = "codex";
    constructor(private readonly outputSize: number) {}

    async start(task: DelegateTask, signal: AbortSignal) {
        await writeFile(task.artifacts.final, "x".repeat(this.outputSize));
        await new Promise<void>((resolve) => {
            const timer = setTimeout(resolve, 20);
            signal.addEventListener(
                "abort",
                () => {
                    clearTimeout(timer);
                    resolve();
                },
                { once: true },
            );
        });
        return Ok({ exitCode: 0 });
    }
}

class FakeBackend implements DelegateBackend {
    readonly name: DelegateName = "codex";

    async start(_task: DelegateTask, signal: AbortSignal) {
        await new Promise<void>((resolve) => {
            const timer = setTimeout(resolve, 200);
            signal.addEventListener(
                "abort",
                () => {
                    clearTimeout(timer);
                    resolve();
                },
                { once: true },
            );
        });
        return Ok({ exitCode: 0 });
    }
}

class LogWritingBackend implements DelegateBackend {
    readonly name: DelegateName = "codex";

    async start(task: DelegateTask, signal: AbortSignal) {
        await writeFile(task.artifacts.log, `HEAD${"x".repeat(10_000)}tail-marker`);
        await new Promise<void>((resolve) => {
            const timer = setTimeout(resolve, 500);
            signal.addEventListener(
                "abort",
                () => {
                    clearTimeout(timer);
                    resolve();
                },
                { once: true },
            );
        });
        return Ok({ exitCode: 0 });
    }
}

class ErrorLogBackend implements DelegateBackend {
    readonly name: DelegateName = "codex";

    async start(task: DelegateTask) {
        await writeFile(task.artifacts.log, `HEAD${"x".repeat(50_000)}error-tail`);
        return Err({ message: "simulated backend failure" });
    }
}

function backends(backend: DelegateBackend) {
    return {
        codex: backend,
        claude: backend,
        agent: backend,
        agy: backend,
    };
}

class VariableTimingBackend implements DelegateBackend {
    readonly name: DelegateName = "codex";

    async start(task: DelegateTask, signal: AbortSignal) {
        const delayMs = task.task.includes("slow") ? 500 : 40;
        await new Promise<void>((resolve) => {
            const timer = setTimeout(resolve, delayMs);
            signal.addEventListener(
                "abort",
                () => {
                    clearTimeout(timer);
                    resolve();
                },
                { once: true },
            );
        });
        return Ok({ exitCode: 0 });
    }
}

async function setupDeferredHarness() {
    const directory = await mkdtemp(path.join(os.tmpdir(), "delegates-deferred-"));
    const previous = process.env.PI_AGENT_DIR;
    process.env.PI_AGENT_DIR = path.join(directory, "agent-state");
    const waitingIds = new Set<string>();
    const toolDeliveredIds = new Set<string>();
    const deferredCompletions = new Map<string, { id: string; status: string }>();

    const manager = new DelegateManager({
        config: DEFAULT_CONFIG,
        backends: backends(new VariableTimingBackend()),
        onSettled: (metadata) => {
            if (toolDeliveredIds.has(metadata.id)) return;
            deferredCompletions.set(metadata.id, {
                id: metadata.id,
                status: metadata.status,
            });
        },
    });
    await manager.recover(directory);

    const bundle: ManagerBundle = {
        manager,
        config: DEFAULT_CONFIG,
        executables: {
            codex: "/usr/bin/codex",
            claude: "/usr/bin/claude",
            agent: "/usr/bin/agent",
            agy: "/usr/bin/agy",
        },
    };

    const tools = new Map<string, RegisteredTool>();
    registerDelegateTools(
        {
            registerTool(definition: RegisteredTool) {
                tools.set(definition.name, definition);
            },
        } as unknown as ExtensionAPI,
        {
            getManager: async () => Ok(bundle),
            onWaitStart: (ids) => {
                for (const id of ids) waitingIds.add(id);
            },
            onWaitEnd: (ids, { consumed }) => {
                for (const id of ids) {
                    waitingIds.delete(id);
                    if (consumed) {
                        toolDeliveredIds.add(id);
                        deferredCompletions.delete(id);
                    }
                }
            },
        },
    );

    const ctx: ToolContext = {
        cwd: directory,
        isProjectTrusted: () => true,
    };

    return {
        directory,
        manager,
        tools,
        ctx,
        waitingIds,
        deferredCompletions,
        flushCompletions() {
            for (const [id] of [...deferredCompletions.entries()]) {
                if (toolDeliveredIds.has(id)) {
                    deferredCompletions.delete(id);
                    continue;
                }
                if (waitingIds.has(id)) continue;
                deferredCompletions.delete(id);
            }
        },
        async cleanup() {
            await manager.shutdown();
            if (previous === undefined) delete process.env.PI_AGENT_DIR;
            else process.env.PI_AGENT_DIR = previous;
            await rm(directory, { recursive: true, force: true });
        },
    };
}

async function setupHarness(options: { backend: DelegateBackend; onSettled?: () => void }) {
    const directory = await mkdtemp(path.join(os.tmpdir(), "delegates-tools-"));
    const previous = process.env.PI_AGENT_DIR;
    process.env.PI_AGENT_DIR = path.join(directory, "agent-state");
    const waitingIds = new Set<string>();
    const toolDeliveredIds = new Set<string>();
    let appendCount = 0;

    const manager = new DelegateManager({
        config: DEFAULT_CONFIG,
        backends: backends(options.backend),
        onSettled: () => {
            appendCount++;
            options.onSettled?.();
        },
    });
    await manager.recover(directory);

    const bundle: ManagerBundle = {
        manager,
        config: DEFAULT_CONFIG,
        executables: {
            codex: "/usr/bin/codex",
            claude: "/usr/bin/claude",
            agent: "/usr/bin/agent",
            agy: "/usr/bin/agy",
        },
    };

    const tools = new Map<string, RegisteredTool>();
    const pi = {
        registerTool(definition: RegisteredTool) {
            tools.set(definition.name, definition);
        },
    } as unknown as ExtensionAPI;

    registerDelegateTools(pi, {
        getManager: async () => Ok(bundle),
        onWaitStart: (ids) => {
            for (const id of ids) waitingIds.add(id);
        },
        onWaitEnd: (ids, { consumed }) => {
            for (const id of ids) {
                waitingIds.delete(id);
                if (consumed) toolDeliveredIds.add(id);
            }
        },
    });

    const ctx: ToolContext = {
        cwd: directory,
        isProjectTrusted: () => true,
    };

    return {
        directory,
        manager,
        tools,
        ctx,
        waitingIds,
        toolDeliveredIds,
        get appendCount() {
            return appendCount;
        },
        shouldSkipAppend(id: string) {
            return toolDeliveredIds.has(id);
        },
        async cleanup() {
            await manager.shutdown();
            if (previous === undefined) delete process.env.PI_AGENT_DIR;
            else process.env.PI_AGENT_DIR = previous;
            await rm(directory, { recursive: true, force: true });
        },
    };
}

test("delegate_spawn rejects agy implementation and untrusted projects", async () => {
    const harness = await setupHarness({ backend: new FakeBackend() });
    try {
        const spawn = harness.tools.get("delegate_spawn")!;
        await assert.rejects(
            () =>
                spawn.execute(
                    "1",
                    { task: "edit", delegate: "agy", profile: "implementation" },
                    new AbortController().signal,
                    undefined,
                    harness.ctx,
                ),
            /Antigravity implementation is not available via tools/,
        );

        await assert.rejects(
            () =>
                spawn.execute(
                    "2",
                    { task: "plan", delegate: "codex" },
                    new AbortController().signal,
                    undefined,
                    { ...harness.ctx, isProjectTrusted: () => false },
                ),
            /trusted Pi project/,
        );
    } finally {
        await harness.cleanup();
    }
});

test("unknown ids throw with the known-id list", async () => {
    const harness = await setupHarness({ backend: new FakeBackend() });
    try {
        const wait = harness.tools.get("delegate_wait")!;
        await assert.rejects(
            () =>
                wait.execute(
                    "1",
                    { ids: ["dlg-missing"] },
                    new AbortController().signal,
                    undefined,
                    harness.ctx,
                ),
            /Known: none/,
        );
    } finally {
        await harness.cleanup();
    }
});

test("delegate_wait output stays within byte caps", async () => {
    const harness = await setupHarness({ backend: new OutputBackend(24 * 1024) });
    try {
        const spawn = harness.tools.get("delegate_spawn")!;
        const wait = harness.tools.get("delegate_wait")!;
        const ids: string[] = [];
        for (let index = 0; index < 4; index++) {
            const spawned = await spawn.execute(
                String(index),
                { task: `job-${index}`, delegate: "codex" },
                new AbortController().signal,
                undefined,
                harness.ctx,
            );
            ids.push((spawned.details as { id: string }).id);
        }
        const result = await wait.execute(
            "wait",
            { ids },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        const text = result.content[0]?.text ?? "";
        assert.ok(Buffer.byteLength(text, "utf8") <= WAIT_OUTPUT_MAX_BYTES + 256);
        for (const id of ids) {
            const marker = `## ${id}`;
            const start = text.indexOf(marker);
            if (start < 0) continue;
            const next = text.indexOf("\n\n---\n\n", start);
            const section = next < 0 ? text.slice(start) : text.slice(start, next);
            assert.ok(
                Buffer.byteLength(section, "utf8") <= WAIT_PER_JOB_MAX_BYTES + 512,
                `section for ${id} exceeded per-job cap`,
            );
        }
    } finally {
        await harness.cleanup();
    }
});

test("delegate_check preview stays within 2 KB", async () => {
    const harness = await setupHarness({ backend: new OutputBackend(8 * 1024) });
    try {
        const spawn = harness.tools.get("delegate_spawn")!;
        const check = harness.tools.get("delegate_check")!;
        const spawned = await spawn.execute(
            "1",
            { task: "large", delegate: "codex" },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        const id = (spawned.details as { id: string }).id;
        await new Promise((resolve) => setTimeout(resolve, 100));
        const result = await check.execute(
            "2",
            { id },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        const text = result.content[0]?.text ?? "";
        assert.ok(Buffer.byteLength(text, "utf8") <= CHECK_PREVIEW_MAX_BYTES + 512);
    } finally {
        await harness.cleanup();
    }
});

test("delegate_wait skips auto-append for consumed jobs", async () => {
    const harness = await setupHarness({ backend: new FakeBackend() });
    try {
        const spawn = harness.tools.get("delegate_spawn")!;
        const wait = harness.tools.get("delegate_wait")!;
        const spawned = await spawn.execute(
            "1",
            { task: "background", delegate: "codex" },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        const id = (spawned.details as { id: string }).id;
        await wait.execute(
            "2",
            { ids: [id] },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        assert.ok(harness.shouldSkipAppend(id));
    } finally {
        await harness.cleanup();
    }
});

test("delegate_wait abort leaves the result collectable after settle", async () => {
    const harness = await setupHarness({ backend: new FakeBackend() });
    try {
        const spawn = harness.tools.get("delegate_spawn")!;
        const wait = harness.tools.get("delegate_wait")!;
        const spawned = await spawn.execute(
            "1",
            { task: "slow", delegate: "codex" },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        const id = (spawned.details as { id: string }).id;
        const controller = new AbortController();
        const waiting = wait.execute("2", { ids: [id] }, controller.signal, undefined, harness.ctx);
        controller.abort();
        await assert.rejects(() => waiting, /Wait aborted/);
        assert.ok(!harness.toolDeliveredIds.has(id));
        await eventually(() => harness.manager.get(id)?.metadata.settledAt !== undefined);
        const result = await wait.execute(
            "3",
            { ids: [id] },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        assert.ok(result.content[0]?.text.includes("finished"));
    } finally {
        await harness.cleanup();
    }
});

test("settled job during aborted multi-wait stays deferred", async () => {
    const harness = await setupDeferredHarness();
    try {
        const spawn = harness.tools.get("delegate_spawn")!;
        const wait = harness.tools.get("delegate_wait")!;
        const fast = await spawn.execute(
            "1",
            { task: "fast-a", delegate: "codex" },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        const slow = await spawn.execute(
            "2",
            { task: "slow-b", delegate: "codex" },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        const idA = (fast.details as { id: string }).id;
        const idB = (slow.details as { id: string }).id;
        const controller = new AbortController();
        const waiting = wait.execute(
            "3",
            { ids: [idA, idB] },
            controller.signal,
            undefined,
            harness.ctx,
        );
        await eventually(() => harness.manager.get(idA)?.metadata.settledAt !== undefined);
        controller.abort();
        await assert.rejects(() => waiting, /Wait aborted/);
        assert.ok(harness.deferredCompletions.has(idA));
        assert.ok(!harness.deferredCompletions.has(idB));
    } finally {
        await harness.cleanup();
    }
});

test("flushCompletions retains deferred entries for in-flight waits", async () => {
    const harness = await setupDeferredHarness();
    try {
        const id = "dlg-flush-test";
        harness.deferredCompletions.set(id, { id, status: "done" });
        harness.waitingIds.add(id);
        harness.flushCompletions();
        assert.ok(harness.deferredCompletions.has(id));
        harness.waitingIds.delete(id);
        harness.flushCompletions();
        assert.ok(!harness.deferredCompletions.has(id));
    } finally {
        await harness.cleanup();
    }
});

test("buildDelegateWaitSection distinguishes stopped from failed", () => {
    assert.match(
        buildDelegateWaitSection({
            id: "dlg-1",
            delegate: "codex",
            profile: "plan",
            status: "stopped",
            error: "Delegate was stopped.",
            output: "partial",
        }),
        /was stopped/,
    );
    assert.doesNotMatch(
        buildDelegateWaitSection({
            id: "dlg-1",
            delegate: "codex",
            profile: "plan",
            status: "stopped",
            error: "Delegate was stopped.",
            output: "partial",
        }),
        / failed/,
    );
    assert.match(
        buildDelegateWaitSection({
            id: "dlg-2",
            delegate: "codex",
            profile: "plan",
            status: "error",
            error: "boom",
            output: "partial",
        }),
        /failed/,
    );
});

test("delegate_wait reads the tail of a failed job log", async () => {
    const harness = await setupHarness({ backend: new ErrorLogBackend() });
    try {
        const spawn = harness.tools.get("delegate_spawn")!;
        const wait = harness.tools.get("delegate_wait")!;
        const spawned = await spawn.execute(
            "1",
            { task: "fail", delegate: "codex" },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        const id = (spawned.details as { id: string }).id;
        const result = await wait.execute(
            "2",
            { ids: [id] },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        const text = result.content[0]?.text ?? "";
        assert.match(text, /failed/);
        assert.ok(text.includes("error-tail"));
        assert.ok(!text.includes("HEAD"));
    } finally {
        await harness.cleanup();
    }
});

test("delegate_check shows the tail of a running job log", async () => {
    const harness = await setupHarness({ backend: new LogWritingBackend() });
    try {
        const spawn = harness.tools.get("delegate_spawn")!;
        const check = harness.tools.get("delegate_check")!;
        const spawned = await spawn.execute(
            "1",
            { task: "stream", delegate: "codex" },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        const id = (spawned.details as { id: string }).id;
        await new Promise((resolve) => setTimeout(resolve, 30));
        const result = await check.execute(
            "2",
            { id },
            new AbortController().signal,
            undefined,
            harness.ctx,
        );
        const text = result.content[0]?.text ?? "";
        assert.ok(text.includes("tail-marker"));
        assert.ok(!text.includes("HEAD"));
    } finally {
        await harness.cleanup();
    }
});
