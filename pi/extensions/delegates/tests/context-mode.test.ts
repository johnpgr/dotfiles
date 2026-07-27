import assert from "node:assert/strict";
import { chmod, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { DEFAULT_CONFIG } from "../src/config.js";
import {
  indexDelegateArtifacts,
  searchDelegateArtifacts,
} from "../src/context-mode.js";
import type { ArtifactPaths, DelegateJobMetadata } from "../src/types.js";

const fixture = path.join(
  process.cwd(),
  "tests",
  "fixtures",
  "delegate-stub.mjs",
);

test("Context Mode uses project/source labels and indexing failure is non-fatal", async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), "delegates-context-"));
  const argsFile = path.join(directory, "args.jsonl");
  const previousArgs = process.env.STUB_ARGS_FILE;
  const previousFail = process.env.STUB_FAIL;
  process.env.STUB_ARGS_FILE = argsFile;
  try {
    await chmod(fixture, 0o755);
    const artifacts: ArtifactPaths = {
      directory,
      metadata: path.join(directory, "metadata.json"),
      prompt: path.join(directory, "prompt.txt"),
      final: path.join(directory, "final.md"),
      log: path.join(directory, "execution.log"),
      events: path.join(directory, "events.jsonl"),
    };
    await writeFile(artifacts.final, "answer");
    await writeFile(artifacts.log, "");
    const metadata: DelegateJobMetadata = {
      id: "dlg-context-1",
      delegate: "codex",
      profile: "plan",
      dangerousBypass: false,
      task: "task",
      cwd: directory,
      projectId: "project",
      status: "done",
      createdAt: 1,
      warnings: [],
      contextSources: [],
      changedFiles: [],
    };
    await indexDelegateArtifacts(
      fixture,
      DEFAULT_CONFIG,
      metadata,
      artifacts,
      new AbortController().signal,
    );
    assert.deepEqual(metadata.contextSources, ["delegate:dlg-context-1:final"]);
    const args = (await readFile(argsFile, "utf8"))
      .trim()
      .split("\n")
      .map((line) => JSON.parse(line) as string[]);
    const indexArgs = args[0];
    assert.ok(indexArgs);
    assert.ok(indexArgs.includes("--project"));
    assert.ok(indexArgs.includes("delegate:dlg-context-1:final"));

    const search = await searchDelegateArtifacts(
      fixture,
      metadata,
      artifacts,
      "needle",
      1024,
    );
    assert.match(search.output, /delegate search match/);

    process.env.STUB_FAIL = "1";
    const failed = { ...metadata, warnings: [], contextSources: [] };
    await indexDelegateArtifacts(
      fixture,
      DEFAULT_CONFIG,
      failed,
      artifacts,
      new AbortController().signal,
    );
    assert.equal(failed.status, "done");
    assert.equal(failed.warnings.length, 1);
  } finally {
    if (previousArgs === undefined) delete process.env.STUB_ARGS_FILE;
    else process.env.STUB_ARGS_FILE = previousArgs;
    if (previousFail === undefined) delete process.env.STUB_FAIL;
    else process.env.STUB_FAIL = previousFail;
    await rm(directory, { recursive: true, force: true });
  }
});
