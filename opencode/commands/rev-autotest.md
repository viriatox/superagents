---
description: "[opencode→claude] Superagents AUTOTEST — optional automation testing; Claude (opus) writes the plan and validates"
agent: sa-orchestrator
---
Agent guard: this command must run as `sa-orchestrator` (this file's frontmatter selects it — the TUI slash command and `opencode run --command rev-autotest "<args>"` both honour it). If you are any OTHER agent (e.g. `build`, which happens when this command's text is passed as a plain `opencode run` message), do NOTHING — no exploration, no file changes, no delegation; reply only: `ERROR: wrong agent — use /rev-autotest in the opencode TUI, or headless: opencode run --command rev-autotest "<args>"`.

Load the `sa-workflow` skill first, then execute phase **AUTOTEST** with variant **REV**.
Input: $ARGUMENTS
Reminders: the phase is configured entirely by the `automation`-tagged rules file (none registered → report and stop); autotest plan writing and all validations are delegated to `claude -p` via bash per the workflow's "Calling Claude from opencode" section; implementation via @sa-autotester (static check only); ask the user before executing the suite via @sa-verifier. Feedback loops per the workflow.
