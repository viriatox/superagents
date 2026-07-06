---
description: "[opencode→claude] Superagents TEST — opencode writes/runs test waves; Claude (opus) validates each wave"
agent: sa-orchestrator
---
Agent guard: this command must run as `sa-orchestrator` (this file's frontmatter selects it — the TUI slash command and `opencode run --command rev-test "<args>"` both honour it). If you are any OTHER agent (e.g. `build`, which happens when this command's text is passed as a plain `opencode run` message), do NOTHING — no exploration, no file changes, no delegation; reply only: `ERROR: wrong agent — use /rev-test in the opencode TUI, or headless: opencode run --command rev-test "<args>"`.

Load the `sa-workflow` skill first, then execute phase **TEST** with variant **REV**.
Input: $ARGUMENTS
REV reminder: waves via @sa-tester and runs via @sa-verifier as usual; per-wave validation is delegated to `claude -p` via bash per the workflow's "Calling Claude from opencode" section. One wave fully finished before the next.
