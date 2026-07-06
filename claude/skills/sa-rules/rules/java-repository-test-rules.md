# Java repository test rules

<!-- STARTER EXAMPLE — replace with your organization's real rules. -->

1. Scope: repository interfaces, custom queries, entity mappings, and migrations' effect on persistence — tested against a real database.
2. Use `@DataJpaTest` sliced context; real database via Testcontainers matching production engine (no H2 for engine-specific SQL) — follow the project's existing setup.
3. Migrations (Liquibase/Flyway) run against the test database — schema comes from migrations, never from `ddl-auto`.
4. Never mock `EntityManager` or repository internals — the point is exercising real persistence.
5. Each test seeds its own data (builders + `TestEntityManager`/repository saves); no reliance on data from other tests; transaction rollback per test is the default isolation.
6. Test every custom `@Query` and every non-trivial derived query: matching rows, non-matching rows, and empty result.
7. Test pagination and sorting behavior for methods taking `Pageable`.
8. Assert constraint violations explicitly (uniqueness, nullability, FK) where the entity relies on them.
9. Flush before asserting when the bug class is mapping-related (`saveAndFlush`, `flush()`); lazy-loading assertions state their session boundary explicitly.
10. Keep these tests focused on persistence semantics — business logic assertions belong to unit tests.
