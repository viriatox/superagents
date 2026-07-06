---
description: "[hybrid] Superagents DEVELOP — opencode implements per-project plans in order; Claude validates each"
argument-hint: <task-id (optional if only one task is ready)>
---

Load the `sa-workflow` skill (Skill tool) before doing anything else. Then execute phase **DEVELOP** with variant **HYBRID**.

Input: $ARGUMENTS

Hybrid reminders:
- Implementation is delegated per project, in the high-level plan's order, to opencode `sa-coder` via Bash (fresh call per project, 10-min timeout); builds run via opencode `sa-verifier`.
- After each project: capture the diff with git yourself, then validate diff+plan+report with the `sa-validator` subagent before moving on.
- You (main thread) never read application source code — you read only `.superagents/` artifacts and run git diff commands.
