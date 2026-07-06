# Database rules

<!-- STARTER EXAMPLE — replace with your organization's real rules. -->

1. Every schema change is a migration (Liquibase changeset / Flyway script per project tooling); never edit a migration that has been released — append a new one.
2. One logical change per changeset; changeset ids and file naming follow the project's existing pattern exactly.
3. Every changeset defines a rollback (or explicitly documents why rollback is impossible).
4. Naming: snake_case for tables/columns; table names singular or plural per existing schema — follow what's there; FK/index/constraint names follow the project's pattern (`fk_<child>_<parent>`, `idx_<table>_<cols>`, `uq_…`).
5. Every FK column gets an index unless the plan documents why not; add indexes for new query patterns identified in the plan.
6. Columns: explicit nullability; defaults for new NOT NULL columns on existing tables (add nullable → backfill → set NOT NULL for large tables); timestamps as UTC (`timestamptz`/equivalent); no floats for money.
7. Destructive operations (drop table/column, data deletion) require an explicit plan step and user approval — never bundled silently into a feature migration.
8. Large-table changes consider locking: batch backfills, concurrent index creation where the engine supports it.
9. Keep schema and code contracts in sync with the repository/entity plan — the cross-project contracts section of the high-level plan is authoritative.
10. Seed/reference data changes are migrations too, idempotent where the tool allows.
