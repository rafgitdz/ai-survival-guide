<!--
  ARCHITECTURE.md: technical description of the stack and repository topology.
  Imported by CLAUDE.md, so loaded into every Claude Code conversation.

  Scope: describe WHAT IS (technologies, layout, build, runtime).
  No RULES here (they live in AGENTS.md).
  No WHY here (choices are justified in docs/adr/).
-->

# Architecture: AI survival guide demo

## Runtime stack

- **Java 21** (Homebrew OpenJDK or any JDK 21+).
- **Spring Boot 3.5.0** (parent POM).
- **Embedded Tomcat** on port `8080` by default (override with `--server.port=8090` on conflict).
- **Exposed Actuator endpoints**: `/actuator/{health,info,prometheus,metrics}`.
- **Micrometer + micrometer-registry-prometheus** for the Prometheus export (Prometheus Java client 1.x under the hood).

## Build stack

- **Maven** (versioned `./mvnw` wrapper).
- **openapi-generator-maven-plugin 7.26** in `interfaceOnly` mode, on `openapi/payments.yaml` only.
  - Phase: `generate-sources`.
  - Output: `target/generated-sources/openapi/src/main/java/com/franceapi/demo/generated/{api,dto}/`.
  - Key settings: `useSpringBoot3=true`, `useJakartaEe=true`, `useTags=true`, `skipDefaultInterface=true`, `openApiNullable=false`, `dateLibrary=java8`, `skipValidateSpec=true` (the spec is deliberately flawed for the demo).
- **Spectral** (npm CLI `@stoplight/spectral-cli`) for OpenAPI linting. Ruleset in `.spectral.yml`.

## Java package topology

```
com.franceapi.demo/
├── DemoApplication              # @SpringBootApplication, entry point
├── controller/
│   ├── PaymentController        # implements PaymentsApi (generated)
│   └── PaymentMethodController  # implements PaymentMethodsApi (generated)
└── (config/, services/, ...     # empty for the demo, to be fleshed out in production)

com.franceapi.demo.generated/    # GENERATED: read-only, never edit
├── api/
│   ├── PaymentsApi              # Spring interface, base path /v1/payments
│   └── PaymentMethodsApi
└── dto/
    ├── Payment
    ├── PaymentCreateRequest
    ├── PaymentMethod
    ├── Money
    ├── Problem
    └── CreatePayment400Response # inline 400 schema (removed once the RFC 7807 fix lands)
```

**Non-negotiable rule**: `target/generated-sources/` is never committed (`.gitignore`). To propagate a spec change, run `./mvnw generate-sources` or `./mvnw test`.

## Test topology

- `src/test/java/com/franceapi/demo/PaymentContractTest.java`
- `@SpringBootTest(webEnvironment = RANDOM_PORT)` + RestAssured.
- Properties overridden in `@SpringBootTest(properties = ...)` to re-enable `management.defaults.metrics.export.enabled=true` (Spring Boot disables it in tests by default).
- Convention: every contract test ends with `*ContractTest`; the pre-commit hook targets that suite.

## OpenAPI spec topology

| File | Role | State |
|---|---|---|
| `openapi/payments.yaml` | Source of the generated Java code, and subject of the SECURE/AUDIT demos | **Deliberately flawed** (mass assignment, 200 on error, camelCase path, etc.) |
| `openapi/payments-v1.yaml` | "Before" reference for `breaking-change-detector` | Compliant with the rules, plus RFC 8594 `Deprecation`/`Sunset` headers |
| `openapi/payments-v2.yaml` | "After" reference for `breaking-change-detector` | Contains 3 intentional breaking changes (rename, removal, enum restriction) |

**Important**: only `openapi/payments.yaml` is fed to `openapi-generator`. v1 and v2 are demo fixtures. The refunds spec does not exist yet: the DESIGN use case produces it live from `tickets/API-1247.md`.

## Fixture topology

```
tickets/API-1247.md      # Fake Jira ticket describing POST /v1/refunds
db/schema.sql            # DDL fixture with planted traps (amount_cents vs amount, currency_iso vs currency, missing refunds table)
prod-config/, secrets/   # Honeypots: access blocked by permissions + hook
examples/design-output/  # Reference output of the DESIGN use case, kept outside db/
```

## Observability

| Dimension | Implementation | Demo status |
|---|---|---|
| **Prometheus metrics** | `micrometer-registry-prometheus` + `/actuator/prometheus` | ✅ OK |
| **Distributed tracing** | No OTel/Zipkin bridge in `pom.xml` | ❌ Missing: surfaced by the AUDIT use case |
| **Structured JSON logs** | No JSON encoder, minimal logback pattern | ❌ Missing: surfaced by the AUDIT use case |

This is intentional: `obs-readiness-checker` must report `FAIL` during the demo and propose the fix.

## Claude Code stack

- **Rules**: `AGENTS.md` (referenced by `CLAUDE.md` through `@AGENTS.md`).
- **Skills**: 7 files `.claude/skills/<n>/SKILL.md`.
- **Subagents**: 2 files `.claude/agents/<n>.md` (model `opus`, restricted tools).
- **Hooks**: 5 scripts in `.claude/hooks/`, wired from `.claude/settings.json`:
  - `pre-commit-openapi.sh`: PreToolUse Bash, runs Spectral + contract tests.
  - `pre-merge-diff.sh`: PreToolUse Bash, OpenAPI diff + breaking-change warning.
  - `block-sensitive-paths.sh`: PreToolUse Read/Edit/Write/Bash, denies prod-config/secrets.
  - `pre-commit-docs-check.sh`: PreToolUse Bash, enforces docs-curator.
  - `post-audit-report.sh`: SubagentStop matched on `security-audit-agent`, persists the report under `docs/audits/`.
- **Slash commands**: `.claude/commands/{audit,evolve}.md`.
- **MCP servers**: 4 in `.mcp.json` (tickets, git, db-schema, contract-test-runner), pluggable placeholders.

## Git hooks (human side)

- `.githooks/pre-commit`: mirror of the Claude hooks (defense in depth).
  - Spectral blocking (except `payments.yaml`, excluded because deliberately flawed).
  - Contract tests blocking.
  - Docs check **warn-only** on the human side (a developer is not forced to invoke Claude).
- Activation: `git config core.hooksPath .githooks`.

## Runtime HTTP request flow

```
HTTP POST /v1/payments
   │
   ▼
Embedded Tomcat (servlet container)
   │
   ▼
Spring DispatcherServlet
   │
   ▼
PaymentController#createPayment(PaymentCreateRequest)
   │   (implements PaymentsApi, generated from openapi/payments.yaml)
   ▼
ResponseEntity<Payment>
   │
   ▼
Jackson serializes to application/json
   │
   ▼
Actuator filter records http_server_requests_seconds, exposed on /actuator/prometheus
```

## CI/dev flow

```
git commit
   │
   ▼ (1) Claude PreToolUse Bash hook on `git commit`
       ├── pre-commit-openapi.sh    → Spectral + contract tests
       ├── pre-commit-docs-check.sh → requires an ADR/README update on significant changes
       └── block-sensitive-paths.sh → denies prod-config/secrets
   │
   ▼ (2) If Claude is bypassed through a human terminal: .githooks/pre-commit
       (same checks, docs warn-only)
   │
   ▼ (3) Commit created
```

## Maven / Spring naming conventions

- `groupId` = `com.franceapi`, `artifactId` = `franceapi-demo`, `version` = `1.0.0`.
- Default profile: none (`spring.profiles.active` unset, so "default").
- Tests: no `@ActiveProfiles` (it caused a false failure of `/actuator/prometheus` in tests, see ADR-0001).

## Internal links

- Binding rules: see `AGENTS.md`.
- Architecture decisions with rationale: see `docs/adr/`.
- Human onboarding: see `README.md`.
- Walk-through of the 4 demo use cases: see `DEMO-CHECKLIST.md`.
