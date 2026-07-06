# Java controller rules

<!-- STARTER EXAMPLE — replace with your organization's real rules. -->

1. Controllers are thin: HTTP concerns only (binding, validation trigger, status codes, headers). No business logic, no repository access — delegate to a service.
2. Request/response bodies are DTOs; never expose JPA entities in a controller signature.
3. Validate inputs with `@Valid` + Bean Validation annotations on the DTOs; validation error handling lives in the global exception handler, not in the controller.
4. One `@RestControllerAdvice` global exception handler per service; controllers contain no try/catch for business exceptions.
5. Explicit HTTP semantics: correct verb, correct status (`201` + `Location` on create, `204` on delete, `400` vs `404` vs `409` distinguished).
6. URL design: plural nouns, kebab-case, resource hierarchy (`/orders/{orderId}/items`); versioning follows the project's existing scheme.
7. Pagination for any list endpoint that can grow; use the project's established pagination contract.
8. Document endpoints with the project's OpenAPI conventions (annotations or generated spec) when the project uses them.
9. Security annotations (`@PreAuthorize` or equivalent) explicit per endpoint; never rely on defaults for new endpoints.
10. No blocking calls to other services directly from controllers; go through a service.
