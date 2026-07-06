# Superagents — installation & validation

Global installation — scripted (`./install.sh`, recommended) or manual copy; both fully documented below, followed by the **file inventory**, **model configuration**, the **validation script**, headless rules, the permission model, and troubleshooting.

After installing, all **3 variants × 5 phases** coexist; you choose one per task simply by which command you invoke (see README §Commands).

## Prerequisites

1. **Claude Code CLI** installed and authenticated (`claude --version`; run `claude` once and log in). Needed for HYBRID and REV.
2. **opencode ≥ 1.16** installed (`opencode --version`). Needed by all variants (HYBRID shells out to it). Earlier versions had a subagent-permission regression.
3. **A model for opencode** — either a provider already authenticated in opencode (check `opencode models`) or a custom OpenAI-compatible endpoint. Wired in [Model configuration](#model-configuration-required-per-machine).
4. **A Jira MCP server** (optional — your internal one). Jira is opencode-only by design; without it, tasks simply start from plain prompts.
5. `git` available in the target repositories.

---

## Option A — automatic installation (recommended)

```bash
git clone <this repo>   # or copy the tree anywhere
cd superagents
./install.sh
./validate-install.sh   # verify everything landed (details below)
```

What `install.sh` does, step by step:

1. **Sanity check** — refuses to run unless the full source tree is next to it (`claude/agents`, `claude/commands/sa`, the three skills, `opencode/agents`, `opencode/commands`, `opencode/opencode.jsonc`).
2. **Claude side** — copies `claude/agents/*` → `~/.claude/agents/`, `claude/commands/*` → `~/.claude/commands/` (creating `commands/sa/`), and `claude/skills/*` → `~/.claude/skills/`. The skills are installed **once, here only** — opencode reads `~/.claude/skills/` natively.
3. **opencode side, layout-aware** — opencode reads both directory layouts (singular `agent/`+`command/` and plural `agents/`+`commands/`). The script detects which one your machine already uses and copies into **that** one (default: plural) so the install is never split across layouts.
4. **Config, never clobbered** — if no `opencode.json[c]` exists, the shipped one is installed fresh (edit its `REPLACE-ME` placeholders). If one exists, it is **left untouched** and the superagents keys are written next to it as `opencode.superagents.jsonc` for you to merge by hand (`model`/`small_model` or your `provider`, `mcp.jira`, `tools."jira*"`, `permission.external_directory`).
5. **Summary** — prints file counts per side and the remaining manual steps.

Idempotent: rerun it after every source update (`git pull && ./install.sh`). Override targets with `CLAUDE_DIR=... OC_DIR=... ./install.sh`.

Then do [Model configuration](#model-configuration-required-per-machine) and run `./validate-install.sh`.

## Option B — manual installation

### Step 1 — Claude side (also serves opencode)

```bash
mkdir -p ~/.claude/agents ~/.claude/commands ~/.claude/skills
cp -r claude/agents/.   ~/.claude/agents/       # sa-refiner, sa-planner, sa-validator
cp -r claude/commands/. ~/.claude/commands/     # creates ~/.claude/commands/sa/ (7 files)
cp -r claude/skills/.   ~/.claude/skills/       # sa-workflow, sa-templates, sa-rules
```

The three skills (workflow logic, templates, rules + manifest) are installed **once** here — opencode discovers `~/.claude/skills/` natively, so both tools share the same workflow, templates, and rules. Do **not** duplicate them into `~/.config/opencode/`.

### Step 2 — opencode side

Check which layout your machine already has (`ls ~/.config/opencode/` → `agent`/`command` or `agents`/`commands`) and copy into **that** one; use plural if starting fresh:

```bash
mkdir -p ~/.config/opencode/agents ~/.config/opencode/commands
cp -r opencode/agents/.   ~/.config/opencode/agents/     # 9 sa-* agents
cp -r opencode/commands/. ~/.config/opencode/commands/   # 7 oc-* + 5 rev-* commands
```

### Step 3 — opencode config

Open `opencode/opencode.jsonc` and **merge its keys into** `~/.config/opencode/opencode.json[c]` (create the file if absent). Do not blindly overwrite an existing config — merge:

- `model` / `small_model` (or the placeholder `provider` block) — see [Model configuration](#model-configuration-required-per-machine).
- `mcp.jira` — your Jira MCP launcher + credentials, then `"enabled": true` (shipped disabled so a placeholder launcher doesn't error at startup).
- `"tools": { "jira*": false }` — disables Jira globally; only `sa-jira` re-enables it. If your Jira MCP's tools aren't prefixed `jira`, adjust the pattern here **and** in `sa-jira.md`.
- `permission.external_directory` — must allow `~/.claude/skills/**` (that's how opencode agents read the shared skills).

---

## File inventory — what must exist where

After installation, these files/folders must exist. (`validate-install.sh` checks all of this for you.)

### `~/.claude/` (Claude Code side — also read by opencode)

| Path | Files | Purpose |
|---|---|---|
| `~/.claude/agents/` | `sa-refiner.md`, `sa-planner.md`, `sa-validator.md` | HYBRID writer/validator subagents (opus) |
| `~/.claude/commands/sa/` | `refine.md`, `plan.md`, `develop.md`, `test.md`, `autotest.md`, `approve.md`, `status.md` | the `/sa:*` commands |
| `~/.claude/skills/sa-workflow/` | `SKILL.md` | state machine, delegation tables, contracts — loaded first by every phase |
| `~/.claude/skills/sa-templates/` | `SKILL.md` + `templates/` (11 templates) | artifact templates |
| `~/.claude/skills/sa-rules/` | `SKILL.md` + `rules/rules-manifest.md` + rule files | rules + Test-waves table + automation enablement |

### `~/.config/opencode/` (opencode side)

| Path | Files | Purpose |
|---|---|---|
| `agent/` **or** `agents/` | `sa-orchestrator.md`, `sa-refiner.md`, `sa-planner.md`, `sa-validator.md`, `sa-coder.md`, `sa-tester.md`, `sa-autotester.md`, `sa-verifier.md`, `sa-jira.md` | 9 opencode agents (one layout only — never split) |
| `command/` **or** `commands/` | `oc-refine/plan/develop/test/autotest/approve/status.md` + `rev-refine/plan/develop/test/autotest.md` | 12 commands |
| `opencode.json[c]` | merged config | model, Jira MCP, `external_directory` allow for `~/.claude/skills/**` |

### Per target repository (created by the workflow, not the installer)

| Path | Purpose |
|---|---|
| `.superagents/<task-id>/state.md` | phase gates + log — the single source of truth |
| `.superagents/<task-id>/…` | all phase artifacts (see README §4) |
| repo `.gitignore` | **recommended:** add `.superagents/` |

---

## Model configuration (required, per machine)

The sa-* agents deliberately don't pin a model — they inherit opencode's `model`/`small_model`, so the model is chosen **in one place per machine**: the opencode config.

**Route (a) — an opencode-authenticated provider** (most common):

```jsonc
// ~/.config/opencode/opencode.jsonc
{
  "model": "opencode-go/deepseek-v4-flash",        // any entry from `opencode models`
  "small_model": "opencode-go/deepseek-v4-flash"
  // …and DELETE the placeholder "provider" block
}
```

1. `opencode models` → pick an id you're authenticated for (`opencode auth login` if needed).
2. Set both `model` and `small_model`.
3. Remove the shipped placeholder `provider` block (it's only for route b).

**Route (b) — your own OpenAI-compatible endpoint** (vLLM, llama.cpp server, an internal gateway):

```jsonc
{
  "provider": {
    "internal": {
      "npm": "@ai-sdk/openai-compatible",
      "options": { "baseURL": "https://your-endpoint/v1", "apiKey": "REPLACE-ME" },
      "models": { "your-model-id": { "name": "your-model-id" } }
    }
  },
  "model": "internal/your-model-id",
  "small_model": "internal/your-model-id"
}
```

**To change the model later**: edit those two keys, nothing else. Verify with:

```bash
opencode run --agent sa-verifier "Reply with exactly: PING-OK" < /dev/null
```

Notes from live testing: slow backends make phases take minutes per delegation (normal); if calls time out, start `opencode serve` once and add `--attach http://localhost:4096` to scripted `opencode run` calls. The Claude side (HYBRID writers/validators, REV `claude -p`) always uses your Claude Code account's models — no configuration needed.

---

## Validation — `validate-install.sh`

Run after every install/update, before starting orchestrations:

```bash
./validate-install.sh          # static checks only (fast, no model calls)
./validate-install.sh --live   # + live probes: opencode agent, skill load, claude -p
```

It checks, in order:

1. **Binaries** — `claude`, `opencode` (with version), `git`.
2. **Claude side** — the 3 agents, 7 `/sa:` commands, 3 skills, templates present, `rules-manifest.md` present.
3. **opencode side** — layout detection (and a warning if BOTH layouts contain sa-files — split install), all 9 agents, all 12 commands.
4. **Config** — an `opencode.json[c]` exists; `model` is set and not a `REPLACE-ME` placeholder; warns if an unmerged `opencode.superagents.jsonc` is sitting there; notes whether Jira MCP is enabled.
5. **Content freshness** — key markers that must exist in the deployed copies (agent guard in commands, environment-lifecycle rule in the automation rules, wave-verdict + binding-trigger rules in the workflow, validator verdict contract). Catches a stale deploy after a source update.
6. **`--live` only** — a `PING-OK` round-trip through an sa agent (proves model + agent selection), a skill-tool load of `sa-workflow` (proves opencode sees the shared skills), and `claude -p "reply OK"` (proves REV/HYBRID's Claude path).

Exit code 0 = ready for orchestrations; any FAIL is printed with the exact path/command that's wrong.

---

## First run

In a target repository:

```bash
# HYBRID, full cycle
claude
> /sa:refine PROJ-123 Add CSV export to the orders list
> /sa:plan          # asks inline approval for refine, or /sa:approve first
> /sa:develop
> /sa:test
> /sa:autotest      # optional
> /sa:status        # any time

# FULL-OC — same flow inside opencode
opencode
> /oc-refine PROJ-123 Add CSV export to the orders list
> /oc-plan
...

# REV — same, /rev-* phases (approve/status stay /oc-*)
```

Each phase ends `awaiting-approval`; approve explicitly (`/sa:approve` · `/oc-approve`) or inline when starting the next phase. To resume days later, run the next phase command with the task-id — state lives in `.superagents/<task-id>/state.md`. **Commit between tasks** — DEVELOP refuses to start over a dirty baseline.

## Headless / scripted use (opencode variants)

The `/oc-*` and `/rev-*` phases can be run non-interactively, with three hard rules:

```bash
# 1. ALWAYS the --command flag. A plain  opencode run "/oc-refine …"  is NOT command
#    dispatch: the text goes to the default full-permission `build` agent, which will
#    happily implement your feature directly — no workflow, no artifacts, exit 0.
#    (The command files carry an agent guard that refuses mis-dispatch; don't rely on it.)
opencode run --command oc-refine "PROJ-123 Add CSV export" < /dev/null

# 2. Headless runs auto-reject every `ask` permission. The orchestrator's allowlist
#    covers the workflow's own commands; anything off-list dies silently.

# 3. `opencode run` exits 0 even when the session dies mid-phase. Trust ONLY state.md:
grep -A7 '## Phases' .superagents/<task-id>/state.md
#    awaiting-approval / failed = finished · still in-progress = died → re-run to resume.
```

Also: every scripted `opencode run` needs `< /dev/null` (otherwise it waits forever for piped stdin). Approval needs a second turn: `opencode run --command oc-approve "<task>"` then `opencode run -c "yes, approve"`. When a phase stops with an open question, re-run the phase command with the answer in the argument text. REV headless additionally needs `claude -p` working non-interactively. For long unattended runs, supervise the process (if it produces no session writes for ~10+ minutes, kill and re-run — state resumes) and prefer generous timeouts.

## Customizing rules & templates (post-install)

- **Rules**: edit/add files in `~/.claude/skills/sa-rules/rules/` and register them in `rules-manifest.md` (tags; plus a Test-waves row if it's a test type; an `automation`-tagged row enables the AUTOTEST phase). The shipped files are starter examples — replace them with your organization's real rules.
- **Templates**: add `plan-<type>.md` files in `~/.claude/skills/sa-templates/templates/` — picked up automatically by the resolution rule.
- **Per-project overrides**: both tools prefer project-level skills, so a repo can carry its own `.claude/skills/sa-rules/` to override the global rules.
- Keep the **source tree canonical**: edit here, then `./install.sh` to sync — not the other way around.

## Permission model (opencode agents)

The opencode agents carry `permission` blocks in their frontmatter — harness-level enforcement backing the prompt rules, so a hallucinated tool call hits a wall instead of executing. Three tiers:

- **Artifact writers** (`sa-refiner`, `sa-planner`, `sa-validator`): `bash`/`webfetch`/`websearch` denied, `edit` allowed only under `.superagents/**`.
- **Code workers** (`sa-coder`, `sa-tester`, `sa-autotester`, `sa-verifier`, `sa-jira`): broad `read`/`edit`/`bash` where the job needs it (verifier and jira are write-scoped to `.superagents/**`); `webfetch`/`websearch`/`doom_loop` denied. **No `ask` rules** — these run headless in HYBRID.
- **Orchestrator** (`sa-orchestrator`): bash allowlist (`git`, `test`, `head`, `tail`, `ls`, `cat`, `grep`, `find`, `mkdir`, `touch`, `claude`, …) with `"*": ask` as safety net. Single simple commands only — compound commands (`a && b`) can't match allowlists and auto-reject headless; the workflow itself mandates one command per call.

Smoke-test the edit sandbox once after installing (inside any git repo):

```bash
opencode run --agent sa-orchestrator "Diagnostic, skip the workflow: use the write tool to create .superagents/ping.md with content 'pong', then try to create ./outside-test.txt. Report both outcomes exactly, then stop."
```

Expected: the `.superagents/` write succeeds, the repo-root write is denied.

Tuning notes: pattern precedence is **last-match-wins** (catch-alls first, specifics after); each agent's block is self-contained — edit the agent file, not the global config; `read` sandboxes for paths outside the project don't match reliably (verified 1.16.2), so reads are prompt-enforced and skills access relies on the global `external_directory` allow; `tools` (deprecated for permissions) is still used for the one thing permissions can't do — enabling/disabling **MCP tools** by name (`jira*`). Authoritative schema: <https://opencode.ai/config.json>, docs: <https://opencode.ai/docs/permissions/>.

## Troubleshooting

- **`validate-install.sh` fails** — it prints the exact missing path or stale marker; rerun `./install.sh` from an up-to-date source tree.
- **Command or agent not found in opencode** — split layout: check `ls ~/.config/opencode/` and keep everything in ONE of `agent/`+`command/` or `agents/`+`commands/`. `install.sh` auto-detects; the validator warns on splits.
- **`opencode run --agent <agent>` runs the wrong agent** — for `mode: subagent` agents, `--agent` **silently falls back** to the default `build` agent. Workers are `mode: all` (safe); for `explore`/subagent-mode agents use the mention form: `opencode run "@explore <question>"`.
- **`opencode run` hangs forever when scripted** — missing `< /dev/null` (it waits for piped stdin).
- **A phase "finished" with exit 0 but nothing happened** — check `state.md`; still `in-progress` means the session died. Re-run the same phase command to resume. This is by design: exit codes lie, state.md doesn't.
- **A phase stopped asking a question (headless)** — that's correct behavior; re-run the phase command with the answer in the argument.
- **Claude usage limit hit mid-phase (REV/HYBRID)** — the phase reports BLOCKED and is resumable; wait for the limit window to reset and re-run the phase command. Nothing is lost.
- **Model backend stalls** (no output, no session writes for 10+ minutes) — kill the run and re-run the phase; consider `opencode serve` + `--attach`. Sporadic with some hosted backends; the state machine absorbs it.
- **Jira tools visible outside sa-jira** — the merged config must keep `"tools": { "jira*": false }`; adjust the pattern (and `sa-jira.md`) if your MCP's tool names aren't `jira`-prefixed.
- **A phase refuses to start** — the previous phase isn't `approved`: `/sa:status` (or `/oc-status`), then approve.
- **Skills not found by opencode** — the config's `permission.external_directory` must allow `~/.claude/skills/**`; the skills live only under `~/.claude/skills/` by design.

## Performance & cost notes

- HYBRID makes many `opencode run` calls; a slow backend dominates wall time. `opencode serve` + `--attach` removes per-call startup cost.
- Token economy is enforced by the workflow (exploration → files, path-based handoffs, fresh context per project/wave, manifest-matched rules only). The first knob if opus usage feels high in HYBRID: fewer exploration questions per refinement (default ≤3).
- FULL-OC costs zero Claude tokens; REV spends Claude only on writing/validating.

## Uninstall

Remove `~/.claude/commands/sa/`, the `sa-*` entries in `~/.claude/agents/` and `~/.claude/skills/`, the `sa-*` agents plus `oc-*`/`rev-*` commands in `~/.config/opencode/agent(s)/command(s)/`, the merged keys in your opencode config, and `opencode.superagents.jsonc` if present. Task state stays in each repository's `.superagents/` (delete per repo if unwanted).
