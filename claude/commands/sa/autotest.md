---
description: "[hybrid] Superagents AUTOTEST — optional automation testing (e.g. Playwright) driven by the automation rules; execution optional"
argument-hint: <task-id (optional if only one task is ready)>
---

Load the `sa-workflow` skill (Skill tool) before doing anything else. Then execute phase **AUTOTEST** with variant **HYBRID**.

Input: $ARGUMENTS

Hybrid reminders:
- Everything the phase needs comes from `.superagents/` artifacts and the `automation`-tagged rules file — if no such rules file is registered in the manifest, report that and stop.
- Exploration of the automation project via opencode `explore` (Bash, output redirected to `context/exploration-auto-<n>.md`); autotest plan via the `sa-planner` subagent; implementation via opencode `sa-autotester` (Bash); validations via `sa-validator` with the feedback loop.
- Execution of the suite is optional — ask the user about environment readiness before delegating the run to opencode `sa-verifier`.
- You (main thread) never read application source code.
