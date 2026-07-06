# Angular general rules

<!-- STARTER EXAMPLE — replace with your organization's real rules. -->

1. Follow the project's Angular version and idioms — check before using standalone components, signals, or control-flow syntax (`@if`/`@for`); do not mix paradigms within a feature.
2. Components are presentation-focused: data access and business logic live in services; components orchestrate and render.
3. `ChangeDetectionStrategy.OnPush` for all new components (unless the project consistently does otherwise).
4. HTTP access only in dedicated services returning typed observables/signals; a typed model interface per API contract — never `any`.
5. Strict typing everywhere: no `any`, no non-null assertions to silence the compiler; model API responses exactly as the backend contract defines them.
6. Subscription hygiene: prefer `async` pipe / `toSignal`; manual subscriptions must be cleaned up (`takeUntilDestroyed` or project pattern).
7. Reactive (typed) forms for anything beyond a trivial input; validation messages centralized per project convention.
8. Routing: lazy-load feature areas; route params and data typed; guards for auth per project pattern.
9. State: use the project's established approach (signals store, NgRx, services) — do not introduce a new state library.
10. Templates stay logic-light: computed values in the component/service, not in template expressions; no function calls in templates that run per change detection unless memoized/signal-based.
11. Styling: component-scoped styles, project design tokens/variables; no hardcoded colors/sizes when tokens exist.
12. i18n: user-facing strings go through the project's translation mechanism if one exists.
