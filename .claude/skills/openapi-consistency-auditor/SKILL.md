---
name: openapi-consistency-auditor
description: Audite une spec OpenAPI pour cohérence interne et conformité aux rules du repo (naming, erreurs, champs documentés, exemples présents, schémas réutilisés). Sort une liste d'incohérences avec fix précis. Utiliser quand on hérite d'une spec, qu'on prépare un audit, ou en complément de owasp-reviewer.
---

# openapi-consistency-auditor

## When to use

- Au démarrage d'un audit (DESIGN/EVOLVE/AUDIT use case).
- Quand une spec a été modifiée par plusieurs mains et qu'on doute du style.
- En pré-flight avant un release pour vérifier que la spec décrit bien l'API réelle.

**Ne pas utiliser** pour : sécurité OWASP (→ `owasp-reviewer`), breaking changes entre deux versions (→ `breaking-change-detector`).

## Checks (groupés)

### Conformité aux rules (AGENTS.md)

- [ ] Tous les paths sont en `kebab-case` et au pluriel pour les collections.
- [ ] Toutes les properties sont en `camelCase`.
- [ ] Tous les paths commencent par `/v{n}`.
- [ ] `securitySchemes.bearerAuth` déclaré ; appliqué globalement ou explicitement par opération ; les endpoints publics ont `security: []` explicite.
- [ ] Chaque opération de mutation déclare au minimum `400, 401, 403, 422, 500`. Pas de `200` pour une erreur.
- [ ] Chaque réponse `4xx/5xx` utilise `application/problem+json` et `$ref` vers `#/components/schemas/Problem`.
- [ ] Chaque `4xx/5xx` a un `example` réaliste (pas juste `"string"`).

### Cohérence interne

- [ ] Tout `$ref` cible un schéma qui existe.
- [ ] Aucun schéma orphelin dans `components.schemas`.
- [ ] Aucun `additionalProperties: true` dans un requestBody.
- [ ] Schémas d'input ≠ schémas d'output (pour bloquer mass assignment).
- [ ] Les champs présents dans les `example` existent tous dans le schéma.
- [ ] Les champs déclarés dans le schéma apparaissent dans **au moins un** `example`.
- [ ] Les `enum` sont cohérents entre input et output (mêmes valeurs).

### Observabilité documentée

- [ ] La spec mentionne `/actuator/prometheus` OU déclare des `tags`/`x-metrics` documentant les métriques émises.
- [ ] Les rate limits sont déclarés (headers `X-RateLimit-Limit`, `X-RateLimit-Remaining`).

## Workflow

1. **Charger** le YAML.
2. **Dérouler** les checks ci-dessus, dans l'ordre.
3. **Pour chaque échec**, produire une ligne `[SEVERITY] <check_id> <location> — <evidence> → <fix>`.
   - Sévérité : `ERROR` (rule violée), `WARN` (style/cohérence), `INFO` (suggestion).
4. **Compter** par sévérité.
5. **Output final** : verdict pass/fail (fail si > 0 ERROR).

## Output format

```
## OpenAPI consistency audit
File: openapi/payments.yaml

### ERROR (n)
- [naming] /v1/Payments — path is not kebab-case → rename to /v1/payments
- [errors] POST /v1/payments — response 200 declared for failure scenario "insufficient funds" → use 422 with Problem schema

### WARN (n)
- [examples] Payment schema — `createdAt` is declared but appears in no example → add a value in the GET response example

### INFO (n)
- [obs] No mention of /actuator/prometheus in the spec → consider documenting metrics tags

### Verdict
FAIL — 2 errors. Spec is not release-ready.
```
