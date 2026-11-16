# Changelog

All notable changes to the public API contracts under `openapi/` are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
versions follow the strict Semver rule of `AGENTS.md §3`.

## [2.0.0] - 2026-11-30

Spec: `openapi/payments-v2.yaml`. Served under `/v2`, alongside the deprecated `/v1`.
Ticket: API-1302. Decision record: ADR-0007.

### Breaking

- `Payment.amount` renamed to `Payment.value` (integer, minor units, still required).
- `Payment.currency` restricted to the enum `EUR`, `USD`, `GBP` (was any 3-letter uppercase code, `^[A-Z]{3}$`).
- `Problem` gains an optional `code` member (stable machine-readable error code). Additive, but classified as an
  error format change, hence MAJOR per `AGENTS.md §3`.
- Base path moved from `/v1` to `/v2`. The `/v1` paths keep being served until the v1 sunset (see [1.3.0]).

### Added

- `GET /v2/payments`: optional `status` query filter (`PENDING`, `AUTHORIZED`, `CAPTURED`, `REFUNDED`, `FAILED`).
- `400`, `403`, `429` and `500` responses declared on both operations, with RFC 7807 examples.
- `X-RateLimit-Limit` and `X-RateLimit-Remaining` headers on successful responses.

## [1.3.0] - 2026-11-30

Spec: `openapi/payments-v1.yaml`.

### Deprecated

- `GET /v1/payments` and `GET /v1/payments/{paymentId}` are deprecated in favour of `/v2`.
  Responses carry `Deprecation: @1795996800` (RFC 9745, 2026-11-30T00:00:00Z),
  `Sunset: Mon, 31 May 2027 00:00:00 GMT` (RFC 8594) and a `Link` header with `rel="successor-version"`.
  `/v1` stops being served on 2027-05-31.

## [1.2.0]

- Version in production before this changelog was started. No entry recorded.
