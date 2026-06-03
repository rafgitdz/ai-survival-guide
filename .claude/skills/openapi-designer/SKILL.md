---
name: openapi-designer
description: Conçoit ou complète une spec OpenAPI 3.1 strictement conforme aux rules du repo (kebab-case, /v1, JWT, RFC 7807, observabilité). Utiliser dès qu'on doit créer un nouvel endpoint, un nouveau resource, ou transformer un ticket produit en contrat d'API. Ne génère JAMAIS de code Java ici — uniquement la spec et son diff.
---

# openapi-designer

## When to use

- Un ticket décrit un nouvel endpoint / une nouvelle ressource.
- Un agent doit traduire un besoin métier en contrat OpenAPI **avant** d'écrire du code.
- Une spec existante doit être étendue (nouvelle opération, nouveau champ).

**Ne pas utiliser** pour : auditer une spec existante (→ `openapi-consistency-auditor`), comparer deux versions (→ `breaking-change-detector`), checker la sécu (→ `owasp-reviewer`).

## Rules à respecter (rappel court)

Tirées de `AGENTS.md` :

- Paths `kebab-case`, pluriels pour les collections.
- Properties `camelCase`.
- Versioning `/v1` dans le path.
- `securitySchemes.bearerAuth` global sauf endpoint public.
- Erreurs RFC 7807 (`application/problem+json`) **avec exemples**.
- Toute mutation : `400, 401, 403, 404?, 409?, 422, 500`.
- Pas de mass assignment : `id`, `status`, `createdAt`, `userId` jamais en input.
- Observabilité : si on touche au resource, vérifier que `/actuator/prometheus` reste exposé.

## Workflow

1. **Lire le ticket / la demande.** Extraire : ressource, opérations attendues, contraintes métier, format des identifiants.
2. **Lire la spec existante** (`openapi/*.yaml`) pour réutiliser les composants (`Problem`, `Money`, `Pagination`, etc.) et garder le style cohérent.
3. **Inspecter la couche données AVANT de drafter** (AGENTS.md §6). Scanner **systématiquement**, même si le ticket n'en parle pas :
   - `db/schema.sql`, `db/migration/`, `src/main/resources/db/migration/` (Flyway/Liquibase).
   - Toute classe `*Entity.java`, `*Repository.java` (JPA).
   Si une table liée à la ressource du ticket existe :
   - **Réconcilier les noms** ticket vs DB. Mismatch (ex: `amount` vs `amount_cents`, `currency` vs `currency_iso`) → **STOP, poser la question à l'humain** : *"j'expose le nom business ou le nom technique ?"*. Ne jamais trancher seul.
   - **Réutiliser les types** (`UUID` → `format: uuid`, `TIMESTAMPTZ` → `format: date-time`, `BIGINT minor units` → `integer`).
   Si la table N'existe pas mais que le ticket en dépend : **STOP**, proposer un DDL en complément OU demander si elle existe ailleurs. **Jamais inventer un schéma.**
4. **Drafter la spec** :
   - Path en `kebab-case` pluriel.
   - Chaque opération : `summary`, `operationId` en camelCase, `tags`, `security`, `parameters`, `requestBody` (si applicable), `responses`.
   - Chaque `4xx`/`5xx` : `$ref: '#/components/schemas/Problem'` + **un `example` réaliste avec `type`, `title`, `status`, `detail`, `instance`**.
   - Schémas d'entrée distincts des schémas de sortie (`PaymentCreateRequest` vs `Payment`) pour bloquer le mass assignment.
5. **Spectral lint mental** : pas d'`additionalProperties: true` par défaut sur les requests, descriptions non vides, exemples présents.
6. **Produire** :
   - Le fichier YAML mis à jour.
   - Un bloc "DIFF résumé" listant : opérations ajoutées, schémas ajoutés, schémas modifiés.
   - Un **classement Semver** (PATCH / MINOR / MAJOR) du changement, justifié.
7. **Stop ici**. Ne pas générer le code Java. Le hook `pre-commit` lancera Spectral et les contract tests.

## Output format attendu

```
## Spec updated
<chemin du yaml>

## Diff résumé
- Added: POST /v1/payments
- Added schema: PaymentCreateRequest, Payment
- Reused: Problem, Money

## Semver
MINOR (nouveau endpoint, aucun champ existant cassé)

## Checklist auto
- [x] kebab-case
- [x] /v1
- [x] bearerAuth
- [x] 400/401/403/422/500 with examples
- [x] No mass-assignment fields in request schema
```
