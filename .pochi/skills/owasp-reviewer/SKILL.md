---
name: owasp-reviewer
description: Audite une spec OpenAPI ET le code Spring Boot associé contre l'OWASP API Security Top 10 (édition 2023). Pour chaque vulnérabilité détectée, produit sévérité (CRITICAL/HIGH/MEDIUM/LOW), localisation précise (fichier:ligne ou path+method), preuve, et patch suggéré. Utiliser avant chaque release ou sur demande explicite d'audit sécurité.
---

# owasp-reviewer

## When to use

- Demande explicite "audit sécurité" / "check OWASP" / "review sécu".
- Lancé par `security-audit-agent`.
- Avant un merge vers `main` qui touche à une route exposée.

**Ne pas utiliser** pour : détection de secrets (→ `secret-scrubber`), cohérence de spec (→ `openapi-consistency-auditor`).

## Référentiel — OWASP API Security Top 10 (2023)

| # | Code | Nom court | Ce qu'on cherche |
|---|---|---|---|
| 1 | API1 | Broken Object Level Authorization (BOLA) | Endpoint `/things/{id}` qui ne vérifie pas que l'objet appartient au caller. |
| 2 | API2 | Broken Authentication | JWT sans vérif `exp`/`iss`/`aud`, endpoints sensibles sans `security`. |
| 3 | API3 | Broken Object Property Level Authorization | Mass assignment, exposition de champs internes (`internalAccountId`, `isAdmin`). |
| 4 | API4 | Unrestricted Resource Consumption | Pas de pagination, pas de rate limit, pas de taille max requestBody. |
| 5 | API5 | Broken Function Level Authorization | Routes admin sans check de rôle. |
| 6 | API6 | Unrestricted Access to Sensitive Business Flows | Pas de protection contre la répétition (paiement, signup). |
| 7 | API7 | Server Side Request Forgery (SSRF) | Champ URL côté input, fetch côté serveur sans allowlist. |
| 8 | API8 | Security Misconfiguration | CORS `*` + credentials, `additionalProperties: true` sur input, headers de sécu manquants. |
| 9 | API9 | Improper Inventory Management | Endpoints non documentés dans la spec, versions obsolètes encore exposées. |
| 10 | API10 | Unsafe Consumption of APIs | Appels sortants sans validation de schéma. |

## Workflow

1. **Inventorier** :
   - Toutes les specs sous `openapi/`.
   - Tous les `@RestController`, `@RequestMapping`, `@GetMapping`, etc. dans `src/main/java`.
   - Le fichier de config de sécurité Spring (`SecurityConfig` ou `application.yml`).
2. **Réconcilier** : confronter les routes de la spec vs les routes du code (mismatch = API9).
3. **Pour chaque endpoint**, dérouler les 10 checks ci-dessus.
4. **Pour chaque finding** :
   - Sévérité : `CRITICAL` (auth/data leak/exec), `HIGH` (BOLA, mass assignment exploitable), `MEDIUM` (DoS, misconfig), `LOW` (info disclosure mineur).
   - Localisation : `openapi/payments.yaml#/paths/~1v1~1payments/post` OU `PaymentController.java:42`.
   - Preuve : 2-5 lignes qui montrent le problème.
   - Fix suggéré : 1-3 lignes (diff ou consigne précise).
5. **Produire le rapport** au format ci-dessous.
6. **Ne pas appliquer les fixes** — c'est le rôle de `security-audit-agent` après validation humaine.

## Output format

```
## OWASP API Security audit
Scope: openapi/payments.yaml + src/main/java/com/franceapi/demo/**

### CRITICAL (n)
[API3] Mass assignment on POST /v1/payments
  Location: openapi/payments.yaml — PaymentCreateRequest
  Evidence: schema accepts `status` and `userId` from the client
  Fix: remove `status` and `userId` from PaymentCreateRequest; set status server-side; derive userId from JWT subject.

### HIGH (n)
...

### MEDIUM (n)
...

### LOW (n)
...

### Summary
CRITICAL: n   HIGH: n   MEDIUM: n   LOW: n
Release-blocking: yes/no (yes si CRITICAL > 0 ou HIGH > 0)
```
