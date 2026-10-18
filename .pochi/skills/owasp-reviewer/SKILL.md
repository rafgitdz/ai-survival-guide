---
name: owasp-reviewer
description: Audits an OpenAPI spec AND the related Spring Boot code against the OWASP API Security Top 10 (2023 edition). For each vulnerability found, outputs severity (CRITICAL/HIGH/MEDIUM/LOW), precise location (file:line or path+method), evidence and a suggested patch. Use before every release or on an explicit security audit request.
---

# owasp-reviewer

## When to use

- Explicit request for a "security audit", "OWASP check" or "security review".
- Invoked by `security-audit-agent`.
- Before a merge to `main` that touches an exposed route.

**Do not use** for: secret detection (use `secret-scrubber`), spec consistency (use `openapi-consistency-auditor`).

## Reference: OWASP API Security Top 10 (2023)

| # | Code | Short name | What to look for |
|---|---|---|---|
| 1 | API1 | Broken Object Level Authorization (BOLA) | An `/things/{id}` endpoint that does not check the object belongs to the caller. |
| 2 | API2 | Broken Authentication | JWT without `exp`/`iss`/`aud` checks, sensitive endpoints without `security`. |
| 3 | API3 | Broken Object Property Level Authorization | Mass assignment, exposure of internal fields (`internalAccountId`, `isAdmin`). |
| 4 | API4 | Unrestricted Resource Consumption | No pagination, no rate limit, no maximum requestBody size. |
| 5 | API5 | Broken Function Level Authorization | Admin routes without a role check. |
| 6 | API6 | Unrestricted Access to Sensitive Business Flows | No protection against replay (payment, signup). |
| 7 | API7 | Server Side Request Forgery (SSRF) | URL field in the input, fetched server-side without an allowlist. |
| 8 | API8 | Security Misconfiguration | CORS `*` with credentials, `additionalProperties: true` on input, missing security headers. |
| 9 | API9 | Improper Inventory Management | Endpoints missing from the spec, obsolete versions still exposed. |
| 10 | API10 | Unsafe Consumption of APIs | Outbound calls without schema validation. |

## Workflow

1. **Inventory**:
   - Every spec under `openapi/`.
   - Every `@RestController`, `@RequestMapping`, `@GetMapping`, etc. in `src/main/java`.
   - The Spring security configuration (`SecurityConfig` or `application.yml`).
2. **Reconcile**: compare spec routes with code routes (a mismatch is API9).
3. **For each endpoint**, run the 10 checks above.
4. **For each finding**:
   - Severity: `CRITICAL` (auth bypass, data leak, code execution), `HIGH` (BOLA, exploitable mass assignment), `MEDIUM` (DoS, misconfiguration), `LOW` (minor information disclosure).
   - Location: `openapi/payments.yaml#/paths/~1v1~1payments/post` OR `PaymentController.java:42`.
   - Evidence: 2 to 5 lines showing the problem.
   - Suggested fix: 1 to 3 lines (a diff or a precise instruction).
5. **Produce the report** in the format below.
6. **Do not apply the fixes**: that is the job of `security-audit-agent`, after human approval.

## Output format

```
## OWASP API Security audit
Scope: openapi/payments.yaml + src/main/java/com/franceapi/demo/**

### CRITICAL (n)
[API3] Mass assignment on POST /v1/payments
  Location: openapi/payments.yaml, PaymentCreateRequest
  Evidence: schema accepts `status` and `userId` from the client
  Fix: remove `status` and `userId` from PaymentCreateRequest; set status server-side; derive userId from JWT subject.

### HIGH (n)
...

### MEDIUM (n)
...

### LOW (n)
...

### Summary
CRITICAL: n   HIGH: n   MEDIUM: n   LOW: n
Release-blocking: yes/no (yes if CRITICAL > 0 or HIGH > 0)
```
