# FranceAPI Demo

Contract-first Spring Boot + OpenAPI demo, used to showcase agent-driven API workflows (design, evolve, secure, audit). The OpenAPI spec is the source of truth; Java DTOs and API interfaces are generated from it at build time.

The hard rules of the project live in [`AGENTS.md`](./AGENTS.md). Every architectural decision is recorded as an ADR under [`docs/adr/`](./docs/adr/).

## Stack

- **Spring Boot 3.5.0** on **Java 21**, built with Maven.
- **OpenAPI 3.1** specs under `openapi/`, generated to Java via `openapi-generator-maven-plugin` 7.10 in `interfaceOnly` mode.
- **Spectral** for spec linting, with a custom ruleset (`.spectral.yml`) that mirrors the AGENTS.md rules.
- **Micrometer + Prometheus** registry on `/actuator/prometheus` (see AGENTS.md §7).
- **Rest-Assured + JSON Schema validator** for contract tests.

## Quickstart

```bash
# 1) Activate the git hooks (lint + contract tests + warn-only docs check)
git config core.hooksPath .githooks

# 2) Install Spectral (otherwise the lint step warns and skips)
npm install -g @stoplight/spectral-cli

# 3) Build — runs the OpenAPI generator, compiles, runs tests
./mvnw -q clean test

# 4) Start Claude Code in the repo
claude
```

Inside Claude, `/agents` shows the 2 subagents, `/skills` lists the 7 skills, `/hooks` lists the 5 wired hooks, `/mcp` lists the 4 MCP servers.

A full guided walk-through of the four demo use cases (DESIGN, EVOLVE, SECURE, AUDIT) lives in [`DEMO-CHECKLIST.md`](./DEMO-CHECKLIST.md).

## Architecture

- **Contract-first hard**: `openapi/payments.yaml` drives Java generation. Spec edits propagate to `target/generated-sources/openapi/com/franceapi/demo/generated/{api,dto}`; controllers implement the generated interfaces. Spec/code drift becomes a compile error, not a review comment. See [ADR-0001](./docs/adr/0001-contract-first-with-openapi-generator.md).
- **No live DB**: the schema ships as a DDL dump at `db/schema.sql` (read by skills, not by the application). Avoids a Spring autoconfig clash during demo runs. See [ADR-0002](./docs/adr/0002-ship-db-as-ddl-dump-no-flyway.md).
- **Two enforcement layers** on every commit: Claude PreToolUse hooks and `.githooks/` git hooks. The Claude path blocks on missing docs; the git path warns. See [ADR-0004](./docs/adr/0004-mirror-claude-hooks-with-git-hooks.md).
- **Sensitive paths denied twice**: a `permissions.deny` list in `.claude/settings.json` and a PreToolUse hook (`block-sensitive-paths.sh`). See [ADR-0005](./docs/adr/0005-permissions-deny-list-for-sensitive-paths.md).
- **Self-documenting commits**: the `docs-curator` skill + `pre-commit-docs-check.sh` hook block any commit that touches a significant file without staging an ADR or README update. See [ADR-0006](./docs/adr/0006-docs-curator-and-self-documenting-commits.md).

## API

OpenAPI specs under `openapi/`:

| File | Version | Notes |
| --- | --- | --- |
| `payments.yaml` | 1.0.0 | The pedagogical spec — contains baked-in defects that the SECURE/AUDIT demos must find. Excluded from the blocking lint. |
| `payments-v1.yaml` | 1.2.0 | Baseline used by the EVOLVE demo (`breaking-change-detector` compares against it). |
| `payments-v2.yaml` | 1.3.0 (planted: should be 2.0.0) | The "candidate next version" used to demonstrate breaking-change detection. |

Endpoints exposed by `payments.yaml`:

- `POST /v1/payments` — create payment (`createPayment`)
- `GET  /v1/payments` — list payments (`listPayments`)
- `GET  /v1/payments/{paymentId}` — get payment (`getPayment`)
- `GET  /v1/paymentMethods` — list payment methods (`listPaymentMethods`, planted naming violation)

## Skills & Agents

### Skills (`.claude/skills/`)

| Skill | One-line purpose |
| --- | --- |
| `openapi-designer` | Draft or extend an OpenAPI 3.1 spec strictly conforming to AGENTS.md (kebab-case, `/v1`, JWT, RFC 7807). Never generates Java. |
| `openapi-consistency-auditor` | Audit an OpenAPI spec for internal consistency and AGENTS.md conformance. |
| `breaking-change-detector` | Diff two specs and classify every change as MAJOR / MINOR / PATCH. Detector only — no patching. |
| `owasp-reviewer` | Audit a spec + Spring Boot code against the OWASP API Security Top 10 (2023). |
| `obs-readiness-checker` | Verify Prometheus metrics + traces + structured logs per AGENTS.md §7. |
| `secret-scrubber` | Detect secrets in code, configs, specs, examples. Mask before any external output. |
| `docs-curator` | Two-mode doc curator — diff-driven (auto-triggered by the pre-commit hook) and codebase-audit (manual). Drafts ADRs and amends the README. |

### Agents (`.claude/agents/`)

| Agent | Trigger | Purpose |
| --- | --- | --- |
| `api-evolution-agent` | `/evolve <ticket-id>` | Plan-then-execute on an evolution ticket. Spec first, code second, tests third, PR last. |
| `security-audit-agent` | `/audit [spec]` | Orchestrate `owasp-reviewer` + `secret-scrubber` + `openapi-consistency-auditor` + `obs-readiness-checker` into one consolidated report. |

### MCP servers (`.mcp.json`)

`tickets` (Jira-like), `git` (read-only), `db-schema` (DDL-only Postgres reader), `contract-test-runner` (custom).

## Hooks

Wired in `.claude/settings.json`:

| Hook | Event | Matcher | Role |
| --- | --- | --- | --- |
| `pre-commit-openapi.sh` | PreToolUse | `Bash` (filters `git commit`) | Spectral lint + contract tests. Blocking. |
| `pre-merge-diff.sh` | PreToolUse | `Bash` (filters `git merge`) | OpenAPI diff + contract tests against the merge target. Warn on breaking patterns. |
| `pre-commit-docs-check.sh` | PreToolUse | `Bash` (filters `git commit`) | Blocks if significant files are staged without an ADR/README update. Routes to `docs-curator`. |
| `block-sensitive-paths.sh` | PreToolUse | `Read\|Edit\|Write\|MultiEdit\|NotebookEdit\|Bash` | Denies access to `prod-config/`, `secrets/`, `.env`, `*.pem`, `*.key`, etc. |
| `post-audit-report.sh` | SubagentStop | `security-audit-agent` | Persists the audit report to `docs/audits/audit-<timestamp>.md` and (best-effort) opens GitHub issues for CRITICAL/HIGH findings. |

A mirror set of human-side hooks lives in `.githooks/`. Lint and contract tests are blocking there too; docs-check is warn-only by design (see ADR-0004).

## Decisions

ADRs in `docs/adr/`, newest first:

- [ADR-0006](./docs/adr/0006-docs-curator-and-self-documenting-commits.md) — Adopt docs-curator skill + pre-commit hook so every significant commit explains itself
- [ADR-0005](./docs/adr/0005-permissions-deny-list-for-sensitive-paths.md) — Lock down sensitive paths via deny-list + a duplicate hook
- [ADR-0004](./docs/adr/0004-mirror-claude-hooks-with-git-hooks.md) — Mirror Claude PreToolUse hooks with git hooks (defense in depth)
- [ADR-0003](./docs/adr/0003-spectral-as-spec-linter.md) — Adopt Spectral as the OpenAPI linter, with a ruleset that mirrors AGENTS.md
- [ADR-0002](./docs/adr/0002-ship-db-as-ddl-dump-no-flyway.md) — Ship the DB schema as a DDL dump, not a Flyway migration
- [ADR-0001](./docs/adr/0001-contract-first-with-openapi-generator.md) — Adopt openapi-generator for contract-first DTOs
