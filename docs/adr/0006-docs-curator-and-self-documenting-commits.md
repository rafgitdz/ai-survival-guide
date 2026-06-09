# ADR-0006: Adopt docs-curator skill + pre-commit hook so every significant commit explains itself

- **Date**: 2026-06-09
- **Status**: Accepted
- **Deciders**: Backend team, Architecture

## Context

ADRs work only if they get written. In practice, they don't — the gap between "we made a decision" and "we wrote it down" is where architectural intent gets lost. The repo encodes many decisions implicitly (this very ADR file's existence is one), and without a forcing function, the next contributor inherits a system with no rationale.

We needed a workflow that:

1. Detects when a commit changes something architecturally significant (specs, AGENTS.md, Claude surface, deps, DB schema, lint config).
2. Refuses to let the commit through if no ADR or README update is staged with it.
3. Offers the contributor an automated way to draft the missing doc, rather than just blocking.

## Decision

Two artifacts, working as a pair:

- **`docs-curator` skill** (`.claude/skills/docs-curator/SKILL.md`): two modes. **Mode A** (diff-driven) reads `git diff --staged`, classifies the change, drafts the ADR + amends README, stages the result, stops. **Mode B** (codebase audit) inventories the repo, identifies decisions not yet documented, drafts retroactive ADRs, reconciles README drift.
- **`pre-commit-docs-check.sh` hook** (`.claude/hooks/`): matched on `Bash` calls that start with `git commit`. If staged files include any "significant" file but neither `docs/adr/*.md` nor `README.md`, exit 2 with a structured message telling Claude to invoke `docs-curator`. After the skill runs, the next commit retry passes.

ADR format is MADR-lite: Context, Decision, Consequences (split positive/negative/neutral), Alternatives considered, Links. Template at `docs/adr/0000-template.md`.

## Consequences

### Positive

- Every significant change ships with its rationale. The audit trail is complete by construction, not by discipline.
- The hook doesn't just block — it routes the agent to the right tool. The contributor gets a draft to edit, not a wall to climb.
- Mode B closes the loop for decisions made before the workflow existed (this ADR is the first product of that mode).

### Negative

- The "significant files" list lives in three places (skill, Claude hook, git hook). Drift breaks the workflow silently — see ADR-0004 Negative.
- Drafting an ADR for a one-line typo fix is overkill. The skill provides a `Status: Trivial` mode, but the temptation to skip is real.
- The Claude hook is blocking; a contributor under pressure can be funneled into agent flow they didn't plan to enter.

### Neutral

- The git hook (`.githooks/pre-commit`) intentionally only warns instead of blocking, to give humans an escape hatch. The asymmetry is documented in ADR-0004.

## Alternatives considered

- **CI-side check**: would catch the gap at PR time instead of commit time. Rejected because the drafting cost falls on the reviewer, not the author.
- **Manual `/curate-docs` slash command**: nothing forces the contributor to call it. Rejected — the whole point is the forcing function.
- **No tool, just discipline**: this is the status quo at most teams. Rejected — ADR-0001 cites the same kind of "discipline-only" gap that the openapi-generator was introduced to close.

## Links

- Skill: `.claude/skills/docs-curator/SKILL.md`
- Hook: `.claude/hooks/pre-commit-docs-check.sh`
- ADR template: `docs/adr/0000-template.md`
- Related: ADR-0004 (the hook layering pattern this fits into)
