---
description: "[hybrid] Superagents PLAN — per-project plans + high-level plan from an approved refinement"
argument-hint: <task-id (optional if only one task is ready)>
---

Load the `sa-workflow` skill (Skill tool) before doing anything else. Then execute phase **PLAN** with variant **HYBRID**.

Input: $ARGUMENTS

Hybrid reminders:
- Any missing codebase knowledge → delegate exploration to opencode `explore` via Bash, output redirected to `context/exploration-<n>.md`.
- Write plans with the `sa-planner` subagent (one project per invocation, then the high-level plan); validate with `sa-validator`. Pass file paths, not content.
- You (main thread) never read application source code.
