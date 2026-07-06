---
name: sa-workflow
description: State machine, delegation tables, and artifact contracts for the superagents refine → plan → develop → test orchestration. Load FIRST when executing any /sa:* (hybrid), oc-* (full opencode), or rev-* (opencode→claude) phase command.
---

# Superagents workflow

You are the ORCHESTRATOR for one phase of a development task. Follow this file exactly. Do only what the phase procedure says — nothing else.

## Core principles (every phase, every variant)

1. **Never read application source code yourself.** Exploration is always delegated (see delegation table). You read only files under `.superagents/` and the sa-* skill files (the sa-rules manifest and rule files, the sa-templates templates) — never the application's own files.
2. **Pass context by file path, never by content.** Delegation prompts reference artifact paths; never paste file contents into them. Keep delegation prompts under ~10 lines. Always write artifact paths IN FULL from the repository root (`.superagents/<task-id>/...`) — never abbreviated — or delegates will write their outputs to the wrong location.
3. **No knowledge without evidence.** Anything about the codebase must come from an artifact file a delegate wrote. If it is not in a file, it is unknown — delegate an exploration; never guess.
4. **Verify every delegation** (see Output contract) before acting on it.
5. **Rules are mandatory.** Every writing and validating step selects rules via the `sa-rules` skill manifest and loads ONLY the matched files.
6. **Technology and architecture agnostic.** Never assume microservices, monolith, language, or framework. Project structure comes only from exploration artifacts.
7. **The user may be asked questions at any point** when requirements are ambiguous or a decision changes scope. Record every question and answer in the current artifact.
8. **One simple shell command per call — every phase, every variant.** Compound shell commands (`&&`, `||`, `;`, pipes that chain state-changing steps) cannot match permission allowlists: interactively they cause needless prompts, and in headless runs the resulting `ask` is auto-rejected and has killed whole phases. Run steps as separate single commands. A rejected permission is routine, not a failure — switch to an allowed alternative (a dedicated tool, or a simpler command) and continue.

## Task store

All state lives in `.superagents/<task-id>/` inside the target repository:

```
.superagents/<task-id>/
├── state.md                     # phase state machine (template: state)
├── context/
│   ├── prompt.md                # user's original input, verbatim
│   ├── jira.md                  # written by sa-jira
│   └── exploration-<n>.md       # explore results, one per question
├── refinement.md                # + refine-validation.md
├── plans/
│   ├── high-level.md            # + plan-validation.md
│   └── plan-<project>.md
├── develop/
│   ├── report-<project>.md
│   ├── diff-<project>.patch
│   ├── verify-<project>.md
│   └── validation-<project>.md
├── test/
│   ├── change-scope.txt
│   ├── wave-<n>-<type>.md
│   ├── verify-wave-<n>-<type>.md
│   └── validation-wave-<n>-<type>.md
└── autotest/                    # optional phase
    ├── plan.md                  # scenarios + delivered-work handoff (self-contained)
    ├── plan-validation.md
    ├── report.md
    ├── validation.md
    └── verify.md                # only when the suite was executed
```

**task-id**: the Jira key if one is present (e.g. `PROJ-123`), otherwise a short kebab-case slug of the prompt (e.g. `add-export-endpoint`).

**Task resolution** when a phase command receives arguments:
- Argument matches an existing directory under `.superagents/` → resume that task.
- Otherwise (REFINE only) treat the arguments as a new task's input.
- Other phases with no matching task-id: pick the single task whose previous phase is `approved` (or `awaiting-approval`) and whose own phase is `pending`. If none or several qualify, list the candidates with their states and ask the user.

## State machine

`state.md` holds one row per phase: `refine → plan → develop → test → autotest`.
Statuses: `pending → in-progress → awaiting-approval → approved` (or `failed`).

- **Gate**: a phase may start only when the previous phase is `approved` (REFINE has no gate).
- On phase start set `in-progress`; on success set `awaiting-approval` plus the artifact path. **Never set `approved` yourself** — only the approval flow below does.
- Append one line to the `## Log` section for every status change.

**Approval flow** (both forms are always available):
- *Explicit*: the approve command shows a ≤10-line summary of the phase artifact, asks the user to confirm, then sets `approved` + date.

When telling the user which command to run (to approve, check status, or start the next phase), ALWAYS name the command of the variant you are running — never the other side's. For commands that serve any variant's tasks (`/oc-approve`, `/oc-status`, `/sa:approve`, `/sa:status`), take the variant from the task's `state.md` `variant:` field and name THAT variant's phase commands:

| you are running | approve | status | phases |
|---|---|---|---|
| HYBRID (inside Claude Code) | `/sa:approve` | `/sa:status` | `/sa:refine` `/sa:plan` `/sa:develop` `/sa:test` `/sa:autotest` |
| FULL-OC (inside opencode) | `/oc-approve` | `/oc-status` | `/oc-refine` `/oc-plan` `/oc-develop` `/oc-test` `/oc-autotest` |
| REV (inside opencode) | `/oc-approve` | `/oc-status` | `/rev-refine` `/rev-plan` `/rev-develop` `/rev-test` `/rev-autotest` |
- *Inline*: when a phase starts and the previous phase is `awaiting-approval`, show the same ≤10-line summary and ask the user to approve. Approved → record in state.md and continue. Rejected → stop and ask what to change.

**Commit boundaries**: the workflow itself never commits. When setting DEVELOP or TEST to `approved` and the working tree still holds the task's changes, end your summary with: *"Reminder: commit this task's changes before starting another task in this repository"* — the DEVELOP baseline gate will refuse to start a new task over uncommitted work.

Only a phase in `awaiting-approval` can be approved. **Re-running a phase**: if a phase command is invoked while that same phase is `awaiting-approval` or `failed`, ask the user what should change, then apply their feedback through the validation feedback loop (FIX mode to the producer, then re-validate) rather than starting over. Re-doing an already `approved` phase requires explicit user confirmation and resets all later phases to `pending` (with a Log entry).

## Output contract (all delegated agents)

Every delegate must end with exactly one line:
- `DONE <path> (<n> lines) — <max 12 words>` after writing its artifact, or
- `BLOCKED — <reason / missing info>`.

Contract-line discipline (all variants, all models):
- Before replying `DONE`, the delegate RE-READS its file from disk and takes `<n>` from what it actually read — a `DONE` for a file that does not exist is a contract violation, and "the coordinator's check must be stale" is never an acceptable answer to a missing-file retry.
- The contract line is plain text starting at column 1 with `DONE ` or `BLOCKED ` — no bold, no backticks, no heading marker.
- The contract line goes ONLY in the reply, never inside the artifact file itself.
- `<path>` names the artifact this delegation produced — not some other file it happened to touch.

**Verification after every delegation:**
1. Confirm the reported file exists and has real content (check its headings; do not fully read large files).
2. Missing file, empty file, or malformed reply → retry ONCE, stating exactly what was wrong. Second failure → set the phase `failed` in state.md and report to the user.
3. `BLOCKED` → resolve the missing input (usually: delegate an exploration, or ask the user), then re-delegate.

**Fix loops** after a FAIL/RED: see *Validation feedback loop* below.

## Validation contract

Validators write a report file ending with `VERDICT: PASS` or `VERDICT: FAIL` followed by numbered issues. The verdict line is plain text starting at column 1 — never a markdown heading (`## VERDICT`) or emphasis (`**VERDICT**`) — so it stays machine-greppable, and it is the LAST line of the report file (the reply's contract line never goes into the file). Validators are read-only with respect to everything except their own report file.

**Standing ruling — test files (TEST and AUTOTEST):** new test files created by a test wave or the automation phase are legitimate work products. Validators must not flag them as unplanned scope or suspected hallucination merely because they are absent from the refinement's affected-areas table — that table enumerates production impact, not future test files. Their content is still validated normally (described tests must exist, map to ACs, and follow the wave's rules). **This ruling NEVER excuses a failing existing suite**: a RED build/verify caused by existing tests not being updated for the change is a blocking defect of the change (DEVELOP fix-loop work), not deferrable test-phase work — validators must FAIL it.

## Validation feedback loop (validator ↔ implementer)

Every validation gate — and every verifier `RESULT: RED` — closes a loop with the agent that produced the work. This applies to ALL of them, no exceptions:

| produced work | producer to re-delegate to |
|---|---|
| refinement | refinement writer (per delegation table) |
| project plan / high-level plan / autotest plan | plan writer |
| code diff, or build RED | sa-coder |
| test wave, or test-run RED (test defects) | sa-tester |
| automation tests, or automation-run RED (test defects) | sa-autotester |

Loop mechanics:
1. Validator FAILs (or verifier reports RED) → re-delegate to the SAME producer in **FIX mode**: prompt names the task-id, the artifact it produced, the validation/verify report path, and the instruction *"FIX mode: apply only the numbered issues in the report; change nothing else."* Never fix the work yourself; never switch producers mid-loop.
2. Producer replies with the normal `DONE`/`BLOCKED` contract; verify as usual (for code/tests, recapture the diff and re-run the verifier first).
3. Re-run the SAME validation with the same inputs, fresh validator context → report saved with a `-r<n>` suffix (e.g. `validation-backend-r2.md`).
4. Maximum 2 fix cycles per gate. Still FAIL → stop, show the user the latest report path and the unresolved issues, and ask how to proceed.

Test-run failures must be classified before looping: defects in the tests go to the producer as above; suspected defects in production code are recorded as findings in the report and reported to the user — the TEST/AUTOTEST phases never modify production code.

**Conflict escalation**: when a validator exposes a contradiction BETWEEN artifacts (e.g. the refinement excludes something the rules manifest requires), the resolution is a USER decision — present both readings, wait for the answer, then apply it via FIX mode to the artifact the user rules against. Never pick a side unilaterally. And regardless of cause: the orchestrator never deletes or edits source files itself — reverts and deletions are producer work (FIX mode).

## Delegation tables

Legend: `OC:<x>` = opencode agent · `CL:<x>` = Claude subagent (Task tool) · `main` = you.

| Work | HYBRID (run from Claude) | REV (run from opencode) | FULL-OC (run from opencode) |
|---|---|---|---|
| Orchestration | CL main thread | OC:sa-orchestrator | OC:sa-orchestrator |
| Jira fetch | OC:sa-jira via bash | OC:sa-jira | OC:sa-jira |
| Code exploration | OC:explore via bash | OC:explore | OC:explore |
| Write refinement | CL:sa-refiner | `claude -p` via bash | OC:sa-refiner |
| Write plans (incl. autotest plan) | CL:sa-planner | `claude -p` via bash | OC:sa-planner |
| Implement code | OC:sa-coder via bash | OC:sa-coder | OC:sa-coder |
| Implement tests | OC:sa-tester via bash | OC:sa-tester | OC:sa-tester |
| Implement automation tests | OC:sa-autotester via bash | OC:sa-autotester | OC:sa-autotester |
| Run builds/tests | OC:sa-verifier via bash | OC:sa-verifier | OC:sa-verifier |
| Validate artifacts | CL:sa-validator | `claude -p` (read-only role) | OC:sa-validator |

Jira access exists ONLY in opencode (`sa-jira`). Never attempt Jira access any other way.

### Delegating within opencode (REV and FULL-OC)

When you ARE opencode (sa-orchestrator), invoke `OC:<x>` agents **natively** — the task tool / `@mention` subagent invocation — never via bash and never with `opencode run`, which would nest a fresh opencode process and session (slow, expensive, and outside your permission context). One delegation per subagent invocation, prompt ≤10 lines as usual; the subagent's reply ends with the contract line, and you still verify the promised file on disk. The ONLY bash delegation in these variants is REV's `claude -p` call below. The bash snippets in the HYBRID section are for Claude's main thread only.

**Headless caveat (REV and FULL-OC)**: in a non-interactive run (`opencode run --command <name> "<args>"` — note it MUST be the `--command` flag; a plain `opencode run "/oc-refine …"` message is NOT command dispatch and lands in the default `build` agent), every permission the config marks `ask` is AUTO-REJECTED. Stay strictly inside the orchestrator's allowlist (single simple commands), treat any rejection as routine (switch to an allowed alternative), and know that `opencode run` exits 0 even when the session dies mid-phase — after a headless phase run, `state.md` is the only truth: a phase still `in-progress` means the run died and must be resumed.

### HYBRID: calling opencode from Claude

Use the Bash tool, fresh session per delegation, timeout 600000 ms (the model backend can be slow — on timeout retry once; for many calls consider `opencode serve` + `--attach`):

```bash
opencode run --agent sa-coder "Task <task-id>. Implement the plan at .superagents/<task-id>/plans/plan-<project>.md. Write your report to .superagents/<task-id>/develop/report-<project>.md (template: dev-report, skill sa-templates). End with the DONE/BLOCKED contract line." < /dev/null 2>/dev/null
```

**Token rule — exploration**: the built-in `explore` agent answers on stdout; redirect it straight to the context file so it never enters your context:

```bash
opencode run "@explore In this repository: <one focused question>. Answer with relevant files as path:line, key symbols, conventions, integration points. Max 80 lines." < /dev/null > .superagents/<task-id>/context/exploration-<n>.md 2>/dev/null
```

Then verify with `head -5` of the file only.

Every `opencode run` call MUST redirect stdin from `/dev/null` (as in the snippets above) — without a terminal attached, opencode waits indefinitely for piped stdin and the call hangs silently. Two more context guards: append `2>/dev/null | tail -3` to non-explore delegations — the contract line is all you need in context; the delegate's report belongs in its file. And NEVER pass a `mode: subagent` agent to `--agent`: `opencode run --agent <subagent>` does not error — it silently falls back to the default full-permission `build` agent. This applies to the built-in `explore` AND to opencode's `sa-refiner`, `sa-planner`, and `sa-validator`. For any of those, use the mention form (`opencode run "@sa-planner …"` / `"@explore …"`). The `--agent` flag is safe only for the sa-* workers (`sa-jira`, `sa-coder`, `sa-tester`, `sa-verifier`, `sa-autotester`), which are `mode: all` precisely so direct selection works.

### REV: calling Claude from opencode

The orchestrator shells out one-shot `claude -p` calls. Pass file paths only; the prompt defines the role:

```bash
claude -p "You are the <REFINEMENT WRITER | PLAN WRITER | VALIDATOR> for superagents task <task-id>. Load skills sa-workflow, sa-templates, sa-rules. Read ONLY these files: <paths>. Do NOT read application source code. Write <output path> using template <name>, applying the matched rules. End your reply with the contract line: DONE <path> — <summary>." --model opus --permission-mode acceptEdits --allowedTools "Read,Write,Edit,Glob,Grep,Skill" --add-dir ~/.claude/skills < /dev/null
```

The prompt MUST come immediately after `-p`, before the flags — `--allowedTools` is variadic and silently consumes a trailing prompt as a tool name, making the call fail with "Input must be provided". `--add-dir ~/.claude/skills` guarantees template/rule reads outside the repo; `< /dev/null` avoids a stdin-wait delay.

For validator calls, the output path is the validation report and the prompt must state the `VERDICT: PASS|FAIL` requirement — including that the verdict is the file's LAST line with nothing after it (advisory notes go above it). The `claude` CLI must be authenticated (see INSTALL.md).

Do NOT probe for the CLI first (`which claude`, `claude --version`, or compound availability checks): the probe adds nothing, compound commands never match the allowlist, and in headless runs the resulting `ask` is auto-rejected — which has killed whole phases. Call `claude -p` directly; if the binary is missing, that call itself fails with a clear error → report BLOCKED naming it.

---

## Phase procedures

### REFINE

1. Resolve task-id. Create `.superagents/<task-id>/` (+ `context/`), write `context/prompt.md` with the user's input verbatim, create `state.md` from the `state` template. Set refine `in-progress`.
2. If the input contains a Jira key → delegate **jira fetch** → `context/jira.md`.
3. Derive 1–3 focused exploration questions from the requirements (affected features, existing similar code, project layout). Delegate each to **explore** → `context/exploration-<n>.md`.
4. Select rules with the `sa-rules` manifest based on the technologies/areas the exploration revealed.
5. Delegate **refinement writing**. Inputs (paths only): `context/prompt.md`, `context/jira.md` (if any), exploration files, template `refinement`, matched rule files. Output: `refinement.md`.
6. If the writer returns open questions (or the refinement's Open Questions section is non-empty): relay them to the user, record answers in the Q&A section, re-delegate an amendment.
7. Delegate **validation**: refinement vs original prompt + jira + user answers + rules → `refine-validation.md`.
8. FAIL → fix loop. PASS → set `awaiting-approval`, show the user a ≤10-line summary + artifact path.

### PLAN

1. Resolve task (requires refine approved — apply inline approval if `awaiting-approval`). Set plan `in-progress`.
2. Read `refinement.md` (orchestrators may read `.superagents/` artifacts).
3. Determine the involved projects from the *Affected areas* section. A monolith is simply one project. If project boundaries or file locations are unclear → delegate exploration first.
4. For each project **sequentially**: pick the template via `sa-templates` (`plan-java` / `plan-angular` / `plan-database`, else `plan-generic`), select rules by tags, delegate **plan writing** → `plans/plan-<project>.md`. One project per delegation, fresh context.
5. Delegate **high-level plan writing**: inputs are `refinement.md` + the list of project-plan paths. Output `plans/high-level.md` with execution order, dependency rationale, and cross-project contracts (APIs, DTOs, migrations).
6. Delegate **validation** per project plan (plan vs refinement + rules), then one coherence pass over `high-level.md` (order sound? contracts consistent? everything in the refinement covered?) → `plans/plan-validation.md`.
7. FAIL → fix loop. PASS → `awaiting-approval` + ≤10-line summary (projects, order, step counts).

### DEVELOP

1. Resolve task (requires plan approved). Set develop `in-progress`. **Baseline gate (HARD)**: run `git status --porcelain` — if there are pre-existing changes outside `.superagents/`, STOP and require the user to commit or stash them first (they are usually a previous task's approved-but-uncommitted work). Never proceed on a dirty baseline: the foreign changes end up inside this task's diffs, validators will correctly flag them as scope creep, and the fix loop will then REVERT ANOTHER TASK'S WORK. A generic prior "user confirmed" does NOT satisfy this gate — it needs an explicit user answer about these specific dirty files.
2. Read `plans/high-level.md` → execution order (e.g. database → shared library → backend → gateway → frontend; whatever the plan says).
3. For each project **in order**, complete a–e before starting the next:
   a. Delegate **sa-coder** with the project plan path (fresh context) → `develop/report-<project>.md`.
   b. Capture the diff yourself — run as two separate commands (compound `&&` commands don't match bash permission allowlists): `git add -A`, then `git diff HEAD -- <project paths from the plan> > .superagents/<task-id>/develop/diff-<project>.patch`.
   c. Delegate **sa-verifier**: run the build command from the plan (+ existing test suite if the plan lists one) → `develop/verify-<project>.md` with exact commands and exit codes.
   d. Delegate **validation**: diff + plan + dev report + matched rules → `develop/validation-<project>.md`.
   e. FAIL or broken build → fix loop via sa-coder (issues only, ≤2 attempts), recapture diff, re-verify, re-validate. A RED verify ALWAYS triggers this loop — a validator PASS never overrides a RED build.
4. All projects done AND every `develop/verify-*.md` (latest revision per project) ends `RESULT: GREEN` → `awaiting-approval` + summary (projects, files changed count, build results). The phase must NEVER be set `awaiting-approval` while any latest verify report is RED.

### TEST

1. Resolve task (requires develop approved). Set test `in-progress`.
2. Establish change scope — two separate commands: `git add -A`, then `git diff HEAD --stat -- . ':(exclude).superagents' > .superagents/<task-id>/test/change-scope.txt`. If the working tree is clean (changes already committed), ask the user for the base ref and use `git diff <base>...HEAD --stat -- . ':(exclude).superagents'`.
3. Read the **Test waves** table in the `sa-rules` manifest. For EVERY row of the table, record a one-line verdict — in the state.md Log and in your output: `wave <n> <type>: RUNS — <file(s) from change-scope.txt matching the trigger>` or `wave <n> <type>: SKIPPED — <why the trigger does not match>`. Select the waves marked RUNS; order by wave number. A wave whose trigger matches the change scope may never be silently skipped — the verdict lines make every skip reviewable. **A matched trigger is BINDING**: the wave runs, adapting its rules file to the project's actual stack; "the rules assume a different framework" or any other feasibility argument is never a skip reason — only a non-matching trigger justifies SKIPPED.
4. For each wave **sequentially, one fresh delegation per wave** (never combine waves — this is the context-contamination guard):
   a. Delegate **sa-tester**: test type, its rules file, `change-scope.txt`, the relevant plan + dev-report paths → writes tests + `test/wave-<n>-<type>.md`.
   b. Delegate **sa-verifier**: run that wave's tests → `test/verify-wave-<n>-<type>.md` (type in the name — several types can share a wave number).
   c. Delegate **validation**: tests vs the wave's rules file + acceptance-criteria coverage from `refinement.md` → `test/validation-wave-<n>-<type>.md`.
   d. FAIL → fix loop (≤2). Only then start the next wave.
5. All waves done → `awaiting-approval` + summary (the step-3 wave verdict lines, tests added, results) — the user approves the skips together with the results.

### AUTOTEST (optional — end-to-end automation)

Optional last phase; it blocks nothing and runs only when the user invokes it. It must be runnable in a completely fresh session: every input comes from `.superagents/<task-id>/` artifacts, and its own plan carries a delivered-work handoff so no earlier conversation is needed.

1. Resolve task (requires test approved — inline approval applies). Set autotest `in-progress`.
2. **Configuration check**: look up the tag `automation` in the sa-rules manifest's Rules index. No match → tell the user automation testing is not configured (they must add an automation rules file + manifest row), set the phase back to `pending`, stop. What can be automated (API calls to a gateway, frontend UI flows, …), where the automation project lives, and the commands all come from that rules file — never hardcode them.
3. Delegate exploration of the automation project named by the rules (config, existing specs, fixtures/page objects, conventions) → `context/exploration-auto-<n>.md`.
4. Delegate **autotest plan writing** (the plan-writer row of the delegation table). Inputs: `refinement.md` (acceptance criteria), `plans/high-level.md`, `develop/report-*.md`, `test/wave-*.md`, the automation rules file, the automation exploration. Output: `autotest/plan.md` (template `plan-autotest`) — it opens with the delivered-work handoff compiled from those reports, then the scenarios to automate with exact spec file paths.
5. Delegate **validation** of the plan (vs refinement ACs + dev reports + automation rules) → `autotest/plan-validation.md`. Feedback loop until PASS.
6. Delegate **sa-autotester**: implement the plan's scenarios per the rules. Static verification only at this step (the rules' static check, e.g. compile/list — no suite execution) → `autotest/report.md`.
7. Delegate **validation** of the tests (vs plan + rules + AC coverage) → `autotest/validation.md`. Feedback loop until PASS.
8. **Optional execution** — ask the user: "Is the environment ready to execute the automation suite (prerequisites: see the plan's environment section)?"
   - No → record `executed: no` + reason in `autotest/report.md`; continue to 9.
   - Yes → establish the environment, then run. The plan's environment section enumerates EVERY required service (any number — frontends, multiple backends, gateways), each with its base URL and local start command.
     - *HYBRID*: the ORCHESTRATOR owns the lifecycle — probe each service's URL; for each one that is down and locally runnable, start it yourself (one simple background command per service) and wait until it responds; after the run, stop every process you started (and only those). Then delegate **sa-verifier** with a NARROW prompt — "environment is up (URLs verified), run <suite command> from <dir>, write the verify report" — the execution delegation must never carry server-lifecycle work.
     - *REV / FULL-OC*: delegate the whole job to **sa-verifier** with the rules' run command AND the automation rules file path — the verifier owns the environment per the rules' lifecycle contract (rule 14: probe → start what is down and locally runnable → run → stop what it started).
     - Any service unreachable and not locally runnable → ask the user / BLOCKED naming it, never RED. Output either way: `autotest/verify.md`. On RED, classify: test defects → feedback loop via sa-autotester (fix, re-verify, ≤2 cycles); suspected product defects → record as findings in the report and inform the user (never change production code in this phase).
   - **After any completed run (GREEN or RED)**: update `autotest/report.md`'s executed block — `executed: yes`, run command, pass/fail counts, findings — so the report the user approves always matches `verify.md`. A report still saying `executed: no` after a run is a contract violation.
9. Set `awaiting-approval` + ≤10-line summary (scenarios implemented, static check result, executed or not, run results/findings).

---

## Token economy checklist (re-check before every step)

- Exploration output goes to files via shell redirection (hybrid) — never through your context.
- Read artifacts, never source. Read only what the current step needs.
- Delegation prompts: paths, not content; ≤10 lines.
- User-facing summaries: ≤10 lines.
- Validators load only manifest-matched rule files.
- One project / one wave per delegation, always a fresh context.
