---
name: openapi-designer
description: Designs or extends an OpenAPI 3.1 spec that strictly follows the repository rules (kebab-case, /v1, JWT, RFC 7807, observability). Use whenever a new endpoint or resource must be created, or a product ticket must become an API contract. NEVER generates Java code: only the spec and its diff.
---

# openapi-designer

## When to use

- A ticket describes a new endpoint or a new resource.
- An agent must turn a business need into an OpenAPI contract **before** writing code.
- An existing spec must be extended (new operation, new field).

**Do not use** to: audit an existing spec (use `openapi-consistency-auditor`), compare two versions (use `breaking-change-detector`), check security (use `owasp-reviewer`).

## Rules to follow (short reminder)

Taken from `AGENTS.md`:

- `kebab-case` paths, plural for collections.
- `camelCase` properties.
- `/v1` versioning in the path.
- Global `securitySchemes.bearerAuth`, except for public endpoints.
- RFC 7807 errors (`application/problem+json`) **with examples**.
- Every mutation: `400, 401, 403, 404?, 409?, 422, 500`.
- No mass assignment: `id`, `status`, `createdAt`, `userId` never accepted as input.
- Observability: when touching a resource, check that `/actuator/prometheus` stays exposed.

## Workflow

1. **Read the ticket or request.** Extract: resource, expected operations, business constraints, identifier format.
2. **Read the existing spec** (`openapi/*.yaml`) to reuse components (`Problem`, `Money`, `Pagination`, etc.) and keep the style consistent.
3. **Inspect the data layer BEFORE drafting** (AGENTS.md §6). Scan **systematically**, even when the ticket does not mention it:
   - `db/schema.sql`, `db/migration/`, `src/main/resources/db/migration/` (Flyway/Liquibase).
   - Every `*Entity.java` and `*Repository.java` class (JPA).
   If a table related to the ticket's resource exists:
   - **Reconcile names** between ticket and database. On a mismatch (e.g. `amount` vs `amount_cents`, `currency` vs `currency_iso`), **STOP and ask the human**: *"do I expose the business name or the technical name?"*. Never decide alone.
   - **Reuse the types** (`UUID` to `format: uuid`, `TIMESTAMPTZ` to `format: date-time`, `BIGINT minor units` to `integer`).
   If the table does NOT exist but the ticket depends on it: **STOP**, propose a DDL alongside OR ask whether it exists elsewhere. **Never invent a schema.**
4. **Draft the spec**:
   - Plural `kebab-case` path.
   - Every operation: `summary`, camelCase `operationId`, `tags`, `security`, `parameters`, `requestBody` (when applicable), `responses`.
   - Every `4xx`/`5xx`: `$ref: '#/components/schemas/Problem'` + **a realistic `example` with `type`, `title`, `status`, `detail`, `instance`**.
   - Input schemas separate from output schemas (`PaymentCreateRequest` vs `Payment`) to block mass assignment.
5. **Mental Spectral lint**: no `additionalProperties: true` by default on requests, no empty descriptions, examples present.
6. **Produce**:
   - The updated YAML file.
   - A "Diff summary" block listing: added operations, added schemas, modified schemas.
   - A justified **Semver classification** (PATCH / MINOR / MAJOR) of the change.
7. **Stop here.** Do not generate Java code. The `pre-commit` hook runs Spectral and the contract tests.

## Expected output format

```
## Spec updated
<path to the yaml>

## Diff summary
- Added: POST /v1/payments
- Added schema: PaymentCreateRequest, Payment
- Reused: Problem, Money

## Semver
MINOR (new endpoint, no existing field broken)

## Automatic checklist
- [x] kebab-case
- [x] /v1
- [x] bearerAuth
- [x] 400/401/403/422/500 with examples
- [x] No mass-assignment fields in request schema
```
