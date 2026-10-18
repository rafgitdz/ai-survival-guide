---
name: breaking-change-detector
description: Compares two OpenAPI specs (before and after) and lists EVERY breaking change with its severity (MAJOR/MINOR/PATCH per the repository Semver rule). Use before any merge on a spec, on a PR that changes a .yaml in openapi/, or to decide the version bump. Does NOT propose a patch: it is a detector, not a fixer.
---

# breaking-change-detector

## When to use

- A PR changes a file in `openapi/`.
- The version bump is unclear (PATCH vs MINOR vs MAJOR).
- The `pre-merge` hook needs a diff report.

**Do not use** for: designing a new spec (use `openapi-designer`), security audit (use `owasp-reviewer`).

## Classification (from AGENTS.md §3)

| Change | Severity |
|---|---|
| Description, summary, tag or example changed | **PATCH** |
| New operation | **MINOR** |
| New **optional** field in a response or input | **MINOR** |
| New response code (e.g. adding a `429`) | **MINOR** |
| Operation removed | **MAJOR** |
| Field removed (request or response) | **MAJOR** |
| Field or operation renamed | **MAJOR** |
| Type changed (`integer` to `string`) | **MAJOR** |
| `optional` to `required` on an input field | **MAJOR** |
| `required` to `optional` on a **response** field | **MAJOR** (clients can no longer rely on it) |
| Enum value removed | **MAJOR** |
| Error format changed | **MAJOR** |
| Security scheme changed | **MAJOR** |
| Path changed (case included) | **MAJOR** |

## Workflow

1. **Load** both YAML files (`old`, `new`).
2. **Parse** each one into a canonical form: `paths × methods × {parameters, requestBody, responses}` + `components.schemas` + `components.securitySchemes`.
3. **Structural diff**:
   - Removed and added operations.
   - For each kept operation: parameters, requestBody, responses, security.
   - For each referenced schema: fields (presence, type, required, enum, format).
4. **Classify** each change with the table above.
5. **Decide**: **at least one MAJOR** means a mandatory major bump. Otherwise MINOR if at least one MINOR. Otherwise PATCH.
6. **Produce the report** (format below).
7. **Do not fix.** If the user asks for a patch, delegate to `openapi-designer`.

## Output format

```
## Breaking change report
old: openapi/payments-v1.yaml
new: openapi/payments-v2.yaml

### MAJOR (n)
- POST /v1/payments: request field `amount` renamed to `value` (rename = MAJOR)
- GET /v1/payments/{id}: response `Payment.currency` removed (removal = MAJOR)

### MINOR (n)
- GET /v1/payments: new optional query param `status`

### PATCH (n)
- (none)

### Verdict
Required version bump: **MAJOR** (v1 → v2)
Path versioning required: yes, must publish under /v2.
```
