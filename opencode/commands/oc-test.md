---
description: "[full-opencode] Superagents TEST — test waves per type from the rules manifest, validated per wave"
agent: sa-orchestrator
---
Agent guard: this command must run as `sa-orchestrator` (this file's frontmatter selects it — the TUI slash command and `opencode run --command oc-test "<args>"` both honour it). If you are any OTHER agent (e.g. `build`, which happens when this command's text is passed as a plain `opencode run` message), do NOTHING — no exploration, no file changes, no delegation; reply only: `ERROR: wrong agent — use /oc-test in the opencode TUI, or headless: opencode run --command oc-test "<args>"`.

Load the `sa-workflow` skill first, then execute phase **TEST** with variant **FULL-OC**.
Input: $ARGUMENTS
