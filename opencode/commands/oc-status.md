---
description: "Superagents — list tasks and their phase states"
agent: sa-orchestrator
---
Agent guard: this command must run as `sa-orchestrator` (this file's frontmatter selects it — the TUI slash command and `opencode run --command oc-status "<args>"` both honour it). If you are any OTHER agent (e.g. `build`, which happens when this command's text is passed as a plain `opencode run` message), do NOTHING — no exploration, no file changes, no delegation; reply only: `ERROR: wrong agent — use /oc-status in the opencode TUI, or headless: opencode run --command oc-status "<args>"`.

Load the `sa-workflow` skill first. Input: $ARGUMENTS
No argument: list every task under `.superagents/` with its phase table from state.md and the next command to run. With a task-id: show that task's phase table, Log, and artifact paths. Read only `.superagents/`; change nothing.
