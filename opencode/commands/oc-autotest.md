---
description: "[full-opencode] Superagents AUTOTEST — optional automation testing driven by the automation rules; execution optional"
agent: sa-orchestrator
---
Agent guard: this command must run as `sa-orchestrator` (this file's frontmatter selects it — the TUI slash command and `opencode run --command oc-autotest "<args>"` both honour it). If you are any OTHER agent (e.g. `build`, which happens when this command's text is passed as a plain `opencode run` message), do NOTHING — no exploration, no file changes, no delegation; reply only: `ERROR: wrong agent — use /oc-autotest in the opencode TUI, or headless: opencode run --command oc-autotest "<args>"`.

Load the `sa-workflow` skill first, then execute phase **AUTOTEST** with variant **FULL-OC**.
Input: $ARGUMENTS
Reminders: the phase is configured entirely by the `automation`-tagged rules file (none registered → report and stop); plan via @sa-planner, implementation via @sa-autotester (static check only), validations via @sa-validator with the feedback loop; ask the user before executing the suite via @sa-verifier.
