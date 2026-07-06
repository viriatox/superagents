---
description: "[hybrid] Superagents REFINE — Claude analyses/writes/validates; opencode fetches Jira and explores"
argument-hint: <task prompt and/or JIRA-KEY, or task-id to resume>
---

Load the `sa-workflow` skill (Skill tool) before doing anything else. Then execute phase **REFINE** with variant **HYBRID**.

Input: $ARGUMENTS

Hybrid reminders:
- Delegate Jira fetch to opencode via Bash (`opencode run --agent sa-jira …`) and exploration via the mention form (`opencode run "@explore …"` — never `--agent explore`, which silently falls back to the build agent), redirecting explore output straight into `context/exploration-<n>.md` files — never into your context.
- Write the spec with the `sa-refiner` subagent; validate with `sa-validator` (Task tool). Pass file paths, not content.
- You (main thread) never read application source code.
