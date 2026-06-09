# ADR-0002: Ship the DB schema as a DDL dump, not a Flyway migration

- **Date**: 2026-06-09
- **Status**: Accepted
- **Deciders**: Backend team

## Context

`AGENTS.md §6` requires that agents read the **real** DB schema before modelling a DTO ("jamais supposer un schéma de base de données"). The demo therefore needs a schema artifact that ships with the repo and is reachable by skills (`openapi-designer`, `owasp-reviewer`).

The obvious choice was a real migration tool (Flyway or Liquibase). But the demo also runs `./mvnw test` at multiple checkpoints (contract tests, hook validation) **without** a live database. With Flyway on the classpath, Spring Boot autoconfigures a `DataSource` and fails at startup when no DB is reachable — which would break every demo step downstream.

## Decision

Ship the schema as a plain DDL file at `db/schema.sql`. Do **not** add Flyway / Liquibase to the build. Skills that need the schema read this file directly. Production deployments will introduce a real migration tool — out of scope for the demo.

## Consequences

### Positive

- `./mvnw test` runs with no DB and no autoconfig surprise.
- Skills can read the DDL with a single `Read` call — no tooling indirection.
- The pedagogical traps in `db/schema.sql` (e.g. `amount_cents` vs ticket's `amount`, missing `refunds` table) stay in plain SQL where they read clearly during the live demo.

### Negative

- The schema is not under migration discipline — no version, no rollback. A divergence between `db/schema.sql` and any future running DB would be silent.
- A real deployment will need a migration tool added later; the cutover is not free.

### Neutral

- The file header documents this choice and the planted traps inline, so a reader who lands on it from a skill won't be surprised.

## Alternatives considered

- **Flyway with `spring.flyway.enabled=false` in the test profile**: workable but adds two dependencies and a config knob just to neutralise them. Rejected for noise.
- **In-memory H2 + Flyway**: would force agents to read JPA entities instead of the DDL, which doesn't match the AGENTS.md §6 instruction to read the schema directly.

## Links

- File: `db/schema.sql`
- Rule: `AGENTS.md §6`
- Related: ADR-0001 (contract-first generation; the spec is the other half of the "no inventing" rule)
