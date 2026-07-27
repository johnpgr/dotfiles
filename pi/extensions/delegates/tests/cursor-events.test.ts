import assert from "node:assert/strict";
import { chmod, mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { CursorBackend } from "../src/backends/cursor.js";
import type { DelegateTask } from "../src/types.js";

const fixture = path.join(
  process.cwd(),
  "tests",
  "fixtures",
  "delegate-stub.mjs",
);

test("Cursor preserves raw events, tolerates unknown data, and writes canonical result", async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "delegates-cursor-"));
  try {
    await chmod(fixture, 0o755);
    const task: DelegateTask = {
      id: "dlg-cursor-1",
      task: "answer",
      cwd: directory,
      profile: "plan",
      dangerousBypass: false,
      timeoutMs: 5000,
      artifacts: {
        directory,
        metadata: path.join(directory, "metadata.json"),
        prompt: path.join(directory, "prompt.txt"),
        final: path.join(directory, "final.md"),
        log: path.join(directory, "execution.log"),
        events: path.join(directory, "events.jsonl"),
      },
    };
    const outcome = await new CursorBackend(fixture).start(
      task,
      new AbortController().signal,
    );
    assert.equal(outcome.exitCode, 0);
    assert.equal(
      await readFile(task.artifacts.final, "utf8"),
      "final cursor answer",
    );
    const events = await readFile(task.artifacts.events, "utf8");
    assert.match(events, /future_event/);
    assert.match(events, /\{not json\}/);
    const log = await readFile(task.artifacts.log, "utf8");
    assert.match(log, /Unknown Cursor event/);
    assert.match(log, /Malformed Cursor event/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
