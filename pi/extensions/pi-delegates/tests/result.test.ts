import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { Check } from "typebox/value";
import {
    Ok,
    Err,
    Try,
    TryResult,
    Success,
    toError,
    unwrapOr,
    context,
    ignore,
    type Result,
} from "../src/result.ts";
import { DelegateJobMetadataSchema } from "../src/schema.ts";

test("ok is present and non-enumerable", () => {
    const result = Ok({ a: 1 });
    assert.equal(result.ok, true);
    assert.deepEqual(Object.keys(result), ["a"]);
    assert.equal(JSON.stringify(result), '{"a":1}');
    assert.deepStrictEqual(result, { a: 1 });
    assert.deepStrictEqual({ ...result }, { a: 1 });
});

test("Err ok marker is non-enumerable", () => {
    const result = Err({ message: "fail" });
    assert.equal(result.ok, false);
    assert.deepEqual(Object.keys(result), ["error"]);
    assert.equal(JSON.stringify(result), '{"error":{"message":"fail"}}');
});

test("stamping parsed metadata breaks TypeBox and cannot be un-stamped", () => {
    const metadata = {
        id: "dlg-test-1",
        delegate: "codex" as const,
        profile: "plan" as const,
        dangerousBypass: false,
        task: "prompt",
        cwd: "/tmp",
        projectId: "project-test",
        status: "queued" as const,
        createdAt: 1,
        warnings: [] as string[],
        contextSources: [] as string[],
    };
    assert.equal(Check(DelegateJobMetadataSchema, metadata), true);

    const stamped = Ok(metadata);
    assert.equal(Check(DelegateJobMetadataSchema, stamped), false);
    assert.throws(() => {
        delete (stamped as { ok?: boolean }).ok;
    }, TypeError);
});

test("Try boxes primitive promise results", async () => {
    const packageJson = path.join(
        path.dirname(fileURLToPath(import.meta.url)),
        "..",
        "..",
        "package.json",
    );
    const result = await Try(readFile(packageJson, "utf8"));
    assert.equal(result.ok, true);
    if (result.ok) {
        assert.match(result.value, /"name"/);
    }
});

test("Try unwraps a function that returns a promise", async () => {
    // The `() => Promise<T>` overload must win over `() => T`, or the declared
    // type is a sync Result while the runtime hands back a Promise.
    const result = await Try(async () => 1);
    assert.equal(result.ok, true);
    if (result.ok) {
        // Type-level assertion: the runtime is already correct here, so only the
        // declared type can regress. If the `() => T` overload wins, `value` is
        // `Promise<number>` and this annotation fails to compile.
        const value: number = result.value;
        assert.equal(value, 1);
    }

    const rejected = await Try(async () => {
        throw new Error("async boom");
    });
    assert.equal(rejected.ok, false);
    if (!rejected.ok) assert.equal(rejected.error.message, "async boom");
});

test("Try sync function boxes return value", () => {
    const result = Try(() => 42);
    assert.equal(result.ok, true);
    if (result.ok) assert.equal(result.value, 42);
});

test("Try catches sync throws and normalizes through toError", () => {
    // The return type is explicit because a body that only throws infers `never`,
    // which matches the `() => Promise<T>` overload ahead of the sync one.
    const result = Try((): number => {
        throw new Error("sync boom");
    });
    assert.equal(result.ok, false);
    if (!result.ok) {
        assert.equal(result.error.message, "sync boom");
        assert.ok(result.error.cause instanceof Error);
    }
});

test("toError normalizes Error, string, and ErrnoException", () => {
    const fromError = toError(new Error("plain"));
    assert.equal(fromError.message, "plain");
    assert.ok(fromError.cause instanceof Error);

    const fromString = toError("oops");
    assert.equal(fromString.message, "oops");
    assert.equal(fromString.cause, "oops");

    const errno = Object.assign(new Error("missing"), { code: "ENOENT" });
    const fromErrno = toError(errno);
    assert.equal(fromErrno.code, "ENOENT");
    assert.equal(fromErrno.message, "missing");
});

test("TryResult passes through Result-returning callees", () => {
    const ok = TryResult(() => Ok({ id: "dlg-abc-1" }));
    assert.equal(ok.ok, true);
    if (ok.ok) assert.equal(ok.id, "dlg-abc-1");

    const fail = TryResult(() => Err({ message: "bad id" }));
    assert.equal(fail.ok, false);
    if (!fail.ok) assert.equal(fail.error.message, "bad id");
});

test("TryResult catches throws from Result-returning callees", () => {
    const result = TryResult(() => {
        throw new Error("callback threw");
    });
    assert.equal(result.ok, false);
    if (!result.ok) assert.match(result.error.message, /callback threw/);
});

test("Result failure propagates across different success types", () => {
    function stepA(): Result<{ id: string }> {
        return Err({ message: "step a failed" });
    }

    function pipeline(): Result<{ metadata: { status: string } }> {
        const a = stepA();
        if (!a.ok) return a;
        return Ok({ metadata: { status: "done" } });
    }

    const result = pipeline();
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.error.message, "step a failed");
});

test("Success singleton is ok", () => {
    assert.equal(Success.ok, true);
    assert.deepStrictEqual(Success, {});
});

test("unwrapOr, context, and ignore", () => {
    const fallback = { n: 0 };
    assert.equal(unwrapOr(Ok({ n: 1 }), fallback).n, 1);
    assert.deepStrictEqual(unwrapOr(Err({ message: "x" }), fallback), fallback);

    const prefixed = context(Err({ message: "root", code: "ENOENT" }), "readMetadata");
    assert.equal(prefixed.ok, false);
    if (!prefixed.ok) {
        assert.equal(prefixed.error.message, "readMetadata: root");
        assert.equal(prefixed.error.code, "ENOENT");
    }

    ignore(Err({ message: "swallowed" }));
});

test("Ok rejects non-object arguments", () => {
    assert.throws(() => Ok(null as unknown as Record<string, never>), /must be passed an object/);
});
