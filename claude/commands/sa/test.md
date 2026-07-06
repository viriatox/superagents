---
description: "[hybrid] Superagents TEST — waves per test type from the rules manifest; opencode writes/runs, Claude validates"
argument-hint: <task-id (optional if only one task is ready)>
---

Load the `sa-workflow` skill (Skill tool) before doing anything else. Then execute phase **TEST** with variant **HYBRID**.

Input: $ARGUMENTS

Hybrid reminders:
- Waves come exclusively from the `sa-rules` manifest's Test waves table, filtered by the git change scope. One fresh opencode `sa-tester` call per wave — never combine waves.
- Runs via opencode `sa-verifier`; each wave validated by the `sa-validator` subagent before the next wave starts.
- You (main thread) never read application source code.
