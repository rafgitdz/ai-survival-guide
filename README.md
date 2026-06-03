# FranceAPI Demo

Démo France API 2026 — comment Claude Code, des skills, des subagents et des hooks
encadrent le cycle de vie d'une API REST Spring Boot **contract-first**.

Quatre use cases présentés en live : **DESIGN**, **EVOLVE**, **SECURE**, **AUDIT**.
La checklist exhaustive et les prompts de démo sont dans [`DEMO-CHECKLIST.md`](./DEMO-CHECKLIST.md).

## Stack

- **Java 21**, **Spring Boot 3.5**.
- **OpenAPI 3.1** comme source de vérité. Les DTOs et API interfaces sont **générés** depuis `openapi/payments.yaml` par `openapi-generator-maven-plugin` (7.10, mode `interfaceOnly`).
- **Spectral** comme linter de spec, branché en pre-commit.
- **Actuator + Micrometer + Prometheus** pour l'observabilité.
- **RestAssured** pour les contract tests.

## Quickstart

```bash
# 1. Init du repo (premier commit : bypass car la spec contient des défauts plantés)
git init && git add -A && git commit -m "chore: initial scaffold" --no-verify

# 2. Active les hooks git côté humain (defense in depth)
git config core.hooksPath .githooks

# 3. (Optionnel) install Spectral pour le lint
npm install -g @stoplight/spectral-cli

# 4. Build + tests (génère les DTOs, compile, lance les contract tests)
./mvnw -q clean test    # → Tests run: 2, Failures: 0

# 5. Lance Claude Code dans le dossier pour exécuter les 4 use cases
claude
```

## Architecture

Le repo encode quatre couches qui collaborent :

| Couche | Rôle | Localisation |
|---|---|---|
| **Rules** | Conventions équipe non négociables | [`AGENTS.md`](./AGENTS.md) |
| **Skills** | Savoir-faire chargés à la demande dans une conversation | [`.claude/skills/*/SKILL.md`](./.claude/skills/) |
| **Subagents** | Orchestrateurs autonomes en contexte isolé | [`.claude/agents/*.md`](./.claude/agents/) |
| **Hooks** | Garde-fous déterministes hors LLM | [`.claude/hooks/*.sh`](./.claude/hooks/) + [`.claude/settings.json`](./.claude/settings.json) |

## API

Sous contrat dans [`openapi/payments.yaml`](./openapi/payments.yaml) :

- `POST   /v1/payments` — créer un paiement.
- `GET    /v1/payments` — lister.
- `GET    /v1/payments/{paymentId}` — récupérer.
- `GET    /v1/paymentMethods` — lister les moyens de paiement *(planté en camelCase pour la démo audit)*.

Spécifications de versioning pour le use case EVOLVE :

- [`openapi/payments-v1.yaml`](./openapi/payments-v1.yaml) — baseline, marquée `deprecated` avec headers `Deprecation` / `Sunset` (RFC 8594), sunset au 2026-09-01.
- [`openapi/payments-v2.yaml`](./openapi/payments-v2.yaml) — successeur publié sous `/v2`, contient 3 breaking changes intentionnels.

## Skills & Agents

**Skills** disponibles (chargés par Claude à la demande) :

- `openapi-designer` — drafte une spec conforme aux rules.
- `breaking-change-detector` — diff deux specs, classifie Semver.
- `owasp-reviewer` — audit OWASP API Top 10.
- `secret-scrubber` — détecte/masque les secrets.
- `openapi-consistency-auditor` — cohérence interne de spec.
- `obs-readiness-checker` — métriques / traces / logs.
- `docs-curator` — drafte ADR + amende README sur les commits significatifs.

**Subagents** (lancés explicitement) :

- `api-evolution-agent` — plan-then-execute sur une demande de changement (slash : `/evolve <TICKET-ID>`).
- `security-audit-agent` — orchestre 4 skills d'audit, produit un rapport consolidé (slash : `/audit`).

## Hooks

Wirés dans [`.claude/settings.json`](./.claude/settings.json) :

| Hook | Événement | Rôle |
|---|---|---|
| `pre-commit-openapi.sh` | `PreToolUse` Bash sur `git commit` | Spectral + contract tests, bloque si fail. |
| `pre-merge-diff.sh` | `PreToolUse` Bash sur `git merge` | Diff OpenAPI + contract tests + warn breaking. |
| `block-sensitive-paths.sh` | `PreToolUse` Read/Edit/Write/Bash | Interdit `prod-config/`, `secrets/`, `.env`, `*.pem`, `*.key`. |
| `pre-commit-docs-check.sh` | `PreToolUse` Bash sur `git commit` | Refuse les commits significatifs sans ADR/README mis à jour — invoque `docs-curator`. |
| `post-audit-report.sh` | `SubagentStop` sur `security-audit-agent` | Persiste le rapport sous `docs/audits/`, ouvre des issues via `gh`. |

Côté humain, un hook git en miroir vit dans [`.githooks/pre-commit`](./.githooks/pre-commit) (mode WARN-only sur les docs pour ne pas casser le workflow dev).

## Decisions

- [ADR-0001: Adopt openapi-generator for contract-first DTOs](./docs/adr/0001-contract-first-with-openapi-generator.md)

Template : [`docs/adr/0000-template.md`](./docs/adr/0000-template.md).
Toutes les futures décisions sont ajoutées par le skill `docs-curator` lors des commits significatifs.

## Use cases de démo

Détail dans [`DEMO-CHECKLIST.md`](./DEMO-CHECKLIST.md).

1. **DESIGN** — un ticket produit, l'agent traduit en spec, **s'arrête et pose une question** parce que le ticket et la DB ne s'alignent pas.
2. **EVOLVE** — `payments-v1` vs `payments-v2`, classification Semver, planification du bump majeur et de la déprecation.
3. **SECURE** — audit multi-angle parallèle (OWASP, secrets, cohérence, obs), rapport consolidé.
4. **AUDIT** — verdict release-readiness (consistency + obs), gate machine-vérifiable.
