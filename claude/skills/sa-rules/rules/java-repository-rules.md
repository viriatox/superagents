# Java repository rules

<!-- STARTER EXAMPLE — replace with your organization's real rules. -->

1. Repositories contain persistence only — no business logic, no mapping to DTOs.
2. Prefer derived query methods for simple cases; `@Query` (JPQL) for anything non-trivial; native SQL only with a stated reason in the plan.
3. Every query returning a list that can grow takes `Pageable` or an explicit limit.
4. Use projections (interface or record) for read models instead of loading full entities when only a few columns are needed.
5. Solve N+1 explicitly: `@EntityGraph` or fetch joins where the access pattern requires it — never `FetchType.EAGER` on associations as a fix.
6. Entities: no public setters where an invariant exists; equals/hashCode based on business key or id-with-care per project convention; no Lombok `@Data` on entities.
7. Associations are `LAZY` by default; bidirectional associations only when genuinely needed, with the owning side documented.
8. Modifying queries (`@Modifying`) state their flush/clear behavior explicitly.
9. Database constraints mirror code invariants (nullability, uniqueness) — the schema is the last line of defense; coordinate with the database plan.
10. Never catch persistence exceptions in the repository; let them translate/propagate.
