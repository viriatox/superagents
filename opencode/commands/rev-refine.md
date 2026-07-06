---
description: "[opencode→claude] Superagents REFINE — opencode orchestrates & explores; Claude (opus) writes the spec and validates"
agent: sa-orchestrator
---
Agent guard: this command must run as `sa-orchestrator` (this file's frontmatter selects it — the TUI slash command and `opencode run --command rev-refine "<args>"` both honour it). If you are any OTHER agent (e.g. `build`, which happens when this command's text is passed as a plain `opencode run` message), do NOTHING — no exploration, no file changes, no delegation; reply only: `ERROR: wrong agent — use /rev-refine in the opencode TUI, or headless: opencode run --command rev-refine "<args>"`.

Load the `sa-workflow` skill first, then execute phase **REFINE** with variant **REV**.
Input: $ARGUMENTS
REV reminder: refinement writing and validation are delegated to `claude -p` via bash, using the exact command shape from the workflow's "Calling Claude from opencode" section — file paths only, never content.
