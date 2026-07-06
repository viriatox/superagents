# Automation test rules (Playwright example)

<!-- STARTER EXAMPLE — replace with your organization's real rules.
     This file also CONFIGURES the AUTOTEST phase: its `automation` tag in the manifest enables
     the phase, and the sections below tell the agents where the automation project lives,
     what may be automated, and which commands to use. Nothing about automation is hardcoded
     in the workflow — it all comes from here. -->

## Automation project

1. Automation tests live in the dedicated Playwright project at `e2e/` (example — point this at your real automation project; it may also be a separate repository, in which case state its path).
2. Static check (no running environment needed): `npx playwright test --list` from the automation project root, plus `npx tsc --noEmit` if the project has a tsconfig. This is the verification used at implementation time.
3. Run command: `npx playwright test` from the automation project root. **Execution is optional** — it requires the environment prerequisites below and explicit user confirmation; never execute during implementation.

## What to automate

4. API scenarios: direct HTTP calls to the gateway project's public endpoints using Playwright's `request` context — assert status codes, response body contracts, and error shapes.
5. UI scenarios: frontend user flows for the screens changed by the task — happy path plus the main error path per acceptance criterion.
6. Automate acceptance criteria, not implementation details: every spec maps to at least one AC from the refinement; anything without an AC needs a stated reason in the plan.

## Conventions

7. Page objects for UI under `e2e/pages/`; API clients and fixtures under `e2e/fixtures/` — reuse existing ones before creating new ones.
8. Spec naming: `<feature>.<surface>.spec.ts` (surface = `api` | `ui`); tag tests `@api` / `@ui` so surfaces can run separately.
9. Tests are independent and repeatable: each creates its own data through API/fixtures and cleans up after itself; no dependence on execution order or leftover state.
10. No sleeps or fixed timeouts — use web-first assertions and explicit waits; enable trace and screenshot on failure in the shared config.
11. Selectors target user-facing roles or `data-testid`s, never styling classes or DOM structure.
12. Base URLs, credentials, and secrets come from environment config (`.env` / CI variables) — never hardcoded in specs.

## Environment prerequisites (for optional execution)

13. Gateway, frontend, and database reachable in the target environment, with base URLs supplied via env config and seeded reference data as declared by the fixtures. If any of this is missing, the suite is implemented but not executed (`executed: no` in the report).
14. **Environment lifecycle — the executing side owns the environment for the run.** The environment may comprise ANY number of services (frontends, multiple backends, gateways); the autotest plan's environment section enumerates them all, each with its base URL and local start command (taken from the target repository's own run documentation, e.g. its README). Before running the suite, probe every listed base URL. For each service that is not reachable and can be run locally, start it, wait until it responds, and stop every process you started once the run ends (and only those). Only services that genuinely cannot be started locally (external gateway, shared database) fall back to rule 13 / a BLOCKED reply naming exactly what the user must start. Never report a RED run because the environment was unreachable — an unreachable environment is a BLOCKED/`executed: no` outcome, not a test failure. Which agent performs the lifecycle is defined by the workflow per variant (hybrid: the orchestrator itself; opencode variants: sa-verifier).
