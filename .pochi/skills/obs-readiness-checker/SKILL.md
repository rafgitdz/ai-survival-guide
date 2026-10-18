---
name: obs-readiness-checker
description: Checks that a Spring Boot API is observable as defined in AGENTS.md §7: Prometheus metrics exposed, distributed tracing configured, structured JSON logs. Outputs a report per dimension with evidence and fix. Use before every release, and systematically when a new route is added.
---

# obs-readiness-checker

## When to use

- Before a release or a merge.
- A new route is exposed (check that it inherits the HTTP metrics).
- Audit requested by the SRE team.

**Do not use** for: security (use `owasp-reviewer`), spec consistency (use `openapi-consistency-auditor`).

## Three dimensions to check

### A. Prometheus metrics

Expected evidence:

- `pom.xml` (or `build.gradle`) declares `micrometer-registry-prometheus`.
- `application.yml` (or `application.properties`) sets `management.endpoints.web.exposure.include` to include `prometheus,health,info,metrics`.
- `/actuator/prometheus` is referenced and exposed.
- No `@RestController` disables HTTP metrics (e.g. `@Timed(enabled=false)`).

### B. Distributed tracing

Expected evidence:

- `pom.xml` declares `micrometer-tracing-bridge-otel` or `micrometer-tracing-bridge-brave`.
- An active exporter (`opentelemetry-exporter-otlp` / `zipkin-reporter-brave`).
- `management.tracing.sampling.probability` configured (> 0).
- W3C `traceparent` propagation enabled. It is the Micrometer + OTel default, but check that no configuration disables it.

### C. Structured logs

Expected evidence:

- A JSON encoder is configured: `logstash-logback-encoder` or `LogbackJsonEncoder`, OR `spring.main.banner-mode: off` + `logging.structured.format.console: ecs/gelf/logstash` (Spring Boot 3.4+).
- The `traceId` and `spanId` MDC fields are injected into every log line (check the logback pattern).
- No `log.info(payload)` on an entity that may contain PII or secrets; delegate doubtful fields to `secret-scrubber`.

## Workflow

1. **List**: `pom.xml`, `application*.yml`, `logback*.xml`, `SecurityConfig`, controllers.
2. **For each dimension A/B/C**, go through the expected evidence.
3. **For each missing piece of evidence**, output a finding: `[A|B|C] <evidence> missing → <precise fix>`.
4. **Verdict**: `PASS` if A, B and C are all green. Otherwise `FAIL` + the failing dimensions.

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
FAIL: A, B (partial), C missing. Not release-ready per AGENTS.md §7.
```
