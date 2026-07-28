# pi-delegates — open tasks

Findings from a full review of the extension (source, tests, docs) plus two live
four-delegate runs against a real codebase. Line references are current as of writing.

Status legend: **open** — not started. **verified** — fixed and covered by a test.

---

## P1 — Correctness the model can act on

### 1. An exit-0 run that produces no output is reported as `done`

**Where:** `src/manager.ts:395`

Status is derived from the exit code alone, so a delegate that exits cleanly having
written nothing to `final.md` is indistinguishable from one that did the work.
`buildDelegateWaitSection` then renders it as **"finished"** with an empty body, and
the model has no way to tell "completed with nothing to say" from "died silently".

This is not hypothetical: it happened in the first live run. An agy delegate was
soft-denied a tool permission, exited 0, wrote 0 bytes to `final.md`, and the
explanation sat unread in `execution.log` because agy writes that diagnostic to
**stderr**. The session summary called it a failure; the tool had called it a success.

Task 5 removes the most common cause but not the class — any harness that exits clean
having produced nothing still lands here.

**Fix:** in the settle path, when `exitCode === 0` and the final artifact is empty,
settle as `error` with `"Delegate produced no output."`, or at minimum push a warning
into `metadata.warnings` so it reaches the model through the result section. Do it in
the manager rather than the tools layer so `/delegate-result` and `/delegate-status`
benefit too.

**Test:** stub backend that exits 0 without writing `final.md`; assert the job does not
settle as a silent `done`.

---

### 2. Audit the other backends for the same headless permission wall

**Where:** `src/backends/claude.ts:16-24`, `src/backends/codex.ts:16-18`,
`src/backends/cursor.ts`

agy's plan profile silently produced nothing whenever a task needed the `command`
permission, because headless `--print` mode has nobody to prompt. Task 5 fixed agy. The
other three run their own permission models and have **not** been checked for the same
class of failure:

| Backend | Plan-profile flags |
|---|---|
| Claude Code | `--permission-mode plan` |
| Codex | `--sandbox read-only` |
| Cursor Agent | `--sandbox enabled --mode plan` |

Codex's `read-only` sandbox is designed for non-interactive use and is probably fine.
Claude Code and Cursor are unknown.

**Fix:** for each, run a plan-profile task that requires a tool likely to need
confirmation (a shell command, a write outside the workspace) and check whether the run
produces output or exits clean and empty. Only then decide whether each needs an
equivalent of the agy change.

---

## P2 — Robustness

### 3. `flushCompletions` deletes the deferred entry before the append can bail

**Where:** `index.ts:117` (delete) vs `index.ts:77` (guard)

```ts
deferredCompletions.delete(id);          // line 117
const result = await appendCompletion(metadata, bundle);
//   ↳ line 77: if (… || waitingIds.has(id)) return Success;   ← bails, entry already gone
```

If a flush ever runs while a wait is in flight, the completion is dropped: deleted from
`deferredCompletions`, never appended.

**Currently unreachable** — both flush triggers (`sessionContext.isIdle()` and
`agent_settled`) imply the agent is not mid-tool-call, so no wait can be open. But that
makes the line-77 guard load-bearing by accident of scheduling; adding a third flush
trigger would silently reintroduce result loss.

**Fix:** skip without deleting, mirroring the `toolDeliveredIds` branch:

```ts
if (waitingIds.has(id)) continue;   // leave deferred; the in-flight wait consumes or releases it
```

---

### 4. `delegate_spawn` does not bound `task` length

**Where:** `src/tools.ts` (spawn `parameters`), compare `src/args.ts:64`

The slash commands reject a task over 32 KiB with a clear message. The tool parameter is
a plain `Type.String()` with no `maxLength`, so an oversized task passes validation,
reaches `submit()`, and fails at `stringifyMetadata` against
`DelegateJobMetadataSchema`'s `maxLength: 32768` — surfacing as a schema error rather
than an actionable one.

**Fix:** `Type.String({ maxLength: 32768, description })` on the `task` parameter so the
model gets rejected up front with a reason it can act on.

---

### 5. A single bad executable override discards the entire config

**Where:** `src/config.ts:53-59`

A non-absolute `executable` for any one delegate returns `DEFAULT_CONFIG` wholesale,
silently resetting unrelated settings — `maxConcurrent`, every `timeoutMinutes`,
`artifactRetentionDays`. The warning says "Using safe defaults" without conveying that
everything else was reverted too.

**Fix:** drop just the offending override and keep the rest of the validated config, or
make the warning state explicitly that the whole file was ignored.

---

### 6. Delegates inherit the full parent environment

**Where:** `src/process.ts:113` — `env: process.env`

Every delegate child gets pi's entire environment, including any API keys, tokens, and
credentials present in the parent shell. This predates the tools work, but its salience
went up with task 5: agy plan runs now auto-approve tool permissions, so a delegate can
execute shell commands (sandboxed) without asking, and anything in `process.env` is
readable from there.

**Fix:** consider an allowlist (`PATH`, `HOME`, `LANG`, `TERM`, plus per-backend auth
vars each CLI genuinely needs) instead of blanket inheritance. Needs a pass over what
each of the four CLIs requires to authenticate before narrowing, or delegates will start
failing to log in.

---

## P3 — Polish, docs, tuning

### 7. README is stale on agy plan permissions

**Where:** `README.md`, "Profiles and permissions"

The table still lists Antigravity plan as `--sandbox --mode plan`. It now also passes
`--dangerously-skip-permissions`. Rule 3 below the table ("Its headless mode cannot ask
for permission, so it denies every edit without the bypass") is still correct for the
implementation profile but reads as if plan is unaffected — which was the bug.

**Fix:** update the agy plan cell and add a sentence explaining that plan auto-approves
because headless mode cannot prompt, while `--sandbox` still bounds it and edits remain
behind `--dangerous`.

---

### 8. A stopped job renders with the failure icon

**Where:** `src/display.ts:37` — `const failed = data.status === "error" || data.status === "stopped"`

Same conflation that was fixed model-side in `buildDelegateWaitSection` (`error` →
"failed", `stopped` → "was stopped"). Here it only picks the icon, so a job the user
deliberately cancelled shows a red `x` in the TUI as though it broke.

**Fix:** third branch, or a neutral icon for `stopped`.

---

### 9. `delegate_wait` byte budget has less headroom than it looks

**Where:** `src/tools.ts` — `WAIT_OUTPUT_MAX_BYTES = 48 * 1024`

A real four-delegate exploration returned 40,499 bytes of `final.md` across the four
jobs — 84% of the total budget, with nothing truncated but roughly 8 KB spare. A fifth
delegate, or slightly longer reports, starts dropping whole sections with
`[omitted: total wait output limit reached]`.

**Fix:** no change needed for fan-outs of four. If wider fan-out becomes normal, raise
the cap deliberately and accept the extra parent context, rather than discovering the
limit through a silently omitted section.

---

### 10. Cursor executable resolves via the generic name `agent`

**Where:** `src/config.ts:64-69` — `DEFAULT_EXECUTABLES.agent = "agent"`

Cursor installs both `agent` and `cursor-agent` as symlinks to the same binary, so this
works today. But `agent` is a generic name and any unrelated tool of that name earlier
on `PATH` would be picked up and spawned with Cursor's flags.

**Fix:** resolve `cursor-agent` first, fall back to `agent`. `resolveExecutable` already
takes a name list, so this is a one-line change to the candidates.

---

### 11. `metadata.warnings` can exceed its schema cap

**Where:** `src/context-mode.ts:57,86` and `src/manager.ts:386`

Warnings are pushed without bound; `DelegateJobMetadataSchema` caps them at 32 items /
4096 chars each. On overflow `stringifyMetadata` fails, `writeMetadataAtomic` returns
`Err`, and the call site wraps it in `ignore(...)` — so the metadata write fails
silently.

In practice at most ~4 warnings are produced per job, so this is latent. Worth a clamp
at the push site if warnings ever become more granular.

---

### 12. A task starting with `--` needs the `--` terminator

**Where:** `src/args.ts:35-59`

`/delegate-codex --look at the auth module` returns `Unknown option: --look`. The `--`
terminator handles it (`/delegate-codex -- --look at …`), but the error doesn't say so.

**Fix:** mention the terminator in the unknown-option message.

---

## Verified fixed

Kept for context — each has test coverage.

| # | Item | Where |
|---|---|---|
| A | `delegate_wait` ignored the abort signal; a wait could pin the turn for up to `timeoutMinutes` | `manager.ts` `waitFor(…, signal)` |
| B | Aborting a wait permanently suppressed the job's result via `toolDeliveredIds` | `onWaitEnd(ids, { consumed })` |
| C | A job settling mid-wait was dropped, not deferred, so a later abort lost it | `index.ts` `onSettled` |
| D | `delegate_check` showed the head of a running job's log while labelling it "Latest output" | `readBoundedTailFile` |
| E | `delegate_wait` showed the head of a failed job's log | `readOutputPreview` tail fallback |
| F | A user-stopped job was reported to the model as "failed" | `buildDelegateWaitSection` |
| G | Unguarded `!` assertions in `delegate_cancel` around an `await` | `tools.ts` |
| H | agy plan runs soft-denied tool permissions and exited 0 with no output | `buildAntigravityArgs` |

Suite: 46 tests, `npm run check` clean.
