---
name: obs-readiness-checker
description: Vérifie qu'une API Spring Boot est observable au sens de AGENTS.md §7 — métriques Prometheus exposées, traces distribuées configurées, logs structurés JSON. Sort un rapport par dimension avec preuve et fix. Utiliser avant tout release, et systématiquement quand une nouvelle route est ajoutée.
---

# obs-readiness-checker

## When to use

- Pré-release ou pré-merge.
- Une nouvelle route est exposée (vérifier qu'elle hérite bien des métriques HTTP).
- Audit demandé par l'équipe SRE.

**Ne pas utiliser** pour : sécurité (→ `owasp-reviewer`), cohérence de spec (→ `openapi-consistency-auditor`).

## Trois dimensions à vérifier

### A. Métriques Prometheus

Preuves attendues :

- `pom.xml` (ou `build.gradle`) déclare `micrometer-registry-prometheus`.
- `application.yml` (ou `application.properties`) expose `management.endpoints.web.exposure.include` incluant `prometheus,health,info,metrics`.
- `/actuator/prometheus` est référencé / exposé.
- Pas d'`@RestController` qui désactive les metrics HTTP (ex: `@Timed(enabled=false)`).

### B. Traces distribuées

Preuves attendues :

- `pom.xml` déclare `micrometer-tracing-bridge-otel` ou `micrometer-tracing-bridge-brave`.
- Un exporter actif (`opentelemetry-exporter-otlp` / `zipkin-reporter-brave`).
- `management.tracing.sampling.probability` configuré (> 0).
- Propagation `traceparent` (W3C) activée — c'est le défaut Micrometer + OTel, mais vérifier qu'aucune config ne la désactive.

### C. Logs structurés

Preuves attendues :

- Un encoder JSON est configuré : `logstash-logback-encoder` ou `LogbackJsonEncoder`, OU `spring.main.banner-mode: off` + `logging.structured.format.console: ecs/gelf/logstash` (Spring Boot 3.4+).
- Les MDC fields `traceId` et `spanId` sont injectés dans chaque log (vérifier le pattern logback).
- Pas de `log.info(payload)` sur une entité contenant potentiellement des PII / secrets — déléguer au `secret-scrubber` pour les champs douteux.

## Workflow

1. **Lister** : `pom.xml`, `application*.yml`, `logback*.xml`, `SecurityConfig`, contrôleurs.
2. **Pour chaque dimension A/B/C**, dérouler les preuves attendues.
3. **Pour chaque preuve manquante**, produire un finding `[A|B|C] <preuve> manquant → <fix précis>`.
4. **Verdict** : `PASS` si A et B et C verts. Sinon `FAIL` + dimensions en échec.

## Output format

```
## Observability readiness
Scope: pom.xml, src/main/resources/**, src/main/java/com/franceapi/demo/**

### A. Metrics (Prometheus)
- [MISSING] micrometer-registry-prometheus not in pom.xml → add dependency.
- [MISSING] management.endpoints.web.exposure.include does not list 'prometheus' → set to 'health,info,prometheus,metrics'.

### B. Tracing
- [OK] micrometer-tracing-bridge-otel present.
- [MISSING] management.tracing.sampling.probability not set → set to 1.0 in dev, 0.1 in prod.

### C. Structured logs
- [MISSING] No JSON encoder → add logstash-logback-encoder + logback-spring.xml with JSON pattern.

### Verdict
FAIL — A, B (partial), C missing. Not release-ready per AGENTS.md §7.
```
