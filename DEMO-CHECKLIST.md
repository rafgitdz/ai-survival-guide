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

**Narratif** : un ticket produit demande un nouvel endpoint. L'agent traduit
en contrat OpenAPI conforme aux rules. **Mais** il rencontre un schéma de
données existant (`db/schema.sql`) qui ne s'aligne pas parfaitement avec le
ticket. Au lieu d'inventer, il **s'arrête et te demande**. C'est la matérialisation
d'`AGENTS.md §6` : *"jamais supposer un schéma DB sans le lire"*.

**Prompt à coller :**

> Lis le ticket `tickets/API-1247.md`. Utilise le skill `openapi-designer`
> pour drafter la spec OpenAPI correspondante. Respecte AGENTS.md. Ne génère
> PAS de code Java.

**Ce qui DOIT se passer (séquence) :**

1. Claude lit `AGENTS.md`, `tickets/API-1247.md`, la spec existante `openapi/payments.yaml`.
2. Claude lit **spontanément** `db/schema.sql` (forcé par le step 3 du skill workflow).
3. Claude détecte deux mismatches et la table manquante, puis **s'arrête et pose les questions** :
   - "Ticket dit `amount`, DB dit `amount_cents` (BIGINT, minor units). J'expose lequel dans le contrat ?"
   - "Ticket dit `currency`, DB dit `currency_iso` (CHAR 3). Idem ?"
   - "La table `refunds` n'existe pas. Je propose un DDL dans `db/schema-refunds.sql`, ou tu en as un quelque part ?"
4. Tu réponds en live : *"noms business (`amount`, `currency`). Propose le DDL refunds."*
5. Claude reprend : draft `POST /v1/refunds` conforme + propose le DDL.

**Comment vérifier que ça a marché :**

- [ ] Claude a posé **au moins une** question avant de drafter (n'a pas inventé).
- [ ] La spec finale expose `amount` et `currency` (pas les noms DB) — typage cohérent avec la DB (uuid, integer minor units).
- [ ] Path `/v1/refunds` en kebab-case pluriel.
- [ ] Schémas distincts `RefundCreateRequest` et `Refund` (anti mass-assignment).
- [ ] Codes 404 / 409 / 422 présents avec exemples `application/problem+json`.
- [ ] `additionalProperties: false` sur `RefundCreateRequest`.
- [ ] Classement Semver annoncé (`MINOR`).
- [ ] (bonus) Un fichier `db/schema-refunds.sql` proposé en complément.

**Test machine optionnel :**
```bash
spectral lint --ruleset .spectral.yml openapi/*.yaml
```

**Plan B si Claude n'ose pas poser de question** (timide en live) : tu le
relances explicitement : *"avant de drafter, scanne `db/` comme demandé par
ton SKILL.md step 3"*. Le moment "il pose la question" est le cœur de la démo,
ne le sacrifie pas.

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

## Bonus moment — `docs-curator` (hook auto-orchestrant)

Pendant n'importe lequel des 4 use cases, quand Claude finit ses modifs et veut
commiter, le hook `pre-commit-docs-check.sh` détecte que le commit touche un
fichier significatif (spec, AGENTS.md, hook, skill, agent, pom, .mcp.json,
schema DB) **sans qu'aucun ADR ne soit staged** → **exit 2**.

Claude voit le message stderr, **invoque le skill `docs-curator`**, qui :

1. Lit le diff staged.
2. Drafte un `docs/adr/NNNN-<slug>.md` (template MADR : Context, Decision,
   Consequences, Alternatives, Links).
3. Amende `README.md` (section `Decisions` au minimum).
4. Stage les nouveaux fichiers.
5. Stoppe.

Claude relance le `git commit` — cette fois le hook passe (ADR détecté).

**Phrase à dire** : *"Le hook ne se contente plus de bloquer. Il **orchestre**
l'agent pour qu'il fasse le boulot de doc qu'il aurait sauté. La rule
'tout changement significatif s'explique' devient auto-applicable."*

**Comment vérifier** :
- [ ] `ls docs/adr/` montre un nouveau fichier `NNNN-*.md`.
- [ ] `README.md` section `Decisions` contient un lien vers le nouvel ADR.
- [ ] Le `git log` final montre **un seul** commit avec spec + ADR + README ensemble.

---

## Bonus / fallback pendant le talk

- Si une démo coince : montre simplement `cat .claude/settings.json`,
  `ls .claude/skills/`, `ls .claude/agents/`, `cat .mcp.json` — la valeur est aussi
  dans **la structure**, pas que dans le résultat live.
- Le rapport d'audit du use case 3 est persisté → tu peux le rouvrir pendant
  les questions du public.
