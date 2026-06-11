<!--
  ARCHITECTURE.md — Description technique de la stack et de la topologie du repo.
  Importé par CLAUDE.md → auto-chargé dans chaque conversation Claude Code.

  Périmètre : décrire CE QUI EST (technologies, layout, build, runtime).
  Pas de RULES ici (elles vivent dans AGENTS.md).
  Pas de POURQUOI ici (les choix sont justifiés dans docs/adr/).
-->

# Architecture — FranceAPI Demo

## Stack runtime

- **Java 21** (Homebrew OpenJDK ou tout JDK 21+).
- **Spring Boot 3.5.0** (parent POM).
- **Tomcat embedded** sur port `8080` par défaut (override `--server.port=8090` en cas de conflit).
- **Actuator endpoints exposés** : `/actuator/{health,info,prometheus,metrics}`.
- **Micrometer + micrometer-registry-prometheus** pour l'export Prometheus (nouvelle Prometheus Java client 1.x sous le capot).

## Stack build

- **Maven** (wrapper `./mvnw` versionné).
- **openapi-generator-maven-plugin 7.10** en mode `interfaceOnly` sur `openapi/payments.yaml` uniquement.
  - Phase : `generate-sources`.
  - Output : `target/generated-sources/openapi/src/main/java/com/franceapi/demo/generated/{api,dto}/`.
  - Config clés : `useSpringBoot3=true`, `useJakartaEe=true`, `useTags=true`, `skipDefaultInterface=true`, `openApiNullable=false`, `dateLibrary=java8`, `skipValidateSpec=true` (parce que la spec est volontairement imparfaite pour la démo).
- **Spectral** (CLI npm `@stoplight/spectral-cli`) pour le lint OpenAPI. Ruleset dans `.spectral.yml`.

## Topologie des packages Java

```
com.franceapi.demo/
├── DemoApplication              # @SpringBootApplication, entry point
├── controller/
│   ├── PaymentController        # implements PaymentsApi (générée)
│   └── PaymentMethodController  # implements PaymentMethodsApi (générée)
└── (config/, services/, ...     # vide pour la démo — à étoffer en prod)

com.franceapi.demo.generated/    # AUTO-GÉNÉRÉ — read-only, ne jamais éditer
├── api/
│   ├── PaymentsApi              # interface Spring, base path /v1/payments
│   └── PaymentMethodsApi
└── dto/
    ├── Payment
    ├── PaymentCreateRequest
    ├── PaymentMethod
    ├── Money
    ├── Problem
    └── CreatePayment400Response # inline 400 schema (sera supprimé après fix RFC 7807)
```

**Règle non négociable** : `target/generated-sources/` n'est jamais commité (`.gitignore`). Pour propager un changement de spec → relancer `./mvnw generate-sources` ou `./mvnw test`.

## Topologie des tests

- `src/test/java/com/franceapi/demo/PaymentContractTest.java`
- `@SpringBootTest(webEnvironment = RANDOM_PORT)` + RestAssured.
- Properties surchargées dans `@SpringBootTest(properties = ...)` pour ré-activer `management.defaults.metrics.export.enabled=true` (Spring Boot le désactive par défaut en tests).
- Convention : tout test de contrat porte le suffixe `*ContractTest` — le hook pre-commit cible cette suite.

## Topologie des specs OpenAPI

| Fichier | Rôle | État |
|---|---|---|
| `openapi/payments.yaml` | Source de génération du code Java + sujet des audits SECURE/AUDIT | **Volontairement imparfaite** (mass assignment, 200 sur erreur, naming camelCase, etc.) |
| `openapi/payments-v1.yaml` | Référence "avant" pour `breaking-change-detector` | Conforme aux rules + headers RFC 8594 `Deprecation`/`Sunset` |
| `openapi/payments-v2.yaml` | Référence "après" pour `breaking-change-detector` | Contient 3 breaking changes intentionnels (rename, removal, enum restrict) |
| `openapi/refunds.yaml` | Résultat du use case DESIGN | Généré par `openapi-designer` à partir de `tickets/API-1247.md` |

**Important** : seul `openapi/payments.yaml` est pris en input par `openapi-generator`. Les v1/v2/refunds sont des fixtures démos.

## Topologie des fixtures

```
tickets/API-1247.md      # Faux ticket Jira décrivant POST /v1/refunds
db/schema.sql            # DDL fixture avec pièges plantés (amount_cents vs amount, currency_iso vs currency, table refunds absente)
prod-config/, secrets/   # Honeypots — accès bloqué par permissions + hook
```

## Observabilité

| Dimension | Implémentation | Statut démo |
|---|---|---|
| **Métriques Prometheus** | `micrometer-registry-prometheus` + `/actuator/prometheus` | ✅ OK |
| **Tracing distribué** | Aucun bridge OTel/Zipkin dans `pom.xml` | ❌ Manquant — surface du use case AUDIT |
| **Logs structurés JSON** | Aucun encoder JSON, pattern logback minimaliste | ❌ Manquant — surface du use case AUDIT |

C'est intentionnel : `obs-readiness-checker` doit produire `FAIL` en démo et proposer le fix.

## Stack Claude Code

- **Rules** : `AGENTS.md` (référencé par `CLAUDE.md` via `@AGENTS.md`).
- **Skills** : 7 fichiers `.claude/skills/<n>/SKILL.md`.
- **Subagents** : 2 fichiers `.claude/agents/<n>.md` (model `opus`, tools restreints).
- **Hooks** : 4 scripts dans `.claude/hooks/` wirés depuis `.claude/settings.json` :
  - `pre-commit-openapi.sh` — PreToolUse Bash → spectral + contract tests.
  - `pre-merge-diff.sh` — PreToolUse Bash → diff openapi + warn breaking.
  - `block-sensitive-paths.sh` — PreToolUse Read/Edit/Write/Bash → deny prod-config/secrets.
  - `pre-commit-docs-check.sh` — PreToolUse Bash → force docs-curator.
  - `post-audit-report.sh` — SubagentStop matché sur `security-audit-agent` → persiste rapport sous `docs/audits/`.
- **Slash commands** : `.claude/commands/{audit,evolve}.md`.
- **MCP servers** : 4 dans `.mcp.json` (tickets, git, db-schema, contract-test-runner) — placeholders branchables.

## Hooks git (côté humain)

- `.githooks/pre-commit` — miroir des hooks Claude (defense in depth).
  - Spectral bloquant (sauf `payments.yaml`, exclu car volontairement imparfait).
  - Contract tests bloquants.
  - Docs check **WARN-only** côté humain (on n'oblige pas un dev à invoquer Claude).
- Activation : `git config core.hooksPath .githooks`.

## Flow de requête HTTP en runtime

```
HTTP POST /v1/payments
   │
   ▼
Tomcat embedded (Servlet container)
   │
   ▼
Spring DispatcherServlet
   │
   ▼
PaymentController#createPayment(PaymentCreateRequest)
   │   (implements PaymentsApi générée depuis openapi/payments.yaml)
   ▼
ResponseEntity<Payment>
   │
   ▼
Jackson sérialise → application/json
   │
   ▼
Filtre Actuator capture : http_server_requests_seconds → /actuator/prometheus
```

## Flow CI/dev

```
git commit
   │
   ▼ (1) Hook Claude PreToolUse Bash sur `git commit`
       ├── pre-commit-openapi.sh   → spectral + contract tests
       ├── pre-commit-docs-check.sh → exige ADR/README si changement significatif
       └── block-sensitive-paths.sh → deny prod-config/secrets
   │
   ▼ (2) Si Claude bypasse via terminal humain : .githooks/pre-commit
       (mêmes checks, docs WARN-only)
   │
   ▼ (3) Commit créé
```

## Conventions de nommage Maven / Spring

- `groupId` = `com.franceapi`, `artifactId` = `franceapi-demo`, `version` = `1.0.0`.
- Profile par défaut : aucun (`spring.profiles.active` non défini → "default").
- Tests : pas d'`@ActiveProfiles` (causait un faux échec de `/actuator/prometheus` en test, cf. ADR-0001).

## Liens internes

- Rules contraignantes : voir `AGENTS.md`.
- Décisions architecturales avec rationale : voir `docs/adr/`.
- Onboarding humain : voir `README.md`.
- Cycle démo des 4 use cases : voir `DEMO-CHECKLIST.md`.
