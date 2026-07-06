# Java general rules

<!-- STARTER EXAMPLE — replace with your organization's real rules. -->

1. Target the project's configured Java version; never introduce syntax the build does not support.
2. Constructor injection only; no field `@Autowired`. Mark injected fields `private final`.
3. One public class per file; package structure follows feature, then layer (`feature/controller`, `feature/service`, …) — follow whatever the project already does.
4. No business logic in static utility classes when a service fits; utilities must be stateless and final with a private constructor.
5. Prefer immutability: `record` for value types and DTOs, `List.of`/unmodifiable collections in APIs.
6. `Optional` only as a return type; never as a field or parameter. Never return `null` for collections — return empty.
7. Exceptions: throw specific unchecked domain exceptions; never swallow exceptions; never log-and-rethrow (one or the other).
8. Logging via SLF4J with parameterized messages (`log.info("... {}", id)`); no `System.out`; never log secrets or full payloads containing personal data.
9. Nullability: annotate public APIs (`@Nullable`/`@NonNull` per project convention) and validate method arguments at boundaries.
10. Use the project's existing mapper approach (MapStruct, manual, …); do not introduce a new mapping library.
11. No new dependencies without an explicit plan step that names the artifact and the reason.
12. Follow existing formatting/checkstyle config; do not reformat untouched code.
13. Javadoc on public API of shared/library modules; internal code documents only the non-obvious.
14. Time handling: `java.time` only, UTC in persistence, explicit zone conversions at the edges.
