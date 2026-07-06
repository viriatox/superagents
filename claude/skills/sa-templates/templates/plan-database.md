# Plan: {{task-id}} / {{project}} (database)

- refinement: `refinement.md`
- project root: {{path}}
- migration tool: {{liquibase | flyway | plain scripts | …}}
- apply/verify command: {{exact command}}
- rules consulted: {{files from sa-rules manifest}}

## Scope in this project
<!-- which FRs/ACs require schema or data changes -->

## Changesets (execute in order)
<!-- exact file paths mandatory; DDL/DML summary precise enough to implement without exploring -->
| # | changeset id / file | operation | objects affected | DDL/DML summary | rollback |
|---|---|---|---|---|---|

## Data migration considerations
<!-- backfills, defaults for existing rows, volume/locking concerns -->

## Contracts exposed
<!-- tables/columns/sequences other plans rely on; exact names and types -->

## Risks
