---
name: docs-curator
description: Curate documentation in two modes. MODE A (diff-driven, default — auto-triggered by the pre-commit hook) reads the staged diff, drafts an ADR for the change, amends the relevant README section. MODE B (codebase audit, manual) scans the whole repo for architectural decisions not yet captured by an ADR, drafts the missing ones, and reconciles the README against the actual state of the codebase. Never decides alone whether a change is trivial — if in doubt, ALWAYS draft at least a minor ADR rather than skipping.
---

# docs-curator

## When to use

### Mode A — diff-driven (default)

- **Auto-triggered** by the hook `pre-commit-docs-check.sh` when a commit touches a "significant" file but no `docs/adr/*.md` or `README.md` is staged. The hook returns exit 2 with a message asking Claude to invoke this skill.
- **On demand** for a pending commit: *"curate the docs for the pending commit"*.

### Mode B — codebase audit (manual, periodic)

- **Manual invocation** before a milestone, before a talk, or when README/ADRs feel out of date: *"invoke docs-curator in codebase audit mode"* / *"audit the docs against the current codebase"*.
- Periodic hygiene: run before a release to catch drift between code reality and what the docs claim.

In Mode B, the skill reads the **current state** of the repo (not a diff) and identifies architectural decisions made implicitly through code that aren't yet captured by an ADR — typically tooling choices, framework versions, conventions, plus drift between README claims and actual skills/agents/hooks/endpoints count.

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

## Workflow — Mode A (diff-driven)

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

## Workflow — Mode B (codebase audit)

**Trigger** : explicit user prompt mentioning "audit", "codebase audit mode", "reconcile docs". NO diff is read in this mode — the source of truth is the current state of the repo.

1. **Inventory the codebase** — produce a mental map of what's architecturally significant **right now** :
   - `.claude/skills/` → list each skill (name, one-line purpose from frontmatter).
   - `.claude/agents/` → list each subagent.
   - `.claude/hooks/` + `.claude/settings.json` → list each wired hook + the event/matcher it's bound to.
   - `.claude/commands/` → list each slash command.
   - `.mcp.json` → list each MCP server (name, command, purpose).
   - `openapi/*.yaml` → list each spec + the endpoints it exposes.
   - `pom.xml` → record Spring Boot version, Java version, key plugin choices (openapi-generator config, etc.).
   - `db/schema.sql` (or any DDL fixture) → record tables + non-obvious column conventions.
   - `.spectral.yml` → list the custom rules.
   - `.githooks/` → list each git hook + whether it mirrors a Claude hook.
   - `AGENTS.md` → list the numbered rules.

2. **Inventory existing ADRs** under `docs/adr/`. For each, record: number, title, what it justifies.

3. **Cross-reference** — for every significant element from step 1, ask : "is this decision documented by an existing ADR?" If NO, it's a candidate for a retroactive ADR. Examples of typical gaps :
   - The choice of Spring Boot version (3.5 vs 3.3 etc.).
   - The choice of OpenAPI Generator's `interfaceOnly` mode.
   - The choice of MADR template format (vs Y-statement, Nygard short, etc.).
   - The choice of Spectral as linter (vs Vacuum, Redocly).
   - The decision NOT to use Flyway (to avoid Spring autoconfig clash).
   - The decision to enforce JWT Bearer in AGENTS.md §4 (vs OAuth2, mTLS).
   - The decision to use a `deny`-list under `.claude/settings.json` for `prod-config/` and `secrets/`.
   - The decision to mirror Claude hooks with git hooks in `.githooks/` (defense in depth).
   - The existence of the `docs-curator` skill itself (meta-ADR).
   - Any rule in `AGENTS.md` not yet backed by an ADR.

4. **Draft the missing ADRs** — same MADR template, same drafting rules (see below). Number them continuously after the highest existing ADR. Status `Accepted` for already-implemented decisions.

5. **Reconcile the README** — read `README.md` and verify every claim against the inventory from step 1 :
   - The skill count matches `.claude/skills/` count.
   - The agent count matches `.claude/agents/` count.
   - The hook table lists every wired hook.
   - The "API" section lists every endpoint actually defined in `openapi/`.
   - The "Decisions" section links to every ADR under `docs/adr/`, newest first.
   - The Stack section reflects actual `pom.xml`.
   For each drift, amend the README. Do not rewrite the whole file.

6. **Stage everything** : `git add docs/adr/*.md README.md`.

7. **STOP** — output a single Markdown report (see "Output format" below). Do NOT commit. Let the human review the ADR titles before merging (they're retroactive — wording matters for the audit trail).

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

### Mode A (diff-driven)

```
## docs-curator — Mode A
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

### Mode B (codebase audit)

```
## docs-curator — Mode B (codebase audit)
Inventoried: 7 skills, 2 agents, 4 hooks, 4 MCP servers, 3 specs, 1 DB schema, 1 spectral ruleset.

Coverage gap detected — created retroactive ADRs:
- docs/adr/0002-pin-spring-boot-3.5.md         (deps choice)
- docs/adr/0003-openapi-generator-interface-only.md  (codegen mode)
- docs/adr/0004-no-flyway-by-design.md         (avoids Spring autoconfig at startup)
- docs/adr/0005-introduce-docs-curator-skill.md (meta-ADR)
- docs/adr/0006-spectral-as-spec-linter.md     (lint stack)

README drift fixed:
- "Skills & Agents" section listed 5 skills, actual count is 7 — added the 2 missing.
- "Hooks" table missing `pre-commit-docs-check.sh` row — added.
- "Decisions" section listed 1 ADR, actual count is now 6 — refreshed full list.
- "Stack" section said "Spring Boot 3.3.4", actual is "3.5.0" — corrected.

Staged: 5 new ADRs + README.md.

Next: human review of the ADR titles + commit. Recommended message:
  docs: retroactive ADRs (0002-0006) + README reconciliation (Mode B audit)
```

## Edge cases

### Mode A
- **Pure doc change** (only `README.md` or `docs/adr/**` staged) : the hook won't even invoke me. If somehow invoked, exit with `No action needed — only docs are staged`.
- **Commit needs no ADR** (typo fix in a comment) : you should still produce a **minimal** ADR (1-2 lines per section) tagged `Status: Trivial` rather than ask the hook to skip — keeps the cadence honest and the audit trail complete. The talk-friendly version is: *"every commit explains itself"*.
- **Diff too big** (more than 50 files) : do NOT try to summarize everything. Produce ONE ADR titled "Bulk refactor : <area>" with a link to the commit, and STOP. Add `TODO: split into atomic ADRs` in the Consequences.

### Mode B
- **Repo already fully documented** : output a one-line `No gaps detected. Inventory:  <counts>.` and STOP without creating any file.
- **Too many gaps** (more than 10 retroactive ADRs needed) : draft the top 5 most load-bearing ones (deps, codegen, lint, security model, hooks model) and list the rest as `TODO: ADR-needed` in a single `docs/adr/9999-audit-backlog.md`. Don't flood the repo in one pass.
- **README rewrite tension** : if drift is so large that surgical amendment isn't feasible, write the new README into `README.md.proposed` first and add a finding in the report — let the human decide to swap.
- **Conflicting ADRs** : if a retroactive ADR would contradict an existing one, do NOT overwrite. Flag the conflict in the report : "ADR-0003 would conflict with ADR-0001 — needs human reconciliation."
