# Java integration test rules

<!-- STARTER EXAMPLE — replace with your organization's real rules. -->

1. Scope: full request→response flows through the real Spring context — controller, service, repository, real database (Testcontainers), serialization, validation, error handling, security.
2. `@SpringBootTest` + `MockMvc`/`WebTestClient` per project convention; external third-party systems stubbed at the boundary (WireMock or the project's equivalent) — never the classes under test.
3. Exercise through the HTTP layer: real URLs, real JSON payloads, real status codes. Assert response body shape, not internal method calls.
4. Cover per new/changed endpoint: happy path, validation failure (400), not-found (404), conflict/business-rule rejection, and authorization denial where security applies.
5. Each test owns its data: seed via API or repositories in setup, isolate via rollback or per-test cleanup; tests must pass in any order and in parallel if the project runs them so.
6. Assert side effects that are part of the contract: persisted rows, published events/messages, outbound calls (via the stub).
7. Reuse a shared base class / test configuration for container wiring — do not redeclare containers per test class.
8. No sleeps: await asynchronous effects with Awaitility (or project equivalent) with explicit timeouts.
9. Keep the count proportionate: integration tests cover contracts and wiring; exhaustive branch coverage stays in unit tests.
10. Tag them (`@Tag("integration")` or project convention) so waves/CI can run them separately.
