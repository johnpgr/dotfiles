import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { artifactForMetadata, DelegateManager } from "./src/manager.js";
import {
  parseJobId,
  parseLaunchArguments,
  parseSearchArguments,
} from "./src/args.js";
import { readBoundedFile } from "./src/artifacts.js";
import { createBackends } from "./src/backends/index.js";
import { loadConfig, resolveExecutable } from "./src/config.js";
import {
  indexDelegateArtifacts,
  resolveContextMode,
  searchDelegateArtifacts,
} from "./src/context-mode.js";
import { formatJob, renderDelegateEntry, statusCounts } from "./src/display.js";
import type {
  DelegateName,
  DelegateResultEntryData,
  DelegatesConfig,
} from "./src/types.js";

const COMMANDS: Record<DelegateName, string> = {
  codex: "delegate-codex",
  claude: "delegate-claude",
  agent: "delegate-agent",
  agy: "delegate-agy",
};

function errorText(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

export default function delegatesExtension(pi: ExtensionAPI) {
  let sessionContext: ExtensionContext | undefined;
  let managerPromise: Promise<DelegateManager> | undefined;
  let config: DelegatesConfig | undefined;
  let executables: Record<DelegateName, string | undefined> | undefined;
  let contextMode: string | undefined;

  const updateStatus = (manager: DelegateManager) => {
    const ui = sessionContext?.hasUI ? sessionContext.ui : undefined;
    if (!ui) return;
    const counts = statusCounts(manager.list());
    if (
      counts.queued +
        counts.running +
        counts.done +
        counts.error +
        counts.stopped ===
      0
    ) {
      ui.setStatus("delegates", undefined);
      return;
    }
    ui.setStatus(
      "delegates",
      `delegates ${counts.running} running · ${counts.queued} queued · ${counts.done} done · ${counts.error} failed`,
    );
  };

  const appendCompletion = async (
    metadata: ReturnType<DelegateManager["list"]>[number],
  ) => {
    if (!sessionContext) return;
    const artifacts = artifactForMetadata(metadata);
    let preview = "";
    let truncated = false;
    try {
      const result = await readBoundedFile(
        artifacts.final,
        config?.maxPreviewBytes ?? 4096,
      );
      preview = result.text;
      truncated = result.truncated;
    } catch {
      preview = metadata.error ?? "(no final output)";
    }
    if (!sessionContext) return;
    const elapsedMs =
      (metadata.settledAt ?? Date.now()) -
      (metadata.startedAt ?? metadata.createdAt);
    pi.appendEntry<DelegateResultEntryData>("delegate-result", {
      id: metadata.id,
      delegate: metadata.delegate,
      profile: metadata.profile,
      status: metadata.status,
      elapsedMs,
      preview,
      truncated,
      artifactPath: artifacts.directory,
      contextSources: [...metadata.contextSources],
      warnings: [...metadata.warnings],
      changedFiles: [...metadata.changedFiles],
    });
    sessionContext.ui.notify(
      `${metadata.delegate} ${metadata.id} ${metadata.status}. Use /delegate-result ${metadata.id}.`,
      metadata.status === "done" ? "info" : "warning",
    );
  };

  const getManager = (ctx: ExtensionContext | ExtensionCommandContext) => {
    managerPromise ??= (async () => {
      config = await loadConfig((message) => ctx.ui.notify(message, "warning"));
      const pairs = await Promise.all(
        (Object.keys(COMMANDS) as DelegateName[]).map(
          async (name) =>
            [
              name,
              await resolveExecutable(name, config?.delegates[name].executable),
            ] as const,
        ),
      );
      executables = Object.fromEntries(pairs) as Record<
        DelegateName,
        string | undefined
      >;
      contextMode = await resolveContextMode();
      const backendExecutables = Object.fromEntries(
        pairs.map(([name, executable]) => [name, executable ?? ""]),
      ) as Record<DelegateName, string>;
      let instance: DelegateManager;
      instance = new DelegateManager({
        config,
        backends: createBackends(backendExecutables),
        onChange: () => updateStatus(instance),
        afterSettle: (metadata, artifacts, signal) =>
          indexDelegateArtifacts(
            contextMode,
            config!,
            metadata,
            artifacts,
            signal,
          ),
        onSettled: (metadata) => void appendCompletion(metadata),
      });
      await instance.recover(ctx.cwd);
      updateStatus(instance);
      return instance;
    })();
    return managerPromise;
  };

  const launch = async (
    name: DelegateName,
    rawArgs: string,
    ctx: ExtensionCommandContext,
  ) => {
    try {
      const args = parseLaunchArguments(rawArgs);
      if (!ctx.isProjectTrusted()) {
        throw new Error("Delegate commands require a trusted Pi project.");
      }
      const manager = await getManager(ctx);
      const delegateConfig = config!.delegates[name];
      if (!delegateConfig.enabled)
        throw new Error(`${name} delegation is disabled.`);
      if (!executables?.[name])
        throw new Error(`${name} executable was not found.`);
      // Antigravity headless mode auto-denies edit tools because it cannot
      // prompt. Require both an explicit command flag and global opt-in; never
      // escalate merely because --implementation was selected.
      if (
        name === "agy" &&
        args.profile === "implementation" &&
        !args.dangerousBypass
      ) {
        throw new Error(
          "Antigravity implementation requires explicit --dangerous because headless edit permissions cannot prompt.",
        );
      }
      const dangerousBypass = args.dangerousBypass;
      if (dangerousBypass && delegateConfig.allowDangerousBypass !== true) {
        throw new Error(
          `${name} requires a dangerous permission bypass for this launch. Set allowDangerousBypass in global delegates.json to opt in.`,
        );
      }
      const metadata = await manager.submit({
        delegate: name,
        profile: args.profile,
        dangerousBypass,
        task: args.task,
        cwd: ctx.cwd,
      });
      ctx.ui.notify(
        `${name} queued as ${metadata.id} (${args.profile}${dangerousBypass ? ", DANGEROUS BYPASS" : ""}).`,
        dangerousBypass ? "warning" : "info",
      );
    } catch (error) {
      ctx.ui.notify(errorText(error), "error");
    }
  };

  pi.registerEntryRenderer<DelegateResultEntryData>(
    "delegate-result",
    renderDelegateEntry,
  );

  for (const [name, command] of Object.entries(COMMANDS) as [
    DelegateName,
    string,
  ][]) {
    pi.registerCommand(command, {
      description: `Run ${name} explicitly outside parent model context`,
      handler: (args, ctx) => launch(name, args, ctx),
    });
  }

  pi.registerCommand("delegate-status", {
    description: "Show queued, running, and recent delegate jobs",
    handler: async (raw, ctx) => {
      try {
        const manager = await getManager(ctx);
        if (raw.trim()) {
          const id = parseJobId(raw);
          const job = manager.get(id);
          if (!job) throw new Error(`Unknown delegate job: ${id}`);
          ctx.ui.notify(formatJob(job.metadata), "info");
          return;
        }
        const jobs = manager.list().slice(0, 12);
        ctx.ui.notify(
          jobs.length > 0
            ? jobs.map(formatJob).join("\n")
            : "No delegate jobs for this project.",
          "info",
        );
      } catch (error) {
        ctx.ui.notify(errorText(error), "error");
      }
    },
  });

  pi.registerCommand("delegate-result", {
    description: "Show a bounded delegate result in the TUI",
    handler: async (raw, ctx) => {
      try {
        const id = parseJobId(raw);
        const job = (await getManager(ctx)).get(id);
        if (!job) throw new Error(`Unknown delegate job: ${id}`);
        const result = await readBoundedFile(
          job.artifacts.final,
          config!.maxPreviewBytes,
        ).catch(() => ({
          text: job.metadata.error ?? "(no final output)",
          truncated: false,
        }));
        ctx.ui.notify(
          `${formatJob(job.metadata)}\n\n${result.text}${result.truncated ? "\n[truncated]" : ""}\n\nArtifacts: ${job.artifacts.directory}`,
          job.metadata.status === "done" ? "info" : "warning",
        );
      } catch (error) {
        ctx.ui.notify(errorText(error), "error");
      }
    },
  });

  pi.registerCommand("delegate-search", {
    description: "Search Context Mode artifacts for one delegate job",
    handler: async (raw, ctx) => {
      try {
        const { id, query } = parseSearchArguments(raw);
        const job = (await getManager(ctx)).get(id);
        if (!job) throw new Error(`Unknown delegate job: ${id}`);
        const result = await searchDelegateArtifacts(
          contextMode,
          job.metadata,
          job.artifacts,
          query,
          config!.maxPreviewBytes,
        );
        ctx.ui.notify(
          `${result.output || "(no matches)"}${result.truncated ? "\n[truncated]" : ""}${result.warning ? `\nWarning: ${result.warning}` : ""}`,
          result.warning ? "warning" : "info",
        );
      } catch (error) {
        ctx.ui.notify(errorText(error), "error");
      }
    },
  });

  pi.registerCommand("delegate-stop", {
    description: "Stop a queued or running delegate job",
    handler: async (raw, ctx) => {
      try {
        const id = parseJobId(raw);
        await (await getManager(ctx)).stop(id);
        ctx.ui.notify(`Stopped ${id}.`, "info");
      } catch (error) {
        ctx.ui.notify(errorText(error), "error");
      }
    },
  });

  pi.registerCommand("delegate-attach", {
    description: "Attach a bounded result to the next parent-model turn",
    handler: async (raw, ctx) => {
      try {
        const id = parseJobId(raw);
        const job = (await getManager(ctx)).get(id);
        if (!job) throw new Error(`Unknown delegate job: ${id}`);
        const result = await readBoundedFile(
          job.artifacts.final,
          config!.maxAttachBytes,
        ).catch(() => ({
          text: job.metadata.error ?? "(no final output)",
          truncated: false,
        }));
        const source = `delegate:${id}`;
        pi.sendMessage(
          {
            customType: "delegate-attachment",
            content: [
              `Explicitly attached delegate result`,
              `Job: ${id}`,
              `Backend: ${job.metadata.delegate}`,
              `Status: ${job.metadata.status}`,
              `Artifacts: ${job.artifacts.directory}`,
              `Context source: ${source}`,
              result.truncated ? "Result was truncated." : "",
              "",
              result.text,
            ]
              .filter((line, index) => line || index >= 7)
              .join("\n"),
            display: true,
            details: { id, source, truncated: result.truncated },
          },
          { deliverAs: "nextTurn" },
        );
        ctx.ui.notify(`${id} attached for the next user turn.`, "info");
      } catch (error) {
        ctx.ui.notify(errorText(error), "error");
      }
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    sessionContext = ctx;
    await getManager(ctx).catch((error) =>
      ctx.ui.notify(errorText(error), "error"),
    );
  });

  pi.on("session_shutdown", async () => {
    const manager = managerPromise
      ? await managerPromise.catch(() => undefined)
      : undefined;
    sessionContext = undefined;
    await manager?.shutdown();
    managerPromise = undefined;
    config = undefined;
    executables = undefined;
    contextMode = undefined;
  });
}
