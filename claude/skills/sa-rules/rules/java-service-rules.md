# Java service rules

<!-- STARTER EXAMPLE — replace with your organization's real rules. -->

1. Business logic lives in services — nowhere else (not controllers, not repositories, not entities beyond simple invariants).
2. Services depend on repositories, other services, and clients — never on controllers or web-layer types (`HttpServletRequest`, DTO validation annotations, etc.).
3. Transactions: `@Transactional` at the service method that forms the unit of work; `readOnly = true` for queries; never on controller or repository level; keep transactions short — no remote calls inside a transaction unless explicitly planned.
4. Entity ↔ DTO mapping happens at the service boundary (or dedicated mapper); entities do not leave the service layer.
5. Throw domain-specific exceptions (`OrderNotFoundException`), not generic ones; the web layer translates them to HTTP.
6. Idempotency: state-changing operations exposed to retries must be explicitly idempotent or guarded.
7. No hidden side effects: a method named `get*`/`find*` must not mutate state.
8. External calls (HTTP clients, messaging) go through dedicated client/gateway classes with timeouts configured; services never build raw HTTP calls inline.
9. Guard clauses over deep nesting; fail fast on invalid arguments.
10. Concurrency-sensitive updates use optimistic locking or explicit locking per the project's convention — never assume single-writer.
