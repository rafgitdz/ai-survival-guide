# Changelog

All notable changes to the FranceAPI Payments contract are documented here.
Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows **Semver strict** as defined in `AGENTS.md` §3.

---

## [2.0.0] — 2026-06-03

**Published under `/v2`.** Spec file: `openapi/payments-v2.yaml`.

### Breaking changes (MAJOR)

- **`Payment.amount` renamed to `Payment.value`.** All consumers must update field reads.
- **`Payment.currency` restricted from free `string` (pattern `^[A-Z]{3}$`) to `enum [EUR, USD, GBP]`.** Any consumer or producer using another ISO 4217 code (e.g. `CHF`, `JPY`) is no longer accepted.
- **`Payment.createdAt` removed** (was `required` in v1). Consumers depending on this field must source it from another endpoint or accept its absence.

### Added (MINOR)

- New optional query parameter `status` on `GET /v2/payments` for filtering by lifecycle state (enum `[PENDING, AUTHORIZED, CAPTURED, REFUNDED, FAILED]`).
- New optional field `Problem.code` (stable machine-readable error code) on all error responses.

### Migration

| v1 (`/v1`)                  | v2 (`/v2`)                  | Notes                                |
|-----------------------------|-----------------------------|--------------------------------------|
| `Payment.amount`            | `Payment.value`             | Rename, same semantics (minor units) |
| `Payment.currency` (string) | `Payment.currency` (enum)   | Restricted to EUR / USD / GBP        |
| `Payment.createdAt`         | _(removed)_                 | No replacement in response payload   |

Path migration is mechanical: replace `/v1/payments` with `/v2/payments` in all calls.

---

## [1.2.0] — DEPRECATED

**Spec file**: `openapi/payments-v1.yaml`.
**Sunset date**: **2026-12-03** (6 months after the 2.0.0 release).

### Status

- Operations `GET /v1/payments` and `GET /v1/payments/{paymentId}` are marked `deprecated: true` in the spec.
- Responses will carry the following headers until sunset:
  - `Deprecation: true`
  - `Sunset: Thu, 03 Dec 2026 00:00:00 GMT` (RFC 8594)
  - `Link: </v2/payments>; rel="successor-version"`
- After **2026-12-03**, the `/v1` paths will return `410 Gone` with an RFC 7807 Problem pointing to `/v2`.

### Why a path bump (and not just `info.version`)

`AGENTS.md` §3 mandates path-based versioning (`/v1`, `/v2`, …) and explicitly forbids version headers. Because the changes above include three MAJOR diffs, publishing under `/v1` would silently break every existing consumer — hence `/v2`.
