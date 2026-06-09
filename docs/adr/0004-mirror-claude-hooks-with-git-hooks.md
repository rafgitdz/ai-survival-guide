# ADR-0004: Mirror Claude PreToolUse hooks with git hooks (defense in depth)

- **Date**: 2026-06-09
- **Status**: Accepted
- **Deciders**: Backend team

## Context

The repo uses Claude Code PreToolUse hooks (`.claude/hooks/pre-commit-openapi.sh`, `pre-commit-docs-check.sh`, `pre-merge-diff.sh`) to enforce spec lint + contract tests + docs hygiene whenever Claude is about to run `git commit` / `git merge`. These hooks only fire **when Claude is the one running the command** — a human running `git commit` in a terminal bypasses them entirely.

For a real team, that gap is unacceptable: the rules in AGENTS.md should hold regardless of who or what is committing.

## Decision

Maintain a parallel set of git hooks in `.githooks/` that re-implement the same checks. Wire them in by setting `git config core.hooksPath .githooks` once after clone. The two layers stay in sync by convention — both call the same `spectral` CLI and the same `./mvnw -Dtest='*ContractTest' test`.

The docs-check layer has a deliberate asymmetry:

- **Claude** path (`pre-commit-docs-check.sh`) is **blocking** (exit 2) — Claude must invoke `docs-curator` before retrying.
- **Human** path (`.githooks/pre-commit`) is **warn-only** — a human who knows what they're doing is not forced to drop into the agent loop.

## Consequences

### Positive

- The AGENTS.md rules hold whether the commit originates from Claude or from a human.
- Defense in depth: if one layer is misconfigured (e.g. hooks disabled), the other still fires.
- The asymmetry on docs-check matches the audience: agents need a hard stop to trigger the right tool; humans need a nudge, not a wall.

### Negative

- Two files to keep in sync. Any new rule must be added in both places.
- The "significant files" list lives in three places now: `.claude/hooks/pre-commit-docs-check.sh`, `.githooks/pre-commit`, and `.claude/skills/docs-curator/SKILL.md`. Drift between them silently breaks the workflow.

### Neutral

- New contributors must run `git config core.hooksPath .githooks` after clone. Documented in the demo prerequisites.

## Alternatives considered

- **Only Claude hooks**: leaves a humans-bypass-everything hole — rejected.
- **Only git hooks**: would lose the PreToolUse interception, which is what lets `docs-curator` auto-orchestrate on a blocked commit. Rejected — the agent UX is the demo's headline.
- **pre-commit framework (Python)**: a third toolchain in the repo. Rejected for footprint.

## Links

- Claude hooks: `.claude/hooks/pre-commit-openapi.sh`, `.claude/hooks/pre-commit-docs-check.sh`, `.claude/hooks/pre-merge-diff.sh`
- Git hooks: `.githooks/pre-commit`
- Activation: `git config core.hooksPath .githooks`
- Related: ADR-0003 (the lint these hooks call), ADR-0006 (the docs-check that they enforce)
