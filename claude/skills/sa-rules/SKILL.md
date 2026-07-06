---
name: sa-rules
description: Select and load coding/testing rules for the superagents workflow. Use whenever writing or validating a refinement, plan, code change, or tests — to load ONLY the rule files that match the work at hand.
---

# sa-rules — rule selection

Rule files live in `rules/` next to this SKILL.md (installed globally: `~/.claude/skills/sa-rules/rules/`). Both Claude Code and opencode read this location.

## Procedure

1. Read `rules/rules-manifest.md`.
2. Collect tags describing the current work: technology (`java`, `angular`, `database`, …), layer (`controller`, `service`, `repository`, …), and activity (`test`, `unit`, `integration`, …). Tags come from the refinement/plan/exploration artifacts — never from assumption.
3. From the **Rules index** table, load every file whose tag set intersects your tags. When a technology matches, its `*-general-rules.md` is always included.
4. Load **only** the matched files. Never load the whole rules directory — this is a token-budget rule as much as a correctness one.
5. No match for a technology in play → write "no rules found for `<tech>`" in the artifact you are producing and proceed with general good practice.
6. List every rule file you consulted in the artifact's "rules consulted" section, so validators load the same set.

## Test waves

The **Test waves** table in the manifest defines which test types exist, which rules file governs each, the wave order, and the trigger deciding whether a wave applies to a given change scope. The TEST phase must derive its waves exclusively from that table — never from a hardcoded notion of test types.

## Customizing

Drop new rule files into `rules/` and register them in the manifest with tags (and a wave row if they define a test type). Nothing else needs to change — agents discover rules only through the manifest. The shipped rule files are **starter examples**; replace them with your organization's real rules.
