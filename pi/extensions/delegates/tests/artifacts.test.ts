import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  artifactPaths,
  createArtifacts,
  readBoundedFile,
  readMetadata,
  writeMetadataAtomic,
} from "../src/artifacts.js";
import type { DelegateJobMetadata } from "../src/types.js";

test("metadata round trips atomically and bounded reads use bytes", async () => {
  const directory = await mkdtemp(
    path.join(os.tmpdir(), "delegates-artifacts-"),
  );
  const previous = process.env.PI_AGENT_DIR;
  process.env.PI_AGENT_DIR = directory;
  try {
    const paths = artifactPaths("project-test", "dlg-test-1");
    await createArtifacts(paths, "prompt");
    const metadata: DelegateJobMetadata = {
      id: "dlg-test-1",
      delegate: "codex",
      profile: "plan",
      dangerousBypass: false,
      task: "prompt",
      cwd: directory,
      projectId: "project-test",
      status: "queued",
      createdAt: 1,
      warnings: [],
      contextSources: [],
      changedFiles: [],
    };
    await writeMetadataAtomic(paths.metadata, metadata);
    const loaded = await readMetadata(paths.metadata);
    assert.equal(loaded.success, true);
    if (loaded.success) assert.deepEqual(loaded.data, metadata);
    await writeFile(paths.final, "éééé");
    const bounded = await readBoundedFile(paths.final, 4);
    assert.equal(Buffer.byteLength(bounded.text), 4);
    assert.equal(bounded.truncated, true);
    const splitCharacter = await readBoundedFile(paths.final, 3);
    assert.ok(Buffer.byteLength(splitCharacter.text) <= 3);
    assert.equal(splitCharacter.text, "é");
  } finally {
    if (previous === undefined) delete process.env.PI_AGENT_DIR;
    else process.env.PI_AGENT_DIR = previous;
    await rm(directory, { recursive: true, force: true });
  }
});
