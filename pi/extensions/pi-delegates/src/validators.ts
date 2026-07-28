import { Err, Ok, Success, Try, type Result, type Unit } from "./result.ts";
import type { TSchema } from "typebox";
import { Check, Errors } from "typebox/value";
import {
    DelegateJobMetadataSchema,
    DelegatesConfigSchema,
    KnownCursorEventSchema,
} from "./schema.ts";
import type { DelegateJobMetadata, DelegatesConfig, KnownCursorEvent } from "./types.ts";

function formatErrors(schema: TSchema, value: unknown) {
    return [...Errors(schema, value)]
        .slice(0, 8)
        .map((error) => `${error.instancePath || "/"}: ${error.message}`)
        .join("; ");
}

export function validateConfig(value: unknown): Result<{ config: DelegatesConfig }> {
    if (Check(DelegatesConfigSchema, value)) return Ok({ config: value });
    return Err({ message: formatErrors(DelegatesConfigSchema, value) });
}

export function parseMetadata(text: string): Result<{ metadata: DelegateJobMetadata }> {
    const parsed = Try(() => JSON.parse(text));
    if (!parsed.ok) return parsed;
    const value = parsed.value;
    if (Check(DelegateJobMetadataSchema, value)) {
        return Ok({ metadata: value });
    }
    return Err({ message: formatErrors(DelegateJobMetadataSchema, value) });
}

export function stringifyMetadata(value: DelegateJobMetadata): Result<{ text: string }> {
    if (!Check(DelegateJobMetadataSchema, value)) {
        return Err({ message: formatErrors(DelegateJobMetadataSchema, value) });
    }
    return Ok({ text: `${JSON.stringify(value, null, 2)}\n` });
}

export function parseCursorEvent(
    line: string,
):
    | { kind: "known"; event: KnownCursorEvent; raw: unknown }
    | { kind: "unknown"; raw: unknown }
    | { kind: "malformed"; error: string } {
    // Stays a 3-way union rather than a Result: "unknown but valid JSON" has to
    // keep its raw payload, which a two-armed Result cannot carry.
    const parsed = Try(() => JSON.parse(line) as unknown);
    if (!parsed.ok) return { kind: "malformed", error: parsed.error.message };
    if (Check(KnownCursorEventSchema, parsed.value)) {
        return { kind: "known", event: parsed.value, raw: parsed.value };
    }
    return { kind: "unknown", raw: parsed.value };
}
