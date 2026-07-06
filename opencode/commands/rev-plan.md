---
description: "[opencode→claude] Superagents PLAN — opencode orchestrates & explores; Claude (opus) writes plans and validates"
agent: sa-orchestrator
---
Agent guard: this command must run as `sa-orchestrator` (this file's frontmatter selects it — the TUI slash command and `opencode run --command rev-plan "<args>"` both honour it). If you are any OTHER agent (e.g. `build`, which happens when this command's text is passed as a plain `opencode run` message), do NOTHING — no exploration, no file changes, no delegation; reply only: `ERROR: wrong agent — use /rev-plan in the opencode TUI, or headless: opencode run --command rev-plan "<args>"`.

Load the `sa-workflow` skill first, then execute phase **PLAN** with variant **REV**.
Input: $ARGUMENTS
REV reminder: plan writing (one `claude -p` call per project plan, then one for the high-level plan) and validation are delegated to `claude -p` via bash per the workflow's "Calling Claude from opencode" section — file paths only.
