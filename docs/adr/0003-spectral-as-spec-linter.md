# ADR-0003: Adopt Spectral as the OpenAPI linter, with a ruleset that mirrors AGENTS.md

- **Date**: 2026-06-09
- **Status**: Accepted
- **Deciders**: Backend team, Architecture

## Context

`AGENTS.md` defines hard rules on OpenAPI shape: kebab-case paths (§2), `/v{n}` versioning (§3), RFC 7807 error responses (§5), no `additionalProperties` on request bodies (§6). Without machine enforcement, these rules degrade to "review comments" — the demo's whole point is that contracts are enforced, not aspirational.

We need a linter that:

1. Runs in pre-commit (Claude `pre-commit-openapi.sh` and `.githooks/pre-commit`).
2. Lets us encode the AGENTS.md rules as failures, not warnings.
3. Has a stable CLI we can drop in any contributor's environment via `npm i -g`.

## Decision

Adopt [Spectral](https://github.com/stoplightio/spectral) as the linter. Ship `.spectral.yml` at the repo root with one custom rule per AGENTS.md numbered rule it can express in JSONPath:

- `paths-kebab-case` ← AGENTS.md §2
- `paths-must-be-versioned` ← AGENTS.md §3
- `error-responses-must-be-problem-json` ← AGENTS.md §5
- `request-bodies-no-additional-properties` ← AGENTS.md §6

All set to `severity: error` so pre-commit blocks. The pedagogical spec `openapi/payments.yaml` is **excluded** from the blocking lint — its baked-in defects are precisely what the live demo finds.

## Consequences

### Positive

- AGENTS.md violations become commit-blocking errors, not review comments.
- One rule file, one CLI, no Maven plugin to maintain.
- Rule descriptions cite the AGENTS.md section number — when Spectral fires, the contributor sees *why*.

### Negative

- Spectral is JavaScript-only; the build now has a Node toolchain dependency for the lint step, separate from Maven.
- The ruleset is necessarily incomplete: not every AGENTS.md rule can be expressed in JSONPath (e.g. §6 "never invent a field" needs a code-level check, not a spec lint).

### Neutral

- The exclusion of `openapi/payments.yaml` is encoded in both `.githooks/pre-commit` and `.claude/hooks/pre-commit-openapi.sh`. Keeping the two lists in sync is a maintenance task.

## Alternatives considered

- **Redocly CLI lint**: comparable rule engine, but Spectral's JSONPath model is closer to what the team already uses for ad-hoc spec greps. Rejected for marginal ergonomics.
- **Vacuum**: faster (Go), but younger ecosystem and smaller rule catalog. Worth revisiting if lint runtime becomes a bottleneck.
- **Custom Maven plugin**: would keep the toolchain in one language, but the cost of writing/maintaining lint rules outweighs the integration benefit for a demo.

## Links

- Config: `.spectral.yml`
- Invocation sites: `.githooks/pre-commit`, `.claude/hooks/pre-commit-openapi.sh`
- Related: ADR-0001 (the lint complements code generation — generation enforces shape, lint enforces style)
