---
name: breaking-change-detector
description: Compare deux specs OpenAPI (avant / après) et liste TOUS les breaking changes avec sévérité (MAJOR/MINOR/PATCH per rule Semver du repo). Utiliser avant tout merge sur une spec, sur une PR qui modifie un .yaml dans openapi/, ou quand on veut décider du bump de version. Ne propose PAS de patch — c'est un détecteur, pas un correcteur.
---

# breaking-change-detector

## When to use

- Une PR modifie un fichier dans `openapi/`.
- On hésite sur le bump de version (PATCH vs MINOR vs MAJOR).
- Le hook `pre-merge` veut un rapport diff.

**Ne pas utiliser** pour : design d'une nouvelle spec (→ `openapi-designer`), audit sécurité (→ `owasp-reviewer`).

## Classification (issue de AGENTS.md §3)

| Changement | Sévérité |
|---|---|
| Description, summary, tag, example modifié | **PATCH** |
| Nouvelle opération | **MINOR** |
| Nouveau champ **optionnel** en réponse ou en input | **MINOR** |
| Nouveau code de réponse (ex: ajout d'un `429`) | **MINOR** |
| Suppression d'une opération | **MAJOR** |
| Suppression d'un champ (request ou response) | **MAJOR** |
| Renommage d'un champ ou d'une opération | **MAJOR** |
| Changement de type (`integer` → `string`) | **MAJOR** |
| `optional` → `required` sur un champ d'input | **MAJOR** |
| `required` → `optional` sur un champ de **response** | **MAJOR** (clients ne s'y attendent plus) |
| Retrait d'une valeur d'enum | **MAJOR** |
| Changement de format d'erreur | **MAJOR** |
| Changement de schéma de sécurité | **MAJOR** |
| Changement de path (incluant casse) | **MAJOR** |

## Workflow

1. **Charger** les deux fichiers YAML (`old`, `new`).
2. **Parser** chacun → représentation canonique : `paths × methods × {parameters, requestBody, responses}` + `components.schemas` + `components.securitySchemes`.
3. **Diff structurel** :
   - Opérations supprimées / ajoutées.
   - Pour chaque opération conservée : params, requestBody, responses, security.
   - Pour chaque schéma référencé : champs (présence, type, required, enum, format).
4. **Classer** chaque changement selon la table ci-dessus.
5. **Décider** : si **au moins un MAJOR** → bump majeur obligatoire. Sinon MINOR si au moins un MINOR. Sinon PATCH.
6. **Produire le rapport** (format ci-dessous).
7. **Ne pas corriger**. Si l'utilisateur demande un patch, déléguer à `openapi-designer`.

## Output format

```
## Breaking change report
old: openapi/payments-v1.yaml
new: openapi/payments-v2.yaml

### MAJOR (n)
- POST /v1/payments — request: field `amount` renamed to `value` (rename = MAJOR)
- GET /v1/payments/{id} — response `Payment.currency` removed (removal = MAJOR)

### MINOR (n)
- GET /v1/payments — new optional query param `status`

### PATCH (n)
- (rien)

### Verdict
Required version bump: **MAJOR** (v1 → v2)
Path versioning required: yes — must publish under /v2.
```
