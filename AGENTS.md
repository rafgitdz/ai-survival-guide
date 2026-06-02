<!--
  AGENTS.md — Règles universelles pour ce repo.
  Lu automatiquement par Claude Code (et tout autre outil compatible AGENTS.md).
  Toute génération de code, toute proposition d'agent, tout review DOIT respecter ces règles.
  Si une règle est en conflit avec une demande utilisateur, l'agent doit le signaler avant d'agir.
-->

# Rules — FranceAPI Demo (Spring Boot + OpenAPI)

## 1. Stack & style

- **Stack** : Spring Boot 3.x, Java 21, OpenAPI 3.1, Maven.
- **Style API** : REST, **contract-first** — la spec OpenAPI est la source de vérité, le code Java est généré ou validé par rapport à elle. Jamais le code en premier.

## 2. Conventions de nommage

- **Paths** : `kebab-case`, **pluriel** pour les collections.
  - ✅ `/payment-methods`, `/invoices/{invoiceId}/line-items`
  - ❌ `/PaymentMethod`, `/invoice/{id}/lineItem`
- **Properties JSON** : `camelCase`.
  - ✅ `customerId`, `createdAt`
  - ❌ `customer_id`, `CreatedAt`
- **Enums** : `SCREAMING_SNAKE_CASE` côté valeur (`PAYMENT_PENDING`).

## 3. Versioning

- **`/v1`, `/v2`, ...** dans le path. Pas de header de version.
- **Semver strict** sur la spec :
  - PATCH : doc, examples, descriptions.
  - MINOR : nouveau endpoint, nouveau champ optionnel.
  - MAJOR : **toute** suppression / renommage / changement de type / changement d'obligation (optional→required) / changement d'enum / changement de format d'erreur.
- **Aucun breaking change ne peut sortir sans bump majeur** ET sans entrée dans `CHANGELOG.md`.

## 4. Authentification

- **JWT Bearer** (`Authorization: Bearer ...`), validé côté serveur (signature + `exp` + `iss` + `aud`).
- Spec : `securitySchemes.bearerAuth` doit être déclaré et appliqué par défaut à toutes les opérations sauf endpoints publics explicitement annotés `security: []`.

## 5. Erreurs

- **RFC 7807** (`application/problem+json`) — strict.
- Chaque opération **DOIT** déclarer ses réponses 4xx/5xx pertinentes avec **schéma `Problem` + un exemple réaliste**.
- Codes minimum à considérer pour toute mutation : `400`, `401`, `403`, `404` (si ressource), `409` (si conflit possible), `422` (validation métier), `500`.
- Jamais de `200 OK` sur une erreur métier. Jamais de body d'erreur custom hors RFC 7807.

## 6. Honnêteté du contrat

- **Jamais inventer un champ.** Si un champ apparaît dans une réponse, il DOIT figurer dans le schéma.
- **Jamais supposer un schéma de base de données.** Avant de modéliser un DTO, lire la migration / l'entité JPA / le schéma SQL réel.
- Pas de mass assignment : les DTOs d'entrée n'exposent que les champs modifiables par le client. `id`, `status`, `createdAt`, `userId` (si dérivé du JWT), etc. ne sont **jamais** acceptés en input direct.

## 7. Observabilité (non négociable)

Toute API exposée DOIT, à la livraison :

- **Métriques Prometheus** : `/actuator/prometheus` exposé, `http_server_requests_seconds` actif via Micrometer.
- **Traces distribuées** : propagation `traceparent` (W3C), export OTLP ou Zipkin configuré.
- **Logs structurés** : JSON, champs minimum `timestamp`, `level`, `traceId`, `spanId`, `service`, `message`. Pas de log de PII ni de secret.

## 8. Sécurité — garde-fous obligatoires

- Pas de secret en clair dans le repo (cf. skill `secret-scrubber`).
- Validation d'entrée systématique (Bean Validation `@Valid`).
- OWASP API Security Top 10 audité avant chaque release (cf. agent `security-audit-agent`).
- Rate limiting documenté dans la spec (`X-RateLimit-*` headers).

## 9. Workflow attendu des agents

1. Lire la spec OpenAPI concernée avant de proposer un changement de code.
2. Si on ajoute / modifie un endpoint : **mettre à jour la spec en premier**, puis le code, puis les tests.
3. Toujours produire le diff de spec si la spec change.
4. Tout PR doit passer : `spectral lint`, contract tests, OWASP review, obs check.
