---
description: "[full-opencode] Superagents DEVELOP — implement per-project plans in order, validate each"
agent: sa-orchestrator
---
Agent guard: this command must run as `sa-orchestrator` (this file's frontmatter selects it — the TUI slash command and `opencode run --command oc-develop "<args>"` both honour it). If you are any OTHER agent (e.g. `build`, which happens when this command's text is passed as a plain `opencode run` message), do NOTHING — no exploration, no file changes, no delegation; reply only: `ERROR: wrong agent — use /oc-develop in the opencode TUI, or headless: opencode run --command oc-develop "<args>"`.

Load the `sa-workflow` skill first, then execute phase **DEVELOP** with variant **FULL-OC**.
Input: $ARGUMENTS
