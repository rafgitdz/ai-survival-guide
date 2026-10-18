<!--
  AGENTS.md: universal rules for this repository.
  Loaded automatically by Claude Code (and by any tool that supports AGENTS.md).
  Every code generation, every agent proposal and every review MUST follow these rules.
  If a rule conflicts with a user request, the agent must say so before acting.
-->

# Rules: contract-first payments API (Spring Boot + OpenAPI)

## 1. Stack and style

- **Stack**: Spring Boot 3.x, Java 21, OpenAPI 3.1, Maven.
- **API style**: REST, **contract-first**. The OpenAPI spec is the source of truth; Java code is generated from it or validated against it. Never code first.

## 2. Naming conventions

- **Paths**: `kebab-case`, **plural** for collections.
  - ✅ `/payment-methods`, `/invoices/{invoiceId}/line-items`
  - ❌ `/PaymentMethod`, `/invoice/{id}/lineItem`
- **JSON properties**: `camelCase`.
  - ✅ `customerId`, `createdAt`
  - ❌ `customer_id`, `CreatedAt`
- **Enums**: `SCREAMING_SNAKE_CASE` values (`PAYMENT_PENDING`).

## 3. Versioning

- **`/v1`, `/v2`, ...** in the path. No version header.
- **Strict semver** on the spec:
  - PATCH: docs, examples, descriptions.
  - MINOR: new endpoint, new optional field.
  - MAJOR: **any** removal, rename, type change, requirement change (optional to required), enum change or error format change.
- **No breaking change ships without a major bump** AND an entry in `CHANGELOG.md`.

## 4. Authentication

- **JWT Bearer** (`Authorization: Bearer ...`), validated server-side (signature + `exp` + `iss` + `aud`).
- Spec: `securitySchemes.bearerAuth` must be declared and applied by default to every operation, except public endpoints explicitly annotated with `security: []`.

## 5. Errors

- **RFC 7807** (`application/problem+json`), strictly.
- Every operation **MUST** declare its relevant 4xx/5xx responses with the **`Problem` schema and a realistic example**.
- Minimum codes to consider for any mutation: `400`, `401`, `403`, `404` (if a resource is addressed), `409` (if a conflict is possible), `422` (business validation), `500`.
- Never `200 OK` on a business error. Never a custom error body outside RFC 7807.

## 6. Contract honesty

- **Never invent a field.** If a field appears in a response, it MUST be in the schema.
- **Never assume a database schema.** Before modeling a DTO, read the actual migration, JPA entity or SQL schema.
- No mass assignment: input DTOs expose only the fields the client may change. `id`, `status`, `createdAt`, `userId` (when derived from the JWT), etc. are **never** accepted as direct input.

## 7. Observability (non-negotiable)

Every exposed API MUST ship with:

- **Prometheus metrics**: `/actuator/prometheus` exposed, `http_server_requests_seconds` enabled through Micrometer.
- **Distributed tracing**: W3C `traceparent` propagation, OTLP or Zipkin export configured.
- **Structured logs**: JSON, with at least `timestamp`, `level`, `traceId`, `spanId`, `service`, `message`. Never log PII or secrets.

## 8. Security: mandatory guardrails

- No plaintext secret in the repository (see the `secret-scrubber` skill).
- Systematic input validation (Bean Validation, `@Valid`).
- OWASP API Security Top 10 audited before every release (see the `security-audit-agent` agent).
- Rate limiting documented in the spec (`X-RateLimit-*` headers).

## 9. Expected agent workflow

1. Read the relevant OpenAPI spec before proposing any code change.
2. When adding or changing an endpoint: **update the spec first**, then the code, then the tests.
3. Always produce the spec diff when the spec changes.
4. Every PR must pass: `spectral lint`, contract tests, OWASP review, observability check.
