# Angular testing rules

<!-- STARTER EXAMPLE — replace with your organization's real rules. -->

1. Use the project's established runner (Jest/Karma/Vitest) and existing test utilities — check before writing the first test.
2. Component tests via `TestBed` render real templates; assert on rendered DOM and emitted outputs, not on private members or implementation details.
3. Query the DOM by role/test-id per project convention (`data-testid`), not by CSS classes that exist for styling.
4. Services with HTTP: test with `HttpTestingController`/`provideHttpClientTesting` — assert request method, URL, body, and response handling including error paths; `verify()` no outstanding requests.
5. Mock at the injection boundary: provide stub services via DI; never patch imports or spy on the class under test.
6. Cover per component: renders with expected inputs, user interactions (click/type) produce expected outputs/state, conditional rendering branches, error/empty/loading states.
7. Async: use `fakeAsync`/`tick` or observable test helpers; no real timers, no arbitrary `setTimeout` waits.
8. Forms: test validation states and submit behavior through DOM interaction, not by calling internal methods.
9. One behavior per spec; `describe` blocks mirror the public behavior, names read as sentences.
10. Shared fixtures/builders for models; no duplicated hand-built objects across specs.
