import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createBackends } from "../../src/backends/index.js";
import { resolveExecutable } from "../../src/config.js";
import type {
  DelegateName,
  DelegateProfile,
  DelegateTask,
} from "../../src/types.js";

const enabled = process.env.PI_DELEGATES_LIVE === "1";

test(
  "paid live backends support plan and implementation profiles",
  { skip: !enabled, timeout: 20 * 60_000 },
  async () => {
    const root = await mkdtemp(path.join(os.tmpdir(), "delegates-live-"));
    try {
      execFileSync("git", ["init", "-q"], { cwd: root });
      await writeFile(path.join(root, "README.md"), "delegate smoke test\n");
      const names: DelegateName[] = ["codex", "claude", "agent", "agy"];
      const pairs = await Promise.all(
        names.map(
          async (name) => [name, await resolveExecutable(name)] as const,
        ),
      );
      for (const [, executable] of pairs)
        assert.ok(executable, "all live executables must exist");
      const backends = createBackends(
        Object.fromEntries(pairs) as Record<DelegateName, string>,
      );
      for (const name of names) {
        for (const profile of [
          "plan",
          "implementation",
        ] satisfies DelegateProfile[]) {
          const directory = path.join(root, ".artifacts", `${name}-${profile}`);
          await mkdir(directory, { recursive: true });
          const outputFile = `${name}-implementation.txt`;
          const task: DelegateTask = {
            id: `dlg-live-${name}-${profile}`,
            task:
              profile === "plan"
                ? "Inspect README.md without modifying files. Reply exactly PLAN_OK."
                : `Create ${outputFile} containing exactly IMPLEMENTATION_OK followed by a newline.`,
            cwd: root,
            profile,
            dangerousBypass: name === "agy" && profile === "implementation",
            timeoutMs: 180_000,
            artifacts: {
              directory,
              metadata: path.join(directory, "metadata.json"),
              prompt: path.join(directory, "prompt.txt"),
              final: path.join(directory, "final.md"),
              log: path.join(directory, "execution.log"),
              events: path.join(directory, "events.jsonl"),
            },
          };
          const controller = new AbortController();
          const timer = setTimeout(() => controller.abort(), task.timeoutMs);
          const outcome = await backends[name].start(task, controller.signal);
          clearTimeout(timer);
          assert.equal(
            outcome.exitCode,
            0,
            `${name}/${profile}: ${outcome.error ?? "failed"}`,
          );
          if (profile === "implementation") {
            assert.equal(
              await readFile(path.join(root, outputFile), "utf8"),
              "IMPLEMENTATION_OK\n",
            );
          }
        }
      }
    } finally {
      await rm(root, { recursive: true, force: true });
    }
  },
);
