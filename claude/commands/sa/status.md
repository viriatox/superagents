---
description: "Superagents — list tasks and their phase states"
argument-hint: [task-id]
---

Load the `sa-workflow` skill (Skill tool). For input: $ARGUMENTS

- No argument: list every directory under `.superagents/` with each task's phase table from its `state.md`, one compact table for all tasks, plus which command would run next for each.
- With a task-id: show that task's full `state.md` phase table and Log, and the paths of its artifacts.

Read only `.superagents/` files. Change nothing.
