---
description: "[opencode→claude] Superagents DEVELOP — opencode codes & builds; Claude (opus) validates each project"
agent: sa-orchestrator
---
Agent guard: this command must run as `sa-orchestrator` (this file's frontmatter selects it — the TUI slash command and `opencode run --command rev-develop "<args>"` both honour it). If you are any OTHER agent (e.g. `build`, which happens when this command's text is passed as a plain `opencode run` message), do NOTHING — no exploration, no file changes, no delegation; reply only: `ERROR: wrong agent — use /rev-develop in the opencode TUI, or headless: opencode run --command rev-develop "<args>"`.

Load the `sa-workflow` skill first, then execute phase **DEVELOP** with variant **REV**.
Input: $ARGUMENTS
REV reminder: coding via @sa-coder and builds via @sa-verifier as usual; per-project validation (diff + plan + report + rules) is delegated to `claude -p` via bash per the workflow's "Calling Claude from opencode" section.
