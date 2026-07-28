import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
    artifactPaths,
    createArtifacts,
    readBoundedFile,
    readBoundedTailFile,
    readMetadata,
    writeMetadataAtomic,
} from "../src/artifacts.ts";
import type { DelegateJobMetadata } from "../src/types.ts";

test("metadata round trips atomically and bounded reads use bytes", async () => {
    const directory = await mkdtemp(path.join(os.tmpdir(), "delegates-artifacts-"));
    const previous = process.env.PI_AGENT_DIR;
    process.env.PI_AGENT_DIR = directory;
    try {
        const paths = artifactPaths("project-test", "dlg-test-1");
        const created = await createArtifacts(paths, "prompt");
        assert.equal(created.ok, true);
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
        };
        const written = await writeMetadataAtomic(paths.metadata, metadata);
        assert.equal(written.ok, true);
        const loaded = await readMetadata(paths.metadata);
        assert.equal(loaded.ok, true);
        if (loaded.ok) assert.deepEqual(loaded.metadata, metadata);
        await writeFile(paths.final, "éééé");
        const bounded = await readBoundedFile(paths.final, 4);
        assert.equal(bounded.ok, true);
        if (bounded.ok) {
            assert.equal(Buffer.byteLength(bounded.text), 4);
            assert.equal(bounded.truncated, true);
        }
        const splitCharacter = await readBoundedFile(paths.final, 3);
        assert.equal(splitCharacter.ok, true);
        if (splitCharacter.ok) {
            assert.ok(Buffer.byteLength(splitCharacter.text) <= 3);
            assert.equal(splitCharacter.text, "é");
        }
        await writeFile(paths.log, `HEAD${"x".repeat(10_000)}end-marker`);
        const tail = await readBoundedTailFile(paths.log, 64);
        assert.equal(tail.ok, true);
        if (tail.ok) {
            assert.ok(tail.text.includes("end-marker"));
            assert.ok(!tail.text.includes("HEAD"));
        }
    } finally {
        if (previous === undefined) delete process.env.PI_AGENT_DIR;
        else process.env.PI_AGENT_DIR = previous;
        await rm(directory, { recursive: true, force: true });
    }
});
