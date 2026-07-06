---
description: "Superagents — approve a phase that is awaiting approval (works for tasks from any variant)"
agent: sa-orchestrator
---
Agent guard: this command must run as `sa-orchestrator` (this file's frontmatter selects it — the TUI slash command and `opencode run --command oc-approve "<args>"` both honour it). If you are any OTHER agent (e.g. `build`, which happens when this command's text is passed as a plain `opencode run` message), do NOTHING — no exploration, no file changes, no delegation; reply only: `ERROR: wrong agent — use /oc-approve in the opencode TUI, or headless: opencode run --command oc-approve "<args>"`.

Load the `sa-workflow` skill first, then run the **explicit approval flow** for: $ARGUMENTS
(Resolve task and phase — default: the single `awaiting-approval` phase; show a ≤10-line artifact summary + validation verdict; on user confirmation set `approved` with today's date in state.md and append a Log line.)
