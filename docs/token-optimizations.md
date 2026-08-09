# Token optimizations — hybrid variant

Input document for a workflow fix pass. Findings from analysing heavy token usage when running
the hybrid (`/sa:*`) variant. Each item states the problem, the fix, and the source files to
change. Ordered by expected impact.

Scope note: the hybrid orchestrator's spend is dominated by **input tokens** — the main-thread
conversation is re-sent on every turn, and every phase adds dozens of turns. Most fixes below
therefore target context size and cache behavior, not output verbosity.

---

## OPT-1 — One session per phase (orchestrator context accumulation)

**Priority: HIGH · Effort: low (doc-only)**

**Problem.** Running `/sa:refine → /sa:plan → /sa:develop → /sa:test` in a single Claude session
means the DEVELOP and TEST loops (the most turn-heavy phases: per project/wave a delegation, a
diff capture, a verify, a validation, plus fix loops) execute on top of the full accumulated
context of every earlier phase. Every turn pays for all of it.

**Fix.** The design already supports cold starts — all state lives in `.superagents/<task-id>/`.
Make it the documented default:

- Each `/sa:*` phase command should be run in a **fresh session** (or after `/clear`).
- Phase commands end by naming the next command; add "run it in a fresh session" to that line.

**Files.**
- `claude/skills/sa-workflow/SKILL.md` — add to *Token economy checklist* and to the
  approval-flow "tell the user which command to run" section.
- `claude/commands/sa/*.md` — one reminder line each.

---

## OPT-1a — Automating the fresh session (no manual `/clear`)

**Priority: MEDIUM · Effort: medium**

`/clear` is user-only — the model can't invoke it and hooks can't clear live context — so
automate the *effect* instead:

**(a) Phase driver script — unattended/campaign runs.** `bin/sa-task.sh <task-id>`: runs each
phase as its own headless one-shot (`claude -p "/sa:<phase> <task-id>" --permission-mode
acceptEdits …`), pausing between phases for a shell-level approve prompt that invokes
`claude -p "/sa:approve <task-id>"`. Fresh session per phase by construction. Caveats: headless
`ask` permissions auto-reject (needs a clean allowlist — same lesson as opencode headless), and
mid-phase user Q&A (REFINE open questions) ends BLOCKED → rerun that phase interactively. A
driver covering only DEVELOP + TEST (turn-heavy, interaction-free) captures most of the value.

**(b) Phase-in-subagent — interactive runs.** Rework `/sa:develop` and `/sa:test` to hand the
entire phase to ONE spawned agent; the main thread only relays the ≤10-line summary, so the
interactive session accumulates ~nothing per phase. Structural catch: subagents cannot spawn
subagents, so the phase orchestrator can't call `CL:sa-validator` via the Task tool — reuse the
REV variant's `claude -p` validator call via Bash instead (DEVELOP/TEST delegation becomes
all-Bash: opencode workers + `claude -p` validators). Side benefit: a leaked delegate stdout
(OPT-5) dies with the subagent instead of polluting the session.

**(c) Reminder-only fallback.** A Stop hook that prints "phase ended — /clear before the next
phase" when `state.md` just moved to `awaiting-approval`. No automation; cheap insurance.

Recommended: (a) + (b) together — they are complementary. Auto-compaction is NOT a substitute
(fires at the context limit, after the tokens are spent, not at phase boundaries).

**Files.**
- New `bin/sa-task.sh` (repo source, machine-agnostic).
- `claude/commands/sa/develop.md`, `claude/commands/sa/test.md` — subagent handoff variant.
- `claude/skills/sa-workflow/SKILL.md` — HYBRID delegation notes for the `claude -p` validator
  path (mirror the REV snippet).
- `install.sh` / `validate-install.sh`.

---

## OPT-2 — Prompt-cache expiry across long delegations

**Priority: HIGH · Effort: low**

**Problem.** Each `opencode run` Bash call may take up to the 10-minute timeout. On the default
5-minute Anthropic cache TTL, the prompt cache expires while the delegation runs, so the next
turn re-writes the **entire conversation** as a cache write (1.25× input cost). A long DEVELOP
phase does this 20+ times against a growing context, with near-zero cache hits. Invisible in the
transcript; shows up as input tokens dwarfing output in `/cost`.

**Fix.** The TTL is not directly controllable, so mitigate:

1. OPT-1 (small context per phase) makes each re-write cheap — this is the main mitigation.
2. Reduce turn count: issue independent tool calls in the same message (e.g. the `head -5`
   artifact verification together with the next step's independent command; the several
   REFINE exploration delegations in parallel). The one-simple-command-per-call rule is about
   compound *shell strings*, not about parallel tool calls — state this explicitly so the
   orchestrator doesn't serialize needlessly.
3. Keep delegation wall-time down where possible (`opencode serve` + `--attach`, see OPT-6).

**Files.**
- `claude/skills/sa-workflow/SKILL.md` — clarify rule 8 (parallel independent tool calls are
  allowed and encouraged); note the cache rationale in the token checklist.

---

## OPT-3 — Model tiers: Sonnet validators, Sonnet orchestration

**Priority: HIGH · Effort: low**

**Problem.** All three Claude subagents (`sa-refiner`, `sa-planner`, `sa-validator`) are pinned
`model: opus`. The validator is the multiplier: it runs per project (DEVELOP) and per wave
(TEST), each revision of a fix loop spawns a **fresh** validator context (`-r2`, `-r3`), and each
context cold-loads templates + matched rules + all input artifacts. One flaky gate = up to 3 full
Opus contexts.

**Fix.**
- `sa-validator` → `model: sonnet`. Validation is mechanical cross-checking (coverage tables,
  rule citations, path existence, verdict formatting) — Sonnet-grade work.
- Keep `sa-refiner` and `sa-planner` on Opus (judgment-heavy writing; also low invocation count).
- Orchestration (main thread): recommend **Sonnet** in the docs. The procedure was written to
  need discipline, not top-tier judgment. Do **not** recommend Haiku: the token guards are
  behavioral per-call disciplines (`tail -3`, `< /dev/null`, full paths), and the high-blast-
  radius judgment gates (dirty-baseline gate, RED classification, binding wave triggers,
  FIX-mode re-delegation instead of self-fixing) are exactly where smaller models take the
  expedient path. If Haiku is ever tried, do it as a throwaway sa-test campaign arm and audit
  the transcript for those specific failure modes.

**Files.**
- `claude/agents/sa-validator.md` — frontmatter `model: sonnet`.
- `README.md` / `INSTALL.md` — recommended session model note for orchestration.

---

## OPT-4 — Diff patch bloat feeding validators

**Priority: HIGH · Effort: medium**

**Problem.** DEVELOP step b runs `git add -A` then diffs the project paths. Anything generated
inside the project and not gitignored (`target/`, `dist/`, `build/`, `node_modules/`, coverage
output, lockfile churn) lands in `diff-<project>.patch`. The validator reads the whole patch in a
fresh context — up to three times through the fix loop. A single bloated patch can dominate an
entire phase's spend.

**Fix.**
1. Add standard excludes to the diff capture command:
   `git diff HEAD -- <project paths> ':(exclude)**/target/**' ':(exclude)**/dist/**'
   ':(exclude)**/build/**' ':(exclude)**/node_modules/**' ':(exclude)**/coverage/**'`
   (same treatment for the TEST phase `change-scope.txt` capture, which already excludes
   `.superagents` — extend the pattern list).
2. Add a **size guard**: after capturing, check the patch size (`wc -c`). Above a threshold
   (suggest 200 KB) the orchestrator must inspect `git diff HEAD --stat` output for generated
   files, fix the capture, and only then delegate validation. Never hand an oversized patch to
   a validator unchecked.

**Files.**
- `claude/skills/sa-workflow/SKILL.md` — DEVELOP step 3b, TEST step 2, token checklist.

---

## OPT-5 — Structural delegation wrapper (stop relying on remembered guards)

**Priority: MEDIUM · Effort: medium**

**Problem.** The context guards on opencode delegations are conventions the orchestrator must
remember on every call: `< /dev/null`, `2>/dev/null`, `| tail -3` for workers, stdout
redirection to the exploration file for `@explore`. One forgotten `tail -3` puts a full coder
narration into the main context permanently. (Also the known footgun: `--agent` with a
subagent-mode agent silently falls back to `build`.)

**Fix.** Ship a wrapper script, e.g. `bin/sa-run.sh`, installed alongside the skills:

```
sa-run.sh worker <agent> "<prompt>"      # stdin </dev/null, full output → per-call log
                                          # under .superagents/<task-id>/logs/, echoes ONLY
                                          # the final contract line; rejects subagent-mode
                                          # agent names for --agent
sa-run.sh explore "<question>" <outfile>  # @explore with stdout → outfile, echoes "wrote
                                          # <outfile> (<n> lines)"
```

The skill then mandates the wrapper instead of raw `opencode run`, turning every guard from a
behavioral rule into code. Keep the raw snippets in the skill as fallback documentation only.

**Files.**
- New `bin/sa-run.sh` (repo source; machine-agnostic — no model/endpoint values inside).
- `install.sh` / `validate-install.sh` — deploy + check it.
- `claude/skills/sa-workflow/SKILL.md` — HYBRID delegation section rewritten around the wrapper.

---

## OPT-6 — Reuse an opencode server

**Priority: LOW · Effort: low**

**Problem.** Every delegation spawns a fresh `opencode run` process (startup + config load), and
delegation wall-time worsens OPT-2. (Fresh *session* per delegation is intentional — context
hygiene — and stays.)

**Fix.** For phases with many delegations, start `opencode serve` once (background) and use
`--attach` per call, as the skill already hints. Fold this into the OPT-5 wrapper so it's
automatic when a server is up. Note: this saves wall-clock and cache churn on the Claude side;
it does not reduce opencode-side tokens, which re-read plan+rules per fresh session by design.

**Files.**
- `bin/sa-run.sh` (with OPT-5), `claude/skills/sa-workflow/SKILL.md`.

---

## OPT-7 — No timeouts on opencode delegations (background execution)

**Priority: HIGH · Effort: medium**

**Problem.** Delegations run as foreground Bash calls with `timeout 600000` — Claude Code's hard
ceiling for foreground commands. Long sa-coder runs hit it, and the current rule ("on timeout
retry once") kills and restarts delegations that were merely slow, doubling their cost.

**Fix.** Launch every opencode delegation as a **background task** (`run_in_background: true`)
instead of a timed foreground call:

1. Command shape: `opencode run --agent <worker> "<prompt>" < /dev/null
   > .superagents/<task-id>/logs/<phase>-<agent>-<n>.log 2>&1` — no timeout parameter at all.
   The call returns immediately; the harness re-invokes the orchestrator when it exits.
2. **Token economy**: happy path costs zero polling turns — do nothing until the exit
   notification. On completion, read `tail -3` of the log for the contract line (same context
   guard as today, applied post-hoc). Never stream or poll delegate output into context.
3. **Liveness / stall policy** (replaces retry-on-timeout): if no exit notification after an
   unusually long silence, check the log's size/mtime once (`stat`). Growing → still working,
   keep waiting. Stalled ≳10 min with no exit → kill the task, retry ONCE stating the stall.
   Kill only on evidence of a hang, never on elapsed time alone.
4. Fold into the OPT-5 wrapper: `sa-run.sh` chooses the log path and echoes it so the
   orchestrator knows what to tail/stat. Sequencing is unchanged — the orchestrator still runs
   one delegation at a time per the phase procedures; background here removes the timeout, it
   does not introduce parallelism.
5. **Verify in a campaign arm**: background-task completion re-invocation under the headless
   `claude -p` driver (OPT-1a) behaves like interactive mode; also confirm opencode exit codes
   surface in the notification (`opencode run` exits 0 even on dead sessions — the contract
   line + state.md remain the real success check, as today).

**Files.**
- `claude/skills/sa-workflow/SKILL.md` — HYBRID delegation section: drop the 600000 ms timeout
  and retry-on-timeout rule; add background launch, notification wait, and stall policy.
- `claude/commands/sa/develop.md` (and other phase commands' hybrid reminder lines mentioning
  the 10-min timeout).
- `bin/sa-run.sh` (with OPT-5).

---

## Existing guards to keep (do not regress in the fix pass)

- Exploration output via shell redirection, never through orchestrator context.
- Delegation prompts: paths only, ≤10 lines; artifact paths written in full.
- Validators load only manifest-matched rule files.
- One project / one wave per delegation, fresh context each.
- Orchestrator never reads application source; artifact checks via headings/`head -5`, not
  full reads.

---

## Diagnostics — how to verify which fix mattered

Run these after a phase on a real task:

1. `/cost` in a fresh-session phase run — input:output ratio ≫ 50× ⇒ context re-send / cache
   misses (OPT-1/2) still dominate.
2. `ls .superagents/<task-id>/**/validation-*-r*.md` — many revision files ⇒ fix-loop
   multiplier (OPT-3) is biting; also look at *why* the gates failed.
3. `wc -c .superagents/<task-id>/develop/diff-*.patch` — anything ≫ 200 KB ⇒ OPT-4.
4. Grep the session transcript for multi-line opencode output blocks ⇒ a missed `tail -3`
   (OPT-5).
5. Compare opencode-side usage separately — hybrid double-bills by design; know which side
   dominates before optimizing further.

## Suggested fix order

1. OPT-3 validator model change (one-line, immediate saving).
2. OPT-1 + OPT-2 doc changes to SKILL.md and phase commands.
3. OPT-4 diff excludes + size guard.
4. OPT-5 wrapper script (+ OPT-6 and OPT-7 folded in — background launch replaces the
   timeout), then update installer and re-run a sa-test campaign arm to confirm no
   behavioral regressions.
5. OPT-1a automation (driver script, then the phase-in-subagent rework) once 1–4 are stable —
   it changes run mechanics, so land it separately and validate with its own campaign arm.
