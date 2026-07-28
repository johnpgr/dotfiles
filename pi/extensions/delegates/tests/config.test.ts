import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { parseLaunchArguments, parseSearchArguments } from "../src/args.ts";
import { DEFAULT_CONFIG, loadConfig } from "../src/config.ts";
import { validateConfig } from "../src/validators.ts";

test("default config validates and unknown properties fail", () => {
    assert.equal(validateConfig(DEFAULT_CONFIG).success, true);
    assert.equal(validateConfig({ ...DEFAULT_CONFIG, surprise: true }).success, false);
    assert.equal(
        validateConfig({
            ...DEFAULT_CONFIG,
            delegates: {
                ...DEFAULT_CONFIG.delegates,
                other: { enabled: true, timeoutMinutes: 1 },
            },
        }).success,
        false,
    );
});

test("invalid global config falls back atomically", async () => {
    const directory = await mkdtemp(path.join(os.tmpdir(), "delegates-config-"));
    const previous = process.env.PI_AGENT_DIR;
    process.env.PI_AGENT_DIR = directory;
    const warnings: string[] = [];
    try {
        await writeFile(path.join(directory, "delegates.json"), '{"maxConcurrent":0}');
        assert.deepEqual(await loadConfig((warning) => warnings.push(warning)), DEFAULT_CONFIG);
        assert.equal(warnings.length, 1);
    } finally {
        if (previous === undefined) delete process.env.PI_AGENT_DIR;
        else process.env.PI_AGENT_DIR = previous;
        await rm(directory, { recursive: true, force: true });
    }
});

test("launch parser handles profiles, separators, and dangerous opt-in", () => {
    assert.deepEqual(parseLaunchArguments("fix it"), {
        profile: "plan",
        dangerousBypass: false,
        task: "fix it",
    });
    assert.deepEqual(parseLaunchArguments("--implementation --dangerous -- --starts-with-dash"), {
        profile: "implementation",
        dangerousBypass: true,
        task: "--starts-with-dash",
    });
    assert.throws(() => parseLaunchArguments("--plan --dangerous task"), /requires/);
    assert.throws(() => parseLaunchArguments("--wat task"), /Unknown/);
    assert.deepEqual(parseSearchArguments("dlg-abc-1 auth failure"), {
        id: "dlg-abc-1",
        query: "auth failure",
    });
});

test("launch parser preserves task newlines and indentation", () => {
    const task = "Line one\n\n  indented\n```ts\nconst x = 1;\n```";
    assert.deepEqual(parseLaunchArguments(`--plan ${task}`), {
        profile: "plan",
        dangerousBypass: false,
        task,
    });
    assert.deepEqual(parseLaunchArguments(`--implementation --\n${task}`), {
        profile: "implementation",
        dangerousBypass: false,
        task,
    });
});
