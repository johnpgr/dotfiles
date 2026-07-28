# pi-delegates

A Pi extension that runs a second coding agent as a background job.

Each job runs in its own process, outside the context of the parent model. The extension writes all job output to files on disk. The parent model receives no part of that output until you attach it with a command.

The extension registers commands and five model-facing tools. Slash commands behave as before. The tools let the parent model spawn, inspect, wait for, and cancel delegate jobs on its own.

The extension supports four delegates: Codex, Claude Code, Cursor Agent, and Antigravity.

## Requirements

- A trusted Pi project. The launch commands fail in an untrusted project.
- At least one delegate program on your `PATH`: `codex`, `claude`, `agent`, or `agy`.
- Context Mode, if you want artifact search. The extension works without it and records a warning on each job.

## Install

1. Run `npm install` in this directory. Pi loads the TypeScript sources directly through jiti, so there is no build step.
2. Add the path of this directory to the `packages` array in `~/.pi/agent/settings.json`.
3. Start Pi.

## Tools

The parent model can delegate on its own with these tools:

| Tool              | Purpose                                                                                  |
| ----------------- | ---------------------------------------------------------------------------------------- |
| `delegate_spawn`  | Queue a background job (`task`, `delegate`, optional `profile`, optional `working_dir`). |
| `delegate_wait`   | Block until listed jobs settle and return bounded final output.                          |
| `delegate_check`  | Peek at status and a short output preview without blocking.                              |
| `delegate_cancel` | Stop one or more queued or running jobs.                                                 |
| `delegate_list`   | List all tracked jobs.                                                                   |

Tool calls require a trusted Pi project. Tools always submit with `dangerousBypass: false`, so Antigravity in the implementation profile is rejected — use `/delegate-agy --implementation --dangerous` for that combination.

After `delegate_spawn`, the model should keep working. Results arrive through `delegate_wait` or as a TUI entry when a job settles unawaited. Auto-appended results are UI-only (`appendEntry`); they do not enter the parent model's context. If the model calls `delegate_wait`, the same result is not appended twice.

`delegate_wait` returns at most 48 KiB total and 16 KiB per job. `delegate_check` previews at most 2 KiB. Full transcripts stay on disk under the job artifact directory.

## Commands

| Command            | Argument           | Action                                                 |
| ------------------ | ------------------ | ------------------------------------------------------ |
| `/delegate-codex`  | `[flags] <task>`   | Queues a Codex job.                                    |
| `/delegate-claude` | `[flags] <task>`   | Queues a Claude Code job.                              |
| `/delegate-agent`  | `[flags] <task>`   | Queues a Cursor Agent job.                             |
| `/delegate-agy`    | `[flags] <task>`   | Queues an Antigravity job.                             |
| `/delegate-status` | `[job-id]`         | Shows one job, or the 12 most recent jobs.             |
| `/delegate-result` | `<job-id>`         | Shows the final output in the TUI.                     |
| `/delegate-search` | `<job-id> <query>` | Searches the indexed artifacts of one job.             |
| `/delegate-stop`   | `<job-id>`         | Stops a queued or running job.                         |
| `/delegate-attach` | `<job-id>`         | Sends the result to the parent model on the next turn. |

A job ID has the form `dlg-<time>-<random>`, for example `dlg-m9x2k4-a1b2c3d4e5`.

### Example

```
/delegate-codex --plan Read src/auth and list every place that reads the session cookie.
/delegate-status
/delegate-result dlg-m9x2k4-a1b2c3d4e5
/delegate-attach dlg-m9x2k4-a1b2c3d4e5
```

The extension keeps the newlines, blank lines, and indentation of the task text. You can paste a multi-line task after the flags.

## Flags

| Flag               | Effect                                                         |
| ------------------ | -------------------------------------------------------------- |
| `--plan`           | Runs the delegate in a read-only profile. This is the default. |
| `--implementation` | Lets the delegate change files.                                |
| `--dangerous`      | Turns off the permission checks of the delegate.               |
| `--`               | Ends the flags. Use it when the task text starts with `--`.    |

Flags must come before the task text. The parser stops at the first token that does not start with `--`.

A task is limited to 32 KiB of UTF-8 text.

## Profiles and permissions

The profile controls which flags the extension passes to the delegate program.

| Delegate     | Plan profile                    | Implementation profile                                                 |
| ------------ | ------------------------------- | ---------------------------------------------------------------------- |
| Codex        | `--sandbox read-only`           | `--sandbox workspace-write`                                            |
| Claude Code  | `--permission-mode plan`        | `--permission-mode acceptEdits --allowedTools Edit,Write,NotebookEdit` |
| Cursor Agent | `--sandbox enabled --mode plan` | `--sandbox enabled`                                                    |
| Antigravity  | `--sandbox --mode plan`         | `--sandbox --mode accept-edits`                                        |

`--dangerous` replaces these flags with the bypass flag of each delegate. Three rules limit it:

1. `--dangerous` requires `--implementation`.
2. The delegate needs `allowDangerousBypass: true` in `pi-delegates.json`. Only `agy` has this by default.
3. Antigravity in the implementation profile always requires `--dangerous`. Its headless mode cannot ask for permission, so it denies every edit without the bypass.

## Job lifecycle

A job holds one of five states.

| Status    | Meaning                                              |
| --------- | ---------------------------------------------------- |
| `queued`  | The job waits for a free slot.                       |
| `running` | The delegate process runs.                           |
| `done`    | The delegate exited with code 0.                     |
| `error`   | The delegate failed, or the job reached its timeout. |
| `stopped` | You stopped the job, or Pi shut down.                |

Two limits control the scheduler:

- `maxConcurrent` sets how many jobs run at the same time across all projects.
- One implementation job runs at a time for each working directory. Plan jobs have no such limit. This stops two delegates from writing to the same tree at once.

A job that reaches `timeoutMinutes` gets the status `error` and the message `Delegate timed out.`

When a session starts, the extension reads the jobs of the current project from disk. Any job still marked `queued` or `running` becomes `stopped`, because the process did not survive the previous session.

## Artifacts

Each job writes to its own directory:

```
$PI_AGENT_DIR/delegate-runs/<project-id>/<job-id>/
```

`PI_AGENT_DIR` defaults to `~/.pi/agent`. The project ID combines the directory name with the first 12 hex characters of the SHA-256 hash of the canonical path.

| File                | Content                                                 |
| ------------------- | ------------------------------------------------------- |
| `metadata.json`     | Job record: status, times, exit code, warnings.         |
| `prompt.txt`        | The task text as sent to the delegate.                  |
| `final.md`          | The final answer of the delegate.                       |
| `execution.log`     | Standard error, and standard output for some delegates. |
| `events.jsonl`      | Raw JSON events. Cursor Agent only.                     |
| `.context-mode.log` | Output of the Context Mode calls.                       |

The extension creates directories with mode `0700` and files with mode `0600`. It writes `metadata.json` to a temporary file first, then renames it, so a reader never sees a half-written record.

The extension bounds every read of an artifact. `/delegate-result` reads at most `maxPreviewBytes`, `/delegate-attach` reads at most `maxAttachBytes`, and both mark a cut file as truncated.

The extension deletes job directories older than `artifactRetentionDays` when a session starts. It uses the modification time of the directory.

## Configuration

The extension reads `$PI_AGENT_DIR/pi-delegates.json`. The file is optional.

If the file is missing, the extension uses the defaults. If the file is present but invalid, the extension shows a warning and uses the defaults for every value. It does not merge a partial file, so a config file must set every key.

| Key                     | Default | Maximum |
| ----------------------- | ------- | ------- |
| `maxConcurrent`         | 4       | 64      |
| `maxTracked`            | 64      | 4096    |
| `maxPreviewBytes`       | 4096    | 1048576 |
| `maxAttachBytes`        | 6144    | 1048576 |
| `indexFinalOutput`      | `true`  | —       |
| `indexExecutionLog`     | `false` | —       |
| `artifactRetentionDays` | 14      | 3650    |

Each entry under `delegates` accepts four keys:

| Key                    | Default                                               | Notes                                                                   |
| ---------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------- |
| `enabled`              | `true`                                                | A disabled delegate rejects every launch.                               |
| `timeoutMinutes`       | 60 for `codex` and `claude`, 30 for `agent` and `agy` | Maximum 1440.                                                           |
| `executable`           | Not set                                               | Must be an absolute path. A relative path makes the whole file invalid. |
| `allowDangerousBypass` | `true` for `agy` only                                 | Required for `--dangerous`.                                             |

Example:

```json
{
    "maxConcurrent": 2,
    "maxTracked": 64,
    "maxPreviewBytes": 4096,
    "maxAttachBytes": 6144,
    "indexFinalOutput": true,
    "indexExecutionLog": false,
    "artifactRetentionDays": 14,
    "delegates": {
        "codex": { "enabled": true, "timeoutMinutes": 90 },
        "claude": { "enabled": true, "timeoutMinutes": 60 },
        "agent": { "enabled": false, "timeoutMinutes": 30 },
        "agy": { "enabled": true, "timeoutMinutes": 30, "allowDangerousBypass": true }
    }
}
```

If `executable` is not set, the extension searches `PATH` for the delegate name. On Windows it also tries each suffix in `PATHEXT`.

## Context Mode

After a job settles, the extension passes its artifacts to Context Mode. This keeps the text searchable without loading it into the parent model.

The extension finds the program in this order:

1. The `CONTEXT_MODE_BIN` environment variable.
2. `~/.pi/agent/npm/node_modules/.bin/context-mode`.
3. Each directory in `PATH`.

It indexes `final.md` when `indexFinalOutput` is true, and `execution.log` and `events.jsonl` when `indexExecutionLog` is true. Each file gets the source label `delegate:<job-id>:<suffix>`. An index call stops after 30 seconds. A failed call adds a warning to the job and does not change the job status.

`/delegate-search` returns at most 5 matches and stops after 15 seconds.

Indexing runs after a stop or a timeout as well, because the artifacts written before the stop are still on disk.

## Limits

- The extension does not read the parent conversation. A delegate receives only the task text you type.
- A delegate cannot resume, and you cannot steer it after it starts. Stop the job and start a new one.
- The extension reports no list of changed files. Use `git status` in the working directory.
- The extension tracks at most `maxTracked` jobs for each project. When the job count reaches the limit, the extension drops the oldest settled jobs. Their directories stay on disk until retention removes them.
- A submission fails if every tracked slot holds an unsettled job.
- Each Pi session runs its own scheduler, so `maxConcurrent` applies for each session and not for the machine. Job records still persist on disk, and a new session reads them back.

## Development

| Command             | Action                                                                                                         |
| ------------------- | -------------------------------------------------------------------------------------------------------------- |
| `npm run check`     | Type-checks the sources and the tests. jiti strips types without checking them, so this is the only type gate. |
| `npm test`          | Compiles the tests and runs them with the Node test runner.                                                    |
| `npm run test:live` | Runs the tests that call the real delegate programs.                                                           |
| `npm run format`    | Formats with oxfmt.                                                                                            |

The live tests need `PI_DELEGATES_LIVE=1` and the delegate programs on `PATH`. The `test:live` script sets the variable.

### Layout

| Path                  | Role                                                                 |
| --------------------- | -------------------------------------------------------------------- |
| `index.ts`            | Registers commands and tools; holds session state.                   |
| `src/manager.ts`      | Schedules jobs, tracks state, runs timeouts, and supports `waitFor`. |
| `src/tools.ts`        | Registers the five `delegate_*` tools.                               |
| `src/prompt.ts`       | Tool descriptions and parameter text for the parent model.           |
| `src/backends/`       | One file for each delegate. Builds the argument list.                |
| `src/process.ts`      | Spawns processes and stops process trees.                            |
| `src/artifacts.ts`    | Artifact paths, atomic writes, bounded reads, retention.             |
| `src/config.ts`       | Loads `pi-delegates.json` and finds executables.                     |
| `src/context-mode.ts` | Indexes and searches artifacts.                                      |
| `src/schema.ts`       | TypeBox schemas for the config, the metadata, and the Cursor events. |
| `src/display.ts`      | Formats the status line and the result entry.                        |

The extension validates every value that crosses a trust boundary against a schema in `src/schema.ts`. This covers the config file, each metadata file read from disk, and each JSON event from Cursor Agent. `src/types.ts` derives the TypeScript types from those schemas, so a schema change updates the types.

Processes start with `shell: false` and a fixed argument list. To stop a job, the extension signals the whole process group with `SIGTERM`, waits 1500 ms, then sends `SIGKILL`. It waits for the `close` event, not the `exit` event, because a child that outlives its parent can hold the inherited streams open.
