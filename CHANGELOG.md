# Changelog

All notable changes to the FranceAPI Payments spec are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html) per AGENTS.md §3.

---

## [2.0.0] — 2026-06-03

**MAJOR bump** — required by AGENTS.md §3: any removal, rename, type change, or constraint
narrowing mandates a major version increment and a new path prefix (`/v2`).
Published in parallel with `/v1` (Option B); `/v1` is now deprecated with sunset 2026-09-01.

### Breaking Changes

These changes are **incompatible** with clients built against `payments-v1.yaml`.
All are surfaced under the new path prefix `/v2/payments*`.

1. **`Payment.amount` removed** (`/v1` field, gone in `/v2`).
   - Impact: any client reading or mapping `amount` will get `undefined` / deserialization error.
   - Migration: replace all references to `amount` with `value` (same semantics, minor units).

2. **`Payment.amount` renamed to `Payment.value`** (required field).
   - Impact: JSON key change — clients must update field name in deserialization and display logic.
   - Migration: rename `amount` → `value` in your Payment DTO / model class.

3. **`Payment.currency` narrowed from free string to enum `[EUR, USD, GBP]`**.
   - Impact: any currency code outside this set will now fail validation (422). Clients that
     display or store the raw string value must handle the closed enum.
   - Migration: validate that stored/transmitted currency values are in `{EUR, USD, GBP}`.
     Contact the API team to request additional currencies before going live.

4. **`Payment.createdAt` removed**.
   - Impact: clients reading `createdAt` for display or ordering will receive no value.
   - Migration: use your own request timestamp or rely on a separate audit-log endpoint
     (to be published in a future ticket).

### Added

- `Problem.code` — optional, stable machine-readable error code string added to the RFC 7807
  Problem schema. Allows programmatic error handling without parsing `detail`. Non-breaking
  (optional field, additive).
- `GET /v2/payments` — new optional query parameter `?status` (enum: `PENDING`, `AUTHORIZED`,
  `CAPTURED`, `REFUNDED`, `FAILED`) for server-side filtering. Non-breaking (optional add).

### Deprecated

- `GET /v1/payments` — deprecated as of 2026-06-03, sunset **2026-09-01**.
  Every response carries `Deprecation: true`, `Sunset: Sun, 01 Sep 2026 00:00:00 GMT`,
  and `Link: </v2/payments>; rel="successor-version"` headers.
- `GET /v1/payments/{paymentId}` — same sunset policy.
  After 2026-09-01 both endpoints will return `410 Gone`.

### Migration Guide

1. Update the base path in your HTTP client from `/v1/payments` to `/v2/payments`.
2. Rename `payment.amount` → `payment.value` everywhere (DTO fields, JSON mappings, tests).
3. Drop any code that reads `payment.createdAt`; substitute a client-side timestamp if needed.
4. Ensure all `currency` values you send are in `{EUR, USD, GBP}`; add validation on your side.
5. Optionally consume `Problem.code` for programmatic error handling instead of matching on
   `detail` strings.

---

<!-- Add older versions below this line -->
