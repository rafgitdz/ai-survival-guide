---
name: docs-curator
description: Curate documentation around a pending commit — decide if the change deserves an ADR (Architecture Decision Record), draft it from the MADR template, and update the relevant section of README.md. Invoked when the pre-commit-docs-check hook detects a "significant" change without a matching doc update staged. Never decides alone whether a change is trivial — if in doubt, ALWAYS draft at least a minor ADR rather than skipping.
---

# docs-curator

## When to use

- **Triggered automatically** by the hook `pre-commit-docs-check.sh` when a commit touches a "significant" file but no `docs/adr/*.md` or `README.md` is staged. The hook returns exit 2 with a message asking Claude to invoke this skill.
- **On demand** : *"curate the docs for the pending commit"*.

**Do not use** for : changelog generation per release (different cadence), API client docs (auto-generated from OpenAPI).

## What counts as "significant"

The hook scopes this — but the skill must agree, so they stay in sync. A change is significant if it touches **any** of :

- `openapi/**.yaml` — public contract changed.
- `AGENTS.md` — rules changed.
- `.claude/agents/**`, `.claude/skills/**`, `.claude/hooks/**`, `.claude/commands/**` — AI surface changed.
- `.mcp.json` — external integrations changed.
- `pom.xml` — dependency / build changed.
- `db/**.sql` — data model changed.
- `.spectral.yml` — quality gate changed.

## Workflow

1. **Read the diff** : `git diff --staged` and `git diff --staged --name-only`.
2. **Read context** : `AGENTS.md` (for tone) + `docs/adr/0000-template.md` + the last 2-3 existing ADRs (for style alignment) + `README.md` (to see current structure).
3. **Classify the change** in ONE of these buckets :
   - **ADR-worthy** (always, when significant) : new endpoint, breaking change, dep change, new hook/skill/agent, new MCP server, new rule in AGENTS.md, schema migration.
   - **README-worthy** (often, when significant) : anything that changes how a developer **runs** or **reads** the repo : new endpoint surface, new slash command, new env var, new prerequisite.
   - **Both** (most common) : a feature that's both architectural AND user-visible.
4. **Generate / update files** :
   - **ADR** : create `docs/adr/NNNN-<short-kebab-slug>.md` (NNNN = next available number, zero-padded to 4 digits). Use the template at `docs/adr/0000-template.md`. Status defaults to `Accepted` (we don't gate the demo on a review workflow — adjust for prod use). Fill all sections, including `Alternatives considered` even if briefly.
   - **README** : amend only the relevant section. Do not rewrite the whole file. If a section doesn't exist yet, add it at the right spot (after `## Architecture` for decisions, after `## How to run` for usage, etc.).
5. **Stage what you produced** : `git add docs/adr/NNNN-*.md README.md`.
6. **STOP** — do not commit yourself. Output a short summary and let the parent agent / human run the commit. The hook will pass on the retry because the doc files are now staged.

## ADR drafting rules (do these, every time)

- **Title** : "ADR-NNNN: <verb> <noun>" (e.g. *"Adopt openapi-generator for contract-first DTOs"*). Active verb, not noun phrase.
- **Context** : 3-6 lines. Why we faced this decision. Mention the rule(s) of `AGENTS.md` at play if any.
- **Decision** : the chosen option, in 1-3 lines. Imperative voice.
- **Consequences** : split into "Positive" / "Negative" / "Neutral". 2-5 bullets each. Be honest about the negative — that's what makes ADRs useful 6 months later.
- **Alternatives considered** : at least one alternative, with the reason it was rejected.
- **Links** : commits, related ADRs, external references (RFC, blog, doc). At least one link to the commit being documented.

## README maintenance rules

- One H1 only (`# FranceAPI Demo`).
- Stable H2 sections : `Stack`, `Quickstart`, `Architecture`, `API`, `Skills & Agents`, `Hooks`, `Decisions`.
- The `Decisions` section is a **bullet list of ADR links**, newest first, with the one-line title. Generate this from `ls docs/adr/`.
- Never duplicate content from ADRs into README — link to them.

## Output format

```
## docs-curator
Diff classified: ADR-worthy + README-worthy

Created: docs/adr/0007-tighten-payment-create-request.md
Updated: README.md (sections: Decisions, API)
Staged: 2 files.

Summary:
- ADR documents the removal of `status`/`userId`/`internalAccountId` from the
  PaymentCreateRequest schema following the security audit.
- README "Decisions" list now references ADR-0007.

Next: retry the commit. The pre-commit-docs-check hook will pass.
```

## Edge cases

- **Pure doc change** (only `README.md` or `docs/adr/**` staged) : the hook won't even invoke me. If somehow invoked, exit with `No action needed — only docs are staged`.
- **Commit needs no ADR** (typo fix in a comment) : you should still produce a **minimal** ADR (1-2 lines per section) tagged `Status: Trivial` rather than ask the hook to skip — keeps the cadence honest and the audit trail complete. The talk-friendly version is: *"every commit explains itself"*.
- **Diff too big** (more than 50 files) : do NOT try to summarize everything. Produce ONE ADR titled "Bulk refactor : <area>" with a link to the commit, and STOP. Add `TODO: split into atomic ADRs` in the Consequences.
