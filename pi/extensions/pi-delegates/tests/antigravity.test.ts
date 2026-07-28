import assert from "node:assert/strict";
import test from "node:test";
import { buildAntigravityArgs } from "../src/backends/antigravity.ts";
import type { DelegateProfile, DelegateTask } from "../src/types.ts";

const AUTO_APPROVE = "--dangerously-skip-permissions";

function task(profile: DelegateProfile, dangerousBypass = false): DelegateTask {
    return {
        id: "dlg-test",
        task: "explore",
        cwd: "/tmp/project",
        profile,
        dangerousBypass,
        timeoutMs: 30 * 60 * 1000,
        artifacts: {
            directory: "/tmp/artifacts",
            metadata: "/tmp/artifacts/metadata.json",
            prompt: "/tmp/artifacts/prompt.txt",
            final: "/tmp/artifacts/final.md",
            log: "/tmp/artifacts/execution.log",
            events: "/tmp/artifacts/events.jsonl",
        },
    };
}

test("plan runs auto-approve tools so headless soft-denies cannot silently empty the run", () => {
    const args = buildAntigravityArgs(task("plan"));
    assert.ok(args.includes(AUTO_APPROVE));
    assert.deepEqual(args.slice(args.indexOf("--mode"), args.indexOf("--mode") + 2), [
        "--mode",
        "plan",
    ]);
});

test("implementation without an explicit bypass does not auto-approve", () => {
    const args = buildAntigravityArgs(task("implementation"));
    assert.ok(!args.includes(AUTO_APPROVE));
    assert.deepEqual(args.slice(args.indexOf("--mode"), args.indexOf("--mode") + 2), [
        "--mode",
        "accept-edits",
    ]);
});

test("implementation auto-approves only when the dangerous bypass is opted in", () => {
    const args = buildAntigravityArgs(task("implementation", true));
    assert.ok(args.includes(AUTO_APPROVE));
});

test("the sandbox stays on for every profile", () => {
    for (const args of [
        buildAntigravityArgs(task("plan")),
        buildAntigravityArgs(task("implementation")),
        buildAntigravityArgs(task("implementation", true)),
    ]) {
        assert.ok(args.includes("--sandbox"));
    }
});

test("the print timeout is derived from the task timeout and never rounds to zero", () => {
    const args = buildAntigravityArgs({ ...task("plan"), timeoutMs: 1 });
    assert.equal(args[args.indexOf("--print-timeout") + 1], "1s");
});
