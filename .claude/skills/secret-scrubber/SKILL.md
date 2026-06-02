---
name: secret-scrubber
description: Détecte secrets, credentials, clés API, tokens, mots de passe en dur dans le code, les configs, les specs et les exemples. Masque-les dans tout output destiné à un log, un rapport ou un message externe. Utiliser systématiquement avant tout output d'audit, toute génération de rapport, toute trace destinée à sortir du repo.
---

# secret-scrubber

## When to use

- Avant de produire n'importe quel rapport qui sortira du repo (audit, PR description, message Slack/Jira via MCP).
- Quand un agent s'apprête à logger / afficher un fichier de config (`application.yml`, `.env`, fichiers sous `secrets/` ou `prod-config/`).
- Si l'utilisateur colle un payload qui ressemble à un secret.

**Ne pas utiliser** pour : audit OWASP (→ `owasp-reviewer`).

## Patterns détectés

| Type | Pattern (regex/heuristique) |
|---|---|
| AWS Access Key | `AKIA[0-9A-Z]{16}` |
| AWS Secret | base64 40 chars + contexte `aws_secret_access_key` |
| JWT | `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` |
| Stripe live key | `sk_live_[0-9a-zA-Z]{24,}` |
| GitHub PAT | `ghp_[A-Za-z0-9]{36}` |
| Google API key | `AIza[0-9A-Za-z\-_]{35}` |
| Private key block | `-----BEGIN (RSA |EC |DSA |OPENSSH |)PRIVATE KEY-----` |
| Generic high-entropy | string 32+ chars, base64/hex alphabet, > 4.0 bits/char Shannon entropy |
| Password in URL | `://[^/\s:]+:[^/\s@]+@` |
| `password=`, `secret=`, `token=`, `api[_-]?key=` assignments | regex sur contexte |

## Workflow

1. **Scanner** le contenu cible (string, fichier, glob).
2. **Pour chaque match** :
   - Logguer **localement** : type, chemin, ligne, **les 4 premiers + 4 derniers caractères** (jamais le secret en clair).
   - Remplacer dans l'output destiné à sortir par `«REDACTED:<TYPE>:<hash8>»` où `hash8` est les 8 premiers chars du SHA256 du secret (utile pour dédupliquer sans révéler).
3. **Si le secret est trouvé dans un fichier commité** (pas seulement un buffer en mémoire) :
   - Sévérité : **CRITICAL**.
   - Recommander : (a) révoquer le secret côté provider, (b) le retirer de l'historique git (`git filter-repo`), (c) le déplacer dans un vault.
4. **Toujours produire un résumé** : `n secret(s) detected, m redacted in output, k require rotation`.

## Faux positifs à éviter

- Exemples de doc explicitement marqués `EXAMPLE` / `dummy` / `fake`.
- UUIDs (entropie haute mais pas un secret).
- Hashes git, hashes de build, checksums.
- Schémas OpenAPI qui *décrivent* un format de token (pas une valeur réelle).

## Output format

```
## Secret scan
Scope: <fichiers ou buffer>

Findings:
- HIGH  src/main/resources/application-prod.yml:14  AWS_ACCESS_KEY  AKIA...XYZW  → REDACTED in report
- CRITICAL  prod-config/db.yml:3  PRIVATE_KEY_BLOCK  -----BEGIN... → rotate immediately, remove from git history

Summary: 2 detected, 2 redacted in output, 1 requires rotation.
```
