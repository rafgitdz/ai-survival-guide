# ADR-0001: Adopt openapi-generator for contract-first DTOs

- **Date**: 2026-06-03
- **Status**: Accepted
- **Deciders**: Backend team, Architecture

## Context

`AGENTS.md §1` mandates contract-first: the OpenAPI spec is the source of truth, the Java code must conform to it. We considered two enforcement levels:

1. **Discipline-only**: developers (and AI agents) write Java DTOs / controllers by hand, and a CI check verifies they match the spec.
2. **Generation**: the spec drives code generation; the build fails if Java diverges.

Level 1 is what we had until now. It depends entirely on reviewers catching spec/code drift — and in practice, the demo audit identified at least one leak (`Payment.internalAccountId` returned by the controller but absent from the schema) that level 1 missed.

## Decision

Adopt `openapi-generator-maven-plugin` 7.10 in `interfaceOnly` mode on `openapi/payments.yaml`. Generated artifacts live under `target/generated-sources/openapi/com/franceapi/demo/generated/{api,dto}`. Controllers (`PaymentController`, `PaymentMethodController`) **implement** the generated API interfaces.

Spring Boot 3.5, Java 21, `useJakartaEe=true`, `useSpringBoot3=true`.

## Consequences

### Positive

- Spec/code drift becomes a **compile error**, not a review finding.
- The `internalAccountId` leak vulnerability described in the security audit is structurally prevented — the generator does not create a field absent from the schema.
- Generated DTOs carry validation annotations from the spec automatically (`@NotNull`, `@Pattern`, etc.).

### Negative

- One more moving part in the build (generator version pin, occasional template surprises).
- `target/generated-sources/` is invisible to IDE indexing until Maven runs once.
- Some planted vulnerabilities (e.g. mass assignment) now live in the spec — the fix requires editing the YAML, not the Java. This is the intended pedagogy but represents a workflow change for Java-first developers.

### Neutral

- The hand-written DTOs (`Payment.java`, `PaymentCreateRequest.java`) have been removed.
- `additionalProperties: true` in a request schema produces a `Map<String, Object>` overflow field in the generated DTO — explicit, visible, easy to audit.

## Alternatives considered

- **Redocly CLI generator**: comparable, but less mature on Spring Boot 3.x. Rejected for tool maturity.
- **OpenAPI-first with custom Maven plugin**: too much glue code for the demo. Rejected for cost.
- **Stay discipline-only**: rejected — see Context, the leak escaped review.

## Links

- Commit: `<initial scaffold>`
- Generated package: `com.franceapi.demo.generated.api`, `com.franceapi.demo.generated.dto`
- Spec under contract: `openapi/payments.yaml`
- External: [openapi-generator Spring docs](https://openapi-generator.tech/docs/generators/spring/)
