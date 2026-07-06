# Rules manifest

Single source of truth mapping work to rule files. Agents load ONLY files matched here.

Tags name the technology that is actually present — match them against what exploration found, not against generic role words. A vanilla-JS frontend with no Angular matches no row, and that is correct: loading no rules beats loading wrong-framework rules and marking everything N/A.

## Rules index

| tags | file |
|---|---|
| java | java-general-rules.md |
| java, controller, rest, api, endpoint | java-controller-rules.md |
| java, service, business-logic | java-service-rules.md |
| java, repository, persistence, jpa, entity | java-repository-rules.md |
| java, test, unit | java-unit-test-rules.md |
| java, test, repository, persistence | java-repository-test-rules.md |
| java, test, integration, e2e | java-integration-test-rules.md |
| angular, typescript, component | angular-general-rules.md |
| angular, test | angular-testing-rules.md |
| database, sql, migration, liquibase, schema | database-rules.md |
| automation, e2e, playwright, api-test | automation-test-rules.md |

## Test waves

Waves run in ascending order. A wave applies when its trigger matches the change scope (`test/change-scope.txt`). Same-number waves for disjoint technologies are still executed as separate delegations.

| wave | test type | rules file | applies when changes touch |
|---|---|---|---|
| 1 | java-unit | java-unit-test-rules.md | any Java production code |
| 1 | angular-unit | angular-testing-rules.md | any Angular code |
| 2 | java-repository | java-repository-test-rules.md | actual persistence infrastructure: repository classes, ORM/JPA entities, database queries, schema migrations (an in-memory domain record/collection is NOT persistence) |
| 3 | java-integration | java-integration-test-rules.md | controllers, services, cross-component or cross-service flows |

## Automation testing (AUTOTEST phase)

The optional AUTOTEST phase is enabled by the presence of a Rules index row tagged `automation`. That rules file configures everything the phase needs: where the automation project lives, which surfaces may be automated (e.g. direct API calls to a gateway, frontend UI flows), conventions, the static check command, and the (optional) execution command with its environment prerequisites. Remove the row to disable the phase; add more `automation`-tagged files to extend it.
