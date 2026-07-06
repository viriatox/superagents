---
description: "Superagents — approve a phase that is awaiting approval (any variant's tasks)"
argument-hint: <task-id> [phase]
---

Load the `sa-workflow` skill (Skill tool), then run the **explicit approval flow** for: $ARGUMENTS

- Resolve the task (and phase — default: the task's single `awaiting-approval` phase; if none, say so and stop).
- Show a ≤10-line summary of the phase artifact plus its validation verdict, and ask the user to confirm.
- On confirmation set the phase to `approved` with today's date in `state.md` and append a Log line. On rejection, ask what should change and leave the status untouched.
