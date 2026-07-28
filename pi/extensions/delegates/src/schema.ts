import { Type } from "typebox";

const positiveInteger = (maximum: number) => Type.Integer({ minimum: 1, maximum });

export const DelegateNameSchema = Type.Union([
    Type.Literal("codex"),
    Type.Literal("claude"),
    Type.Literal("agent"),
    Type.Literal("agy"),
]);

export const DelegateProfileSchema = Type.Union([
    Type.Literal("plan"),
    Type.Literal("implementation"),
]);

export const DelegateStatusSchema = Type.Union([
    Type.Literal("queued"),
    Type.Literal("running"),
    Type.Literal("done"),
    Type.Literal("error"),
    Type.Literal("stopped"),
]);

export const DelegateConfigSchema = Type.Object(
    {
        enabled: Type.Boolean(),
        timeoutMinutes: positiveInteger(24 * 60),
        executable: Type.Optional(Type.String({ minLength: 1, maxLength: 4096 })),
        allowDangerousBypass: Type.Optional(Type.Boolean()),
    },
    { additionalProperties: false },
);

export const DelegatesConfigSchema = Type.Object(
    {
        maxConcurrent: positiveInteger(64),
        maxTracked: positiveInteger(4096),
        maxPreviewBytes: positiveInteger(1024 * 1024),
        maxAttachBytes: positiveInteger(1024 * 1024),
        indexFinalOutput: Type.Boolean(),
        indexExecutionLog: Type.Boolean(),
        artifactRetentionDays: positiveInteger(3650),
        delegates: Type.Object(
            {
                codex: DelegateConfigSchema,
                claude: DelegateConfigSchema,
                agent: DelegateConfigSchema,
                agy: DelegateConfigSchema,
            },
            { additionalProperties: false },
        ),
    },
    { additionalProperties: false },
);

export const DelegateJobMetadataSchema = Type.Object(
    {
        id: Type.String({ pattern: "^dlg-[a-z0-9-]+$", maxLength: 96 }),
        delegate: DelegateNameSchema,
        profile: DelegateProfileSchema,
        dangerousBypass: Type.Boolean(),
        task: Type.String({ minLength: 1, maxLength: 32768 }),
        cwd: Type.String({ minLength: 1 }),
        projectId: Type.String({ minLength: 1, maxLength: 160 }),
        status: DelegateStatusSchema,
        createdAt: Type.Integer({ minimum: 0 }),
        startedAt: Type.Optional(Type.Integer({ minimum: 0 })),
        settledAt: Type.Optional(Type.Integer({ minimum: 0 })),
        pid: Type.Optional(Type.Integer({ minimum: 1 })),
        exitCode: Type.Optional(Type.Integer()),
        signal: Type.Optional(Type.String({ maxLength: 32 })),
        error: Type.Optional(Type.String({ maxLength: 4096 })),
        warnings: Type.Array(Type.String({ maxLength: 4096 }), { maxItems: 32 }),
        contextSources: Type.Array(Type.String({ maxLength: 256 }), {
            maxItems: 3,
        }),
    },
    { additionalProperties: false },
);

const CursorContentSchema = Type.Object(
    {
        type: Type.String(),
        text: Type.Optional(Type.String()),
    },
    { additionalProperties: true },
);

const CursorMessageSchema = Type.Object(
    {
        content: Type.Optional(Type.Array(CursorContentSchema)),
    },
    { additionalProperties: true },
);

export const CursorSystemEventSchema = Type.Object(
    { type: Type.Literal("system") },
    { additionalProperties: true },
);
export const CursorUserEventSchema = Type.Object(
    { type: Type.Literal("user"), message: Type.Optional(CursorMessageSchema) },
    { additionalProperties: true },
);
export const CursorAssistantEventSchema = Type.Object(
    {
        type: Type.Literal("assistant"),
        message: Type.Optional(CursorMessageSchema),
    },
    { additionalProperties: true },
);
export const CursorToolCallEventSchema = Type.Object(
    { type: Type.Literal("tool_call") },
    { additionalProperties: true },
);
export const CursorResultEventSchema = Type.Object(
    {
        type: Type.Literal("result"),
        subtype: Type.Optional(Type.String()),
        is_error: Type.Optional(Type.Boolean()),
        result: Type.Optional(Type.String()),
    },
    { additionalProperties: true },
);

export const KnownCursorEventSchema = Type.Union([
    CursorSystemEventSchema,
    CursorUserEventSchema,
    CursorAssistantEventSchema,
    CursorToolCallEventSchema,
    CursorResultEventSchema,
]);
