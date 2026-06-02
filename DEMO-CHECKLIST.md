# Demo Checklist — France API 2026

Quatre prompts à coller dans Claude Code, dans l'ordre. Chaque prompt utilise UN
skill ou UN agent déjà en place. Vérifie en sortie le critère "comment savoir
que ça marche".

## Socle technique (rappel pour le narratif)

- **Spring Boot 3.5** + Java 21.
- **Contract-first dur** via `openapi-generator-maven-plugin` (7.10) sur
  `openapi/payments.yaml`. Les interfaces `PaymentsApi` / `PaymentMethodsApi`
  et tous les DTOs sont **générés** dans `target/generated-sources/openapi/`.
  Les `@RestController` les implémentent. Si la spec change → le build casse.
- Talking point fort : le leak `internalAccountId` côté response **n'est plus
  possible** parce que le generator ne crée pas un champ absent du schéma. Le
  contract-first tue mécaniquement le drift spec/code.

---

## Pré-requis (à faire UNE fois avant le talk)

```bash
cd /Users/fikou/IdeaProjects/FranceAPI/franceapi-demo

# 1. Init git pour activer le hook git pre-commit côté humain
git init && git add -A && git commit -m "chore: initial scaffold" --no-verify

# 2. Activer les hooks git
git config core.hooksPath .githooks

# 3. Installer spectral (sinon les hooks loguent un warn et passent)
npm install -g @stoplight/spectral-cli

# 4. Vérifier que Maven build (génération OpenAPI + compile + tests)
./mvnw -q clean test     # doit afficher Tests run: 2, Failures: 0

# 5. Démarrer Claude Code dans le dossier
claude
```

Vérification rapide que Claude voit bien tout :

- Tape `/agents` → tu dois voir `api-evolution-agent` et `security-audit-agent`.
- Tape `/skills` → 6 skills.
- Tape `/mcp` → 4 serveurs listés (status peut être "failed" si les commandes ne sont pas branchées, c'est normal pour la démo).
- Tape `/hooks` → 4 hooks (PreToolUse×3 + SubagentStop×1).

---

## Use case 1 — DESIGN (skill `openapi-designer`)

**Prompt à coller :**

> Lis le ticket `tickets/API-1247.md`. Utilise le skill `openapi-designer` pour
> drafter la spec OpenAPI correspondante, à ajouter dans `openapi/payments.yaml`
> (ou un nouveau fichier `openapi/refunds.yaml`, à toi de juger). Respecte les
> rules de `AGENTS.md`. Ne génère PAS de code Java.

**Comment vérifier que ça a marché :**

- [ ] Claude a lu `AGENTS.md` et `tickets/API-1247.md`.
- [ ] Une nouvelle section `paths: /v1/refunds:` apparaît dans un fichier YAML.
- [ ] Le path est en kebab-case, pluriel.
- [ ] Schémas distincts pour `RefundCreateRequest` et `Refund`.
- [ ] Les codes 404 / 409 / 422 sont présents avec exemples RFC 7807.
- [ ] Un classement Semver est annoncé (devrait être `MINOR`).
- [ ] `additionalProperties: false` sur `RefundCreateRequest`.

Test optionnel :
```bash
spectral lint --ruleset .spectral.yml openapi/*.yaml
```

---

## Use case 2 — EVOLVE (agent `api-evolution-agent` + skill `breaking-change-detector`)

**Prompt à coller :**

> Lance le subagent `api-evolution-agent`. Sa mission : on veut publier
> `openapi/payments-v2.yaml`. D'abord, fais-toi confirmer par le skill
> `breaking-change-detector` la classification Semver entre `payments-v1.yaml`
> et `payments-v2.yaml`. Puis propose un plan : faut-il bump la version, créer
> un `/v2`, garder `/v1` actif ? STOP au plan, je veux décider avant.

**Comment vérifier que ça a marché :**

- [ ] Le rapport breaking-change-detector liste au minimum :
  - `amount` → `value` (rename, MAJOR)
  - `currency` enum restreint (MAJOR)
  - `createdAt` supprimé (MAJOR)
  - nouveau query param `status` (MINOR)
- [ ] Verdict : `MAJOR`.
- [ ] L'agent SIGNALE que la spec `payments-v2.yaml` est encore sous `/v1/` alors
      qu'elle devrait être sous `/v2/` (le piège planté).
- [ ] L'agent S'ARRÊTE au plan (mode plan-then-execute) avant d'appliquer.

---

## Use case 3 — SECURE (agent `security-audit-agent` + skill `owasp-reviewer` + `secret-scrubber`)

**Prompt à coller :**

> Lance le subagent `security-audit-agent` sur la spec `openapi/payments.yaml`
> et le code dans `src/main/java/com/franceapi/demo/`. Je veux le rapport
> complet : OWASP Top 10 + secrets + cohérence + observabilité, dans un seul
> document, avec sévérité et fix proposé. N'APPLIQUE PAS encore.

**Comment vérifier que ça a marché :**

Le rapport DOIT contenir au minimum :

- [ ] **[API3 / mass assignment]** sur `PaymentCreateRequest` (`status`, `userId`, `internalAccountId`) — la spec expose ces champs, le generator les a fait remonter dans le DTO Java, le controller les consomme tels quels. Fix : retirer ces champs de la spec → la prochaine compilation régénère un DTO propre.
- [ ] **[additionalProperties]** : `PaymentCreateRequest` a `additionalProperties: true` → le client peut injecter n'importe quel champ.
- [ ] **[errors]** : POST `/v1/payments` renvoie 200 sur erreur métier au lieu de 422.
- [ ] **[API2 / broken auth]** : `GET /v1/payments/{id}` a `security: []` sans justification.
- [ ] **[API1 / BOLA]** : `GET /v1/payments/{id}` ne check pas l'ownership.
- [ ] **[API4]** : pas de pagination sur `GET /v1/payments`.
- [ ] **[naming]** : `/v1/paymentMethods` viole kebab-case.
- [ ] Verdict release-blocking : `yes` (CRITICAL > 0).
- [ ] Le hook `post-audit-report.sh` a écrit `docs/audits/audit-<timestamp>.md`.

Test bonus : demande à Claude de lire `prod-config/db.yml`. **Doit échouer**
(hook `block-sensitive-paths` + permissions deny).

---

## Use case 4 — AUDIT (skill `openapi-consistency-auditor` + skill `obs-readiness-checker`)

**Prompt à coller :**

> Utilise le skill `openapi-consistency-auditor` sur `openapi/payments.yaml`,
> puis le skill `obs-readiness-checker` sur l'application Spring Boot.
> Donne-moi les deux rapports, séparés. Pas de fix, juste le verdict.

**Comment vérifier que ça a marché :**

Pour `openapi-consistency-auditor` :

- [ ] ERROR sur `/v1/paymentMethods` (naming).
- [ ] ERROR sur réponse `400` non `application/problem+json`.
- [ ] ERROR sur `additionalProperties: true` dans `PaymentCreateRequest`.
- [ ] WARN/ERROR sur le champ `internalAccountId` retourné mais absent du schéma.
- [ ] Verdict : `FAIL`.

Pour `obs-readiness-checker` :

- [ ] A. Métriques : **OK** (`micrometer-registry-prometheus` présent, `/actuator/prometheus` exposé via `application.yml`).
- [ ] B. Tracing : **MISSING** (pas de bridge OTel dans `pom.xml` — c'est l'amélioration à demander en live).
- [ ] C. Logs structurés : **MISSING** (pas de `logstash-logback-encoder`, pas de `structured.format`).
- [ ] Verdict : `FAIL`.

---

## Bonus / fallback pendant le talk

- Si une démo coince : montre simplement `cat .claude/settings.json`,
  `ls .claude/skills/`, `ls .claude/agents/`, `cat .mcp.json` — la valeur est aussi
  dans **la structure**, pas que dans le résultat live.
- Le rapport d'audit du use case 3 est persisté → tu peux le rouvrir pendant
  les questions du public.
