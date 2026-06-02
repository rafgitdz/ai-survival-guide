---
description: Lance un audit sécurité complet (use case 3 — SECURE) via le subagent security-audit-agent.
argument-hint: "[chemin de spec optionnel, par défaut openapi/payments.yaml]"
---

Lance le subagent `security-audit-agent` avec la consigne suivante :

> Audit cible : `openapi/payments.yaml` (ou `$ARGUMENTS` si fourni) + tout
> `src/main/java/com/franceapi/demo/`. Suis exactement le workflow décrit dans
> ton system prompt : Phase 1 scope → Phase 2 skills → Phase 3 rapport consolidé
> → Phase 4 propositions de patches (NE PAS APPLIQUER).

Le hook `post-audit-report.sh` capturera automatiquement ton rapport final.
