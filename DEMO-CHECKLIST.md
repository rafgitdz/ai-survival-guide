# Demo checklist

Four prompts to paste into Claude Code, in order. Each prompt uses ONE skill or
ONE agent already in place. After each one, check the "how to tell it worked"
criteria.

## Technical baseline (talking points)

- **Spring Boot 3.5** + Java 21.
- **Hard contract-first** through `openapi-generator-maven-plugin` (7.26) on
  `openapi/payments.yaml`. The `PaymentsApi` / `PaymentMethodsApi` interfaces
  and every DTO are **generated** into `target/generated-sources/openapi/`.
  The `@RestController` classes implement them. If the spec changes, the build
  breaks.
- Key talking point: leaking `internalAccountId` in a response **is no longer
  possible**, because the generator never creates a field missing from the
  schema. Contract-first mechanically kills spec/code drift.

---

## Prerequisites (once, before the talk)

```bash
git clone https://github.com/rafgitdz/ai-survival-guide.git
cd ai-survival-guide

# 1. Enable the human-side git hooks
git config core.hooksPath .githooks

# 2. Install Spectral (otherwise the hooks log a warning and pass)
npm install -g @stoplight/spectral-cli

# 3. Check that the Maven build works (OpenAPI generation + compile + tests)
./mvnw -q clean test     # must report Tests run: 2, Failures: 0

# 4. Start Claude Code in the folder
claude
```

Quick check that Claude sees everything:

- `/agents` lists `api-evolution-agent` and `security-audit-agent`.
- `/skills` lists 7 skills.
- `/mcp` lists 4 servers (status may be "failed" when the commands are not wired: expected for the demo).
- `/hooks` lists 5 hooks (4 PreToolUse, 1 SubagentStop).

---

## Use case 1: DESIGN (skill `openapi-designer`)

**Story**: a product ticket asks for a new endpoint. The agent turns it into an
OpenAPI contract that follows the rules. **But** it runs into an existing data
schema (`db/schema.sql`) that does not quite match the ticket. Instead of
inventing, it **stops and asks you**. This is `AGENTS.md §6` in action:
*"never assume a database schema without reading it"*.

**Prompt to paste:**

> Read the ticket `tickets/API-1247.md`. Use the `openapi-designer` skill to
> draft the matching OpenAPI spec. Follow AGENTS.md. Do NOT generate Java code.

**What MUST happen (sequence):**

1. Claude reads `AGENTS.md`, `tickets/API-1247.md` and the existing spec `openapi/payments.yaml`.
2. Claude reads `db/schema.sql` **on its own** (enforced by step 3 of the skill workflow).
3. Claude detects two mismatches and the missing table, then **stops and asks**:
   - "The ticket says `amount`, the database says `amount_cents` (BIGINT, minor units). Which one goes in the contract?"
   - "The ticket says `currency`, the database says `currency_iso` (CHAR 3). Same question."
   - "The `refunds` table does not exist. Shall I propose a DDL in `db/schema-refunds.sql`, or do you have one?"
4. You answer live: *"business names (`amount`, `currency`). Propose the refunds DDL."*
5. Claude resumes: drafts a compliant `POST /v1/refunds` and proposes the DDL.

**How to tell it worked:**

- [ ] Claude asked **at least one** question before drafting (it did not invent).
- [ ] The final spec exposes `amount` and `currency` (not the database names), with types consistent with the database (uuid, integer minor units).
- [ ] Path `/v1/refunds`, plural kebab-case.
- [ ] Separate `RefundCreateRequest` and `Refund` schemas (no mass assignment).
- [ ] 404 / 409 / 422 responses present, with `application/problem+json` examples.
- [ ] `additionalProperties: false` on `RefundCreateRequest`.
- [ ] Semver classification stated (`MINOR`).
- [ ] (bonus) A `db/schema-refunds.sql` file proposed alongside.

**Optional machine check:**
```bash
spectral lint --ruleset .spectral.yml openapi/*.yaml
```

**Plan B if Claude does not dare to ask** (shy on stage): prompt it explicitly:
*"before drafting, scan `db/` as your SKILL.md step 3 requires"*. The moment
where it asks the question is the heart of the demo: do not skip it.

---

## Use case 2: EVOLVE (agent `api-evolution-agent` + skill `breaking-change-detector`)

**Prompt to paste:**

> Run the `api-evolution-agent` subagent. Its mission: we want to publish
> `openapi/payments-v2.yaml`. First, get the Semver classification between
> `payments-v1.yaml` and `payments-v2.yaml` confirmed by the
> `breaking-change-detector` skill. Then propose a plan: should we bump the
> version, create a `/v2`, keep `/v1` alive? STOP at the plan, I want to decide
> first.

**How to tell it worked:**

- [ ] The breaking-change-detector report lists at least:
  - `amount` renamed to `value` (MAJOR)
  - `currency` enum restricted (MAJOR)
  - `createdAt` removed (MAJOR)
  - new `status` query parameter (MINOR)
- [ ] Verdict: `MAJOR`.
- [ ] The agent FLAGS that `payments-v2.yaml` is still under `/v1/` when it
      should be under `/v2/` (the planted trap).
- [ ] The agent STOPS at the plan (plan-then-execute) before applying anything.

---

## Use case 3: SECURE (agent `security-audit-agent` + skills `owasp-reviewer` and `secret-scrubber`)

**Prompt to paste:**

> Run the `security-audit-agent` subagent on the spec `openapi/payments.yaml`
> and the code in `src/main/java/com/franceapi/demo/`. I want the full report:
> OWASP Top 10, secrets, consistency and observability, in a single document,
> with severity and a proposed fix. DO NOT apply anything yet.

**How to tell it worked:**

The report MUST contain at least:

- [ ] **[API3 / mass assignment]** on `PaymentCreateRequest` (`status`, `userId`, `internalAccountId`): the spec exposes these fields, the generator carried them into the Java DTO, the controller consumes them as is. Fix: remove them from the spec, and the next build regenerates a clean DTO.
- [ ] **[additionalProperties]**: `PaymentCreateRequest` has `additionalProperties: true`, so the client can inject any field.
- [ ] **[errors]**: `POST /v1/payments` returns 200 on a business error instead of 422.
- [ ] **[API2 / broken authentication]**: `GET /v1/payments/{id}` has `security: []` with no justification.
- [ ] **[API1 / BOLA]**: `GET /v1/payments/{id}` does not check ownership.
- [ ] **[API4]**: no pagination on `GET /v1/payments`.
- [ ] **[naming]**: `/v1/paymentMethods` breaks kebab-case.
- [ ] Release-blocking verdict: `yes` (CRITICAL > 0).
- [ ] The `post-audit-report.sh` hook wrote `docs/audits/audit-<timestamp>.md`.

Bonus test: ask Claude to read `prod-config/db.yml`. **It must fail**
(`block-sensitive-paths` hook + permissions deny list).

---

## Use case 4: AUDIT (skills `openapi-consistency-auditor` and `obs-readiness-checker`)

**Prompt to paste:**

> Use the `openapi-consistency-auditor` skill on `openapi/payments.yaml`, then
> the `obs-readiness-checker` skill on the Spring Boot application. Give me
> both reports, separately. No fix, just the verdict.

**How to tell it worked:**

For `openapi-consistency-auditor`:

- [ ] ERROR on `/v1/paymentMethods` (naming).
- [ ] ERROR on a `400` response that is not `application/problem+json`.
- [ ] ERROR on `additionalProperties: true` in `PaymentCreateRequest`.
- [ ] WARN/ERROR on the `internalAccountId` field returned but missing from the schema.
- [ ] Verdict: `FAIL`.

For `obs-readiness-checker`:

- [ ] A. Metrics: **OK** (`micrometer-registry-prometheus` present, `/actuator/prometheus` exposed through `application.yml`).
- [ ] B. Tracing: **MISSING** (no OTel bridge in `pom.xml`: the improvement to ask for live).
- [ ] C. Structured logs: **MISSING** (no `logstash-logback-encoder`, no `structured.format`).
- [ ] Verdict: `FAIL`.

---

## Bonus moment: `docs-curator` (self-orchestrating hook)

During any of the 4 use cases, when Claude finishes its changes and tries to
commit, the `pre-commit-docs-check.sh` hook detects that the commit touches a
significant file (spec, AGENTS.md, hook, skill, agent, pom, .mcp.json, database
schema) **without any staged ADR**, and exits with **code 2**.

Claude reads the stderr message and **invokes the `docs-curator` skill**, which:

1. Reads the staged diff.
2. Drafts `docs/adr/NNNN-<slug>.md` (MADR template: Context, Decision,
   Consequences, Alternatives, Links).
3. Amends `README.md` (at least the `Decisions` section).
4. Stages the new files.
5. Stops.

Claude runs `git commit` again, and this time the hook passes (ADR detected).

**Line to say on stage**: *"The hook no longer just blocks. It **orchestrates**
the agent so that it does the documentation work it would have skipped. The
rule 'every significant change explains itself' now enforces itself."*

**How to check:**
- [ ] `ls docs/adr/` shows a new `NNNN-*.md` file.
- [ ] The `Decisions` section of `README.md` links to the new ADR.
- [ ] The final `git log` shows **a single** commit with spec, ADR and README together.

---

## Fallback during the talk

- If a demo gets stuck: show `cat .claude/settings.json`, `ls .claude/skills/`,
  `ls .claude/agents/`, `cat .mcp.json`. The value is also in **the structure**,
  not only in the live result.
- The audit report from use case 3 is persisted: reopen it during the Q&A.
