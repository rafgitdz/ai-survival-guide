# ADR-0007: Publish Payments API v2 alongside a deprecated v1

- **Date**: 2026-11-15
- **Status**: Accepted
- **Deciders**: Backend team, Product (ticket API-1302)

## Context

The candidate `openapi/payments-v2.yaml` was submitted as `1.3.0` under the `/v1` paths. The
`breaking-change-detector` comparison against production (`openapi/payments-v1.yaml`, 1.2.0) found three
breaking changes: `Payment.amount` renamed to `value`, `Payment.currency` narrowed from a pattern to the enum
`EUR`/`USD`/`GBP`, and a new `Problem.code` member (an error format change, MAJOR under `AGENTS.md §3`). The
candidate also dropped `Payment.createdAt`; this was confirmed as a mistake and the field was restored, so it is
not part of this decision. Two partner integrations consume the v1 contract.

## Decision

Publish the candidate as `2.0.0` under `/v2`, keep `/v1` served as `1.3.0` with `deprecated: true` and the
`Deprecation` (RFC 9745), `Sunset` (RFC 8594) and `Link: rel="successor-version"` headers. v2 goes live on
2026-11-30; v1 is sunset on 2027-05-31 (T0 + 6 months).

## Consequences

### Positive

- The partner integrations keep working unchanged until the sunset; the migration is opt-in and dated.
- The version number and the base path now match the Semver verdict, so `pre-merge-diff.sh` and reviewers see a
  coherent major bump with a `CHANGELOG.md` entry.
- The v2 spec closes the consistency debt of v1: RFC 7807 examples, `403`/`429`/`500`, rate-limit headers.

### Negative

- Two API versions must be run, monitored and secured in parallel for six months.
- The `amount` to `value` rename moves the API name further from the `amount_cents` column; the mapping now lives
  in code only.
- The currency enum cannot represent payments stored in other currencies (`currency_iso CHAR(3)` is
  unconstrained). Production data was confirmed by the product owner, not by a query.

### Neutral

- Java code, build and contract tests for `/v2` are out of scope (follow-up ticket). Only
  `openapi/payments.yaml` feeds `openapi-generator`, so this change does not alter the running service.
- v1 stays frozen apart from the deprecation markers.

## Alternatives considered

- **Drop-in 1.3.0 under `/v1`, reverting the breaking changes**: zero consumer migration. Rejected because the
  product owner confirmed the `value` rename, the currency enum and `Problem.code` as intended.
- **Ship the candidate as-is (1.3.0 under `/v1`)**: rejected, it violates `AGENTS.md §3` and breaks both partners
  without notice.
- **Version through a header instead of the path**: rejected, `AGENTS.md §3` mandates path versioning.

## Links

- Commit: see the commit introducing this file on branch `api-evolution/payments-v2`
- Ticket: `tickets/API-1302.md`
- Related ADRs: ADR-0001 (contract-first), ADR-0003 (Spectral)
- External: RFC 8594 (Sunset), RFC 9745 (Deprecation), RFC 8288 (Web Linking), RFC 7807 (Problem Details)
