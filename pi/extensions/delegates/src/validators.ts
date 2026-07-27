import type { TSchema } from "typebox";
import { Check, Errors } from "typebox/value";
import {
    DelegateJobMetadataSchema,
    DelegatesConfigSchema,
    KnownCursorEventSchema,
} from "./schema.js";
import type {
    DelegateJobMetadata,
    DelegatesConfig,
    KnownCursorEvent,
} from "./types.js";

function formatErrors(schema: TSchema, value: unknown) {
    return [...Errors(schema, value)]
        .slice(0, 8)
        .map((error) => `${error.instancePath || "/"}: ${error.message}`)
        .join("; ");
}

export function validateConfig(
    value: unknown,
): { success: true; data: DelegatesConfig } | { success: false; error: string } {
    if (Check(DelegatesConfigSchema, value))
        return { success: true, data: value };
    return {
        success: false,
        error: formatErrors(DelegatesConfigSchema, value),
    };
}

export function parseMetadata(
    text: string,
):
    | { success: true; data: DelegateJobMetadata }
    | { success: false; error: string } {
    let value: unknown;
    try {
        value = JSON.parse(text);
    } catch (error) {
        return {
            success: false,
            error: error instanceof Error ? error.message : String(error),
        };
    }
    if (Check(DelegateJobMetadataSchema, value)) {
        return { success: true, data: value };
    }
    return {
        success: false,
        error: formatErrors(DelegateJobMetadataSchema, value),
    };
}

export function stringifyMetadata(value: DelegateJobMetadata) {
    if (!Check(DelegateJobMetadataSchema, value)) {
        throw new Error(formatErrors(DelegateJobMetadataSchema, value));
    }
    return `${JSON.stringify(value, null, 2)}\n`;
}

export function parseCursorEvent(
    line: string,
):
    | { kind: "known"; event: KnownCursorEvent; raw: unknown }
    | { kind: "unknown"; raw: unknown }
    | { kind: "malformed"; error: string } {
    let value: unknown;
    try {
        value = JSON.parse(line);
    } catch (error) {
        return {
            kind: "malformed",
            error: error instanceof Error ? error.message : String(error),
        };
    }
    if (Check(KnownCursorEventSchema, value)) {
        return { kind: "known", event: value, raw: value };
    }
    return { kind: "unknown", raw: value };
}
