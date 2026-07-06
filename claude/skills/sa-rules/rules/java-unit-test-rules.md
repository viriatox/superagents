# Java unit test rules

<!-- STARTER EXAMPLE — replace with your organization's real rules. -->

1. JUnit 5 + Mockito + AssertJ (or the project's established equivalents); no Spring context in unit tests — plain constructor instantiation with mocks.
2. Scope: services, mappers, utilities, domain logic. Controllers and repositories are covered by their own test types, not here.
3. Structure: Arrange–Act–Assert with a blank line between blocks; one behavior per test method.
4. Naming: `methodUnderTest_condition_expectedOutcome` (or the project's existing convention — follow what's there).
5. Mock only direct collaborators; never mock value objects, DTOs, or the class under test. No `@MockBean` (that is an integration-test tool).
6. Verify observable outcomes (return values, state, thrown exceptions) over interaction verification; `verify()` only when the interaction IS the contract (e.g. event published).
7. Test data via builders/object mothers shared in a test fixtures package; no copy-pasted 20-line setup blocks.
8. Cover: happy path, each business error path, boundary values, null/empty inputs for public methods.
9. Deterministic: fixed `Clock` injected for time, fixed seeds for randomness, no sleeps, no network, no filesystem.
10. Assert exception type AND relevant message/fields with `assertThatThrownBy`.
11. Keep tests independent: no shared mutable state between tests, no execution-order assumptions.
