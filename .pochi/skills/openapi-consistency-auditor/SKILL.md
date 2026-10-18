---
name: openapi-consistency-auditor
description: Audits an OpenAPI spec for internal consistency and compliance with the repository rules (naming, errors, documented fields, examples present, reused schemas). Outputs a list of inconsistencies with a precise fix for each. Use when inheriting a spec, preparing an audit, or alongside owasp-reviewer.
---

# openapi-consistency-auditor

## When to use

- At the start of an audit (DESIGN/EVOLVE/AUDIT use case).
- When a spec has been edited by many hands and the style is in doubt.
- As a pre-flight check before a release, to verify that the spec describes the real API.

**Do not use** for: OWASP security (use `owasp-reviewer`), breaking changes between two versions (use `breaking-change-detector`).

## Checks (grouped)

### Rule compliance (AGENTS.md)

- [ ] Every path is `kebab-case`, and plural for collections.
- [ ] Every property is `camelCase`.
- [ ] Every path starts with `/v{n}`.
- [ ] `securitySchemes.bearerAuth` is declared and applied globally or explicitly per operation; public endpoints have an explicit `security: []`.
- [ ] Every mutation declares at least `400, 401, 403, 422, 500`. Never `200` for an error.
- [ ] Every `4xx/5xx` response uses `application/problem+json` and `$ref` to `#/components/schemas/Problem`.
- [ ] Every `4xx/5xx` has a realistic `example` (not just `"string"`).

### Internal consistency

- [ ] Every `$ref` targets a schema that exists.
- [ ] No orphan schema in `components.schemas`.
- [ ] No `additionalProperties: true` in a requestBody.
- [ ] Input schemas differ from output schemas (to block mass assignment).
- [ ] Every field used in an `example` exists in the schema.
- [ ] Every field declared in the schema appears in **at least one** `example`.
- [ ] `enum` values are consistent between input and output.

### Documented observability

- [ ] The spec mentions `/actuator/prometheus` OR declares `tags`/`x-metrics` documenting the emitted metrics.
- [ ] Rate limits are declared (`X-RateLimit-Limit`, `X-RateLimit-Remaining` headers).

## Workflow

1. **Load** the YAML.
2. **Run** the checks above, in order.
3. **For each failure**, output one line: `[SEVERITY] <check_id> <location>: <evidence> → <fix>`.
   - Severity: `ERROR` (rule violated), `WARN` (style/consistency), `INFO` (suggestion).
4. **Count** per severity.
5. **Final output**: pass/fail verdict (fail if more than 0 ERROR).

## Output format

```
## OpenAPI consistency audit
File: openapi/payments.yaml

### ERROR (n)
- [naming] /v1/Payments: path is not kebab-case → rename to /v1/payments
- [errors] POST /v1/payments: response 200 declared for failure scenario "insufficient funds" → use 422 with Problem schema

### WARN (n)
- [examples] Payment schema: `createdAt` is declared but appears in no example → add a value in the GET response example

### INFO (n)
- [obs] No mention of /actuator/prometheus in the spec → consider documenting metrics tags

### Verdict
FAIL: 2 errors. Spec is not release-ready.
```
