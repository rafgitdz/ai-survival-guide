# Changelog

All notable changes to the FranceAPI Payments contract are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
as enforced by AGENTS.md §3.

## [2.0.0] - 2026-06-08

### BREAKING

- `Payment.amount` renamed to `Payment.value` (response).
- `Payment.currency` tightened to enum `[EUR, USD, GBP]` (response) — was free
  `string` with pattern `^[A-Z]{3}$`.
- `Payment.createdAt` removed (response).
- `Payment.createdAt` no longer present in `required[]` (response).
- Resource now served under `/v2/payments` (was `/v1/payments`).

### Added

- Optional query param `status` on `GET /v2/payments`.
- Optional `code` field on `Problem` schema (stable machine-readable error code).

### Migration

- Clients on v1 must migrate before Sunset date **2026-12-08**.
- Replace `amount` with `value` in deserializers.
- Restrict accepted `currency` values to `EUR`, `USD`, `GBP`.
- Stop relying on `createdAt` from the payment response.
- Update base path from `/v1/payments` to `/v2/payments`.

## [1.3.0] - 2026-06-08

### Deprecated

- All `/v1/payments` operations marked `deprecated: true`; Sunset **2026-12-08**;
  successor `/v2/payments`. Responses now expose `Deprecation` (RFC 9745),
  `Sunset` (RFC 8594) and `Link` (RFC 8288, `rel="successor-version"`) headers.

## [1.2.0] - 2026-05-15

### Added

- Initial public release of `/v1/payments` (listPayments, getPayment).
