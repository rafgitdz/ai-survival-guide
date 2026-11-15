---
name: "obs-readiness-checker"
description: "Checks that a Spring Boot API is observable as defined in AGENTS.md §7: Prometheus metrics exposed, distributed tracing configured, structured JSON logs. Outputs a report per dimension with evidence and fix. Use before every release, and systematically when a new route is added."
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

**Verdict rules (mechanical, no judgement call):**

- **A is OK** only if `micrometer-registry-prometheus` is in `pom.xml` AND `prometheus` is in `management.endpoints.web.exposure.include`.
- **B is OK** only if `pom.xml` declares a tracing bridge (`micrometer-tracing-bridge-otel` or `-brave`) AND an exporter. `management.tracing.*` properties alone, without the dependencies, mean **B is MISSING**: Spring Boot ignores them.
- **C is OK** only if a JSON encoder or `logging.structured.format.*` is configured. A `logging.pattern.console` line, even with `traceId`/`spanId`, is plain text, so **C is MISSING**.
- You must quote the `pom.xml` line (or state its absence after reading the whole file) for A and B. Configuration files are never sufficient evidence on their own.

## Workflow

1. **List**: `pom.xml`, `application*.yml`, `logback*.xml`, `SecurityConfig`, controllers.
2. **For each dimension A/B/C**, go through the expected evidence.
3. **For each missing piece of evidence**, output a finding: `[A|B|C] <evidence> missing → <precise fix>`.
4. **Verdict**: `PASS` if A, B and C are all green. Otherwise `FAIL` + the failing dimensions.

## Output format

**The block below is a FORMAT template, not a result.** Every line you output must come from a file you actually read in this run, with its evidence (`file:line` or the exact key/dependency). Never reuse the placeholder text; if a dimension has no finding, say `none found` and cite what you checked.

```
## Observability readiness
Scope: <files actually read>

### A. Metrics (Prometheus)
- [<OK | MISSING>] <dependency or property checked> (evidence: <file:line>) → <fix if missing>

### B. Tracing
- [<OK | MISSING>] <dependency or property checked> (evidence: <file:line>) → <fix if missing>

### C. Structured logs
- [<OK | MISSING>] <encoder or config checked> (evidence: <file:line>) → <fix if missing>

### Verdict
<PASS | FAIL>: <which dimensions are OK / missing>. <one sentence per AGENTS.md §7>
```
