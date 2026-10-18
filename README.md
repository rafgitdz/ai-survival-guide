<div align="center">

# Your AI survival guide in software development

**A contract-first Spring Boot API where AI agents design, evolve, secure and audit, under rules they cannot bypass.**<br>
The live demo of the talk given at Devoxx Belgium, France API and DevQuest.

[![CI](https://github.com/rafgitdz/ai-survival-guide/actions/workflows/ci.yml/badge.svg)](https://github.com/rafgitdz/ai-survival-guide/actions/workflows/ci.yml)
![Java 21](https://img.shields.io/badge/Java-21-orange)
![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.5-6db33f)
![OpenAPI](https://img.shields.io/badge/OpenAPI-3.1-6ba539)
![Claude Code](https://img.shields.io/badge/Claude%20Code-skills%20%C2%B7%20agents%20%C2%B7%20hooks%20%C2%B7%20MCP-d97757)
![license](https://img.shields.io/badge/license-MIT-green)

[Why](#why) · [Quick start](#quick-start) · [The four demos](#the-four-demos) · [How it is wired](#how-it-is-wired) · [Watch the talk](#the-talk) · [Book this talk](#book-this-talk)

</div>

---

## Why

AI coding tools produce code fast. Very little of it is code you can defend in
production. The talk argues for a method before the tools: **vocabulary first,
then configure, produce and control.** This repository is that method applied
to a real API:

- **Rules the agent reads**: [`AGENTS.md`](./AGENTS.md) states naming, versioning, errors, security and observability rules once.
- **Skills that do one job**: seven narrow skills (design, consistency, breaking changes, OWASP, secrets, observability, docs).
- **Agents that plan before they act**: two subagents that stop at the plan and wait for a human decision.
- **Hooks that enforce instead of hoping**: the agent cannot commit a broken spec, read a secret, or skip documentation.
- **A contract the compiler enforces**: Java interfaces and DTOs are generated from the OpenAPI spec, so spec/code drift is a build error.

> [!IMPORTANT]
> The application is **deliberately vulnerable**. `openapi/payments.yaml` and
> the controllers contain planted defects (mass assignment, BOLA, 200 on error,
> missing tracing) for the agents to find. `prod-config/` and `secrets/` hold
> fictitious honeypot values. Do not reuse this code as a template.

## Quick start

```bash
git clone https://github.com/rafgitdz/ai-survival-guide.git
cd ai-survival-guide

git config core.hooksPath .githooks         # human-side hooks
npm install -g @stoplight/spectral-cli      # spec linter used by the hooks
./mvnw -q clean test                        # generates the API from the spec, runs the contract tests

claude                                      # start Claude Code in the repo
```

Inside Claude Code, `/agents` shows the 2 subagents, `/skills` the 7 skills,
`/hooks` the 5 hooks and `/mcp` the 4 MCP servers.

## The four demos

The full script, with the prompts to paste and the checklist of what must
happen, is in [`DEMO-CHECKLIST.md`](./DEMO-CHECKLIST.md).

| # | Use case | Driven by | The moment that matters |
|---|---|---|---|
| 1 | **DESIGN** a refunds endpoint from a ticket | `openapi-designer` | The database disagrees with the ticket: the agent **stops and asks** instead of inventing |
| 2 | **EVOLVE** the payments API to v2 | `api-evolution-agent` + `breaking-change-detector` | The agent catches a MAJOR change published under `/v1`, then stops at the plan |
| 3 | **SECURE** the API | `security-audit-agent` + `owasp-reviewer` + `secret-scrubber` | OWASP API Top 10 findings with severity and fix; reading `prod-config/` fails |
| 4 | **AUDIT** consistency and observability | `openapi-consistency-auditor` + `obs-readiness-checker` | Metrics pass, tracing and structured logs fail, with the exact fix |
| + | **Self-documenting commits** | `docs-curator` + pre-commit hook | The hook blocks a commit without an ADR, and the agent writes the ADR itself |

A reference output for use case 1 is kept in
[`examples/design-output/`](./examples/design-output/), outside `db/`, so the
starting state of the demo stays intact. CI fails if the planted traps disappear.

## How it is wired

### Contract-first, enforced by the build

`openapi/payments.yaml` drives `openapi-generator-maven-plugin` in
`interfaceOnly` mode. Controllers implement the generated interfaces, so a spec
change that the code does not follow fails compilation, not a code review. See
[ADR-0001](./docs/adr/0001-contract-first-with-openapi-generator.md).

| Spec | Version | Role |
|---|---|---|
| `payments.yaml` | 1.0.0 | Source of the generated code. Contains the planted defects for the SECURE and AUDIT demos; excluded from the blocking lint |
| `payments-v1.yaml` | 1.2.0 | Compliant baseline for the EVOLVE demo |
| `payments-v2.yaml` | 1.3.0 (should be 2.0.0) | Candidate next version with three planted breaking changes |

### Skills (`.claude/skills/`)

| Skill | Purpose |
|---|---|
| `openapi-designer` | Draft or extend an OpenAPI 3.1 spec that follows AGENTS.md. Never generates Java |
| `openapi-consistency-auditor` | Audit a spec for internal consistency and rule compliance |
| `breaking-change-detector` | Diff two specs and classify each change as MAJOR, MINOR or PATCH. Detects, never patches |
| `owasp-reviewer` | Audit spec and code against the OWASP API Security Top 10 (2023) |
| `obs-readiness-checker` | Check Prometheus metrics, distributed tracing and structured logs |
| `secret-scrubber` | Detect secrets and mask them before any output leaves the repository |
| `docs-curator` | Draft ADRs and amend the README, from a staged diff or from a codebase audit |

### Agents (`.claude/agents/`)

| Agent | Trigger | Purpose |
|---|---|---|
| `api-evolution-agent` | `/evolve <ticket-id>` | Plan then execute: spec first, code second, tests third, PR last |
| `security-audit-agent` | `/audit [spec]` | Orchestrate four skills into one consolidated, severity-ranked report |

### Hooks (`.claude/settings.json`)

| Hook | Event | Role |
|---|---|---|
| `pre-commit-openapi.sh` | PreToolUse on `git commit` | Spectral lint + contract tests. Blocking |
| `pre-merge-diff.sh` | PreToolUse on `git merge` | OpenAPI diff + contract tests; warns on breaking patterns |
| `pre-commit-docs-check.sh` | PreToolUse on `git commit` | Blocks significant changes without an ADR or README update, and routes to `docs-curator` |
| `block-sensitive-paths.sh` | PreToolUse on Read, Edit, Write, Bash | Denies `prod-config/`, `secrets/`, `.env`, `*.pem`, `*.key` |
| `post-audit-report.sh` | SubagentStop on `security-audit-agent` | Persists the report to `docs/audits/` and opens issues for CRITICAL and HIGH findings when `gh` is available |

Sensitive paths are denied twice, by `permissions.deny` and by the hook
([ADR-0005](./docs/adr/0005-permissions-deny-list-for-sensitive-paths.md)).
The same checks run on the human side through `.githooks/`, with the docs check
as a warning only ([ADR-0004](./docs/adr/0004-mirror-claude-hooks-with-git-hooks.md)).

### MCP servers (`.mcp.json`)

`tickets` (Jira-like), `git` (read-only), `db-schema` (DDL-only reader) and
`contract-test-runner`. Only `git` points to a published server; the three
others are placeholders showing where your own servers plug in.

### Other assistants

`.pochi/` mirrors the skills, agents and MCP configuration for
[Pochi](https://github.com/TabbyML/pochi): the method does not depend on one tool.

## Architecture decisions

ADRs live in [`docs/adr/`](./docs/adr/), newest first:

- [ADR-0006](./docs/adr/0006-docs-curator-and-self-documenting-commits.md): docs-curator skill + pre-commit hook, so every significant commit explains itself
- [ADR-0005](./docs/adr/0005-permissions-deny-list-for-sensitive-paths.md): lock down sensitive paths with a deny list and a duplicate hook
- [ADR-0004](./docs/adr/0004-mirror-claude-hooks-with-git-hooks.md): mirror the Claude hooks with git hooks (defense in depth)
- [ADR-0003](./docs/adr/0003-spectral-as-spec-linter.md): Spectral as the OpenAPI linter, with a ruleset that mirrors AGENTS.md
- [ADR-0002](./docs/adr/0002-ship-db-as-ddl-dump-no-flyway.md): ship the database schema as a DDL dump, not a Flyway migration
- [ADR-0001](./docs/adr/0001-contract-first-with-openapi-generator.md): openapi-generator for contract-first DTOs

More detail in [`ARCHITECTURE.md`](./ARCHITECTURE.md).

## The talk

| Year | Event | Title | Language | Replay |
|---|---|---|---|---|
| 2026 | France API | Your AI Survival Guide in Software Development | FR | [YouTube](https://youtu.be/5S8L5pSh2zU) |
| 2026 | DevQuest | Your AI Survival Guide in Software Development | FR | [YouTube](https://youtu.be/UtOyOZ1Ji3s) |
| 2025 | Devoxx Belgium | Your AI Survival Guide in Software Development | EN | [YouTube](https://youtu.be/fDPJtzuWLFg) |

Also given to students at Epitech Paris and Epitech Bordeaux (2026).

## Book this talk

Available as a keynote, a 2-hour meetup or a half-day hands-on workshop, in
French or English.

**[Request a quote](https://tally.so/r/Y5LRev)** · [LinkedIn](https://www.linkedin.com/in/rafik-ferroukh) · [YouTube](https://www.youtube.com/@TheUnBullshIT)

## License

[MIT](./LICENSE)
