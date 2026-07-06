---
name: sa-templates
description: Fetch document templates for superagents artifacts (refinement, plans, dev reports, test wave reports, task state). Use whenever creating any file under .superagents/ so every artifact has a consistent, parseable structure.
---

# sa-templates — artifact templates

Templates live in `templates/` next to this SKILL.md (installed globally: `~/.claude/skills/sa-templates/templates/`). Both Claude Code and opencode read this location.

## Available templates

| name | file | used for |
|---|---|---|
| state | state.md | `.superagents/<task>/state.md` |
| refinement | refinement.md | refinement spec |
| plan-high-level | plan-high-level.md | cross-project plan index |
| plan-java | plan-java.md | Java/backend project plan |
| plan-angular | plan-angular.md | Angular/frontend project plan |
| plan-database | plan-database.md | database / migration project plan |
| plan-generic | plan-generic.md | any project type without a specific template |
| plan-autotest | plan-autotest.md | automation test plan incl. delivered-work handoff (AUTOTEST phase) |
| dev-report | dev-report.md | per-project development report |
| test-wave-report | test-wave-report.md | per-wave test report |
| autotest-report | autotest-report.md | automation test implementation/execution report |

## Usage

1. Read the template file for the artifact you are producing.
2. Replace every `{{placeholder}}`; delete sections that are genuinely not applicable (state why in one line rather than leaving them empty).
3. Keep the headings — orchestrators and validators locate content by heading.

## Resolution rule for plans

Pick `plan-<type>` where `<type>` matches the project's technology (`java`, `angular`, `database`). No specific template → `plan-generic`. New template files added to `templates/` as `plan-<type>.md` are picked up automatically by this rule.
