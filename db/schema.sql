-- db/schema.sql
-- Teaching fixture for the DESIGN use case.
--
-- Deliberately not a real Flyway/Liquibase migration (otherwise Spring Boot
-- auto-configures the DataSource and fails at startup). It is a DDL DUMP that
-- the skills must read to comply with AGENTS.md §6:
--   "never assume a database schema without reading it".
--
-- Traps planted to force a live "the agent asks a question" moment:
--   1) `amount_cents` (DB) vs `amount` (ticket API-1247)  → business vs technical naming
--   2) `currency_iso` (DB) vs `currency` (ticket)          → same
--   3) The `refunds` table DOES NOT EXIST. It is the subject of the ticket.
--      The agent must notice and propose a DDL, or ask.
--
-- Keep this file in its starting state: the expected output of the demo lives
-- in examples/design-output/.

CREATE TABLE payments (
    id            UUID         PRIMARY KEY,
    amount_cents  BIGINT       NOT NULL,
    currency_iso  CHAR(3)      NOT NULL,
    status        VARCHAR(20)  NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    customer_id   UUID         NOT NULL
);

CREATE INDEX idx_payments_customer ON payments(customer_id);
CREATE INDEX idx_payments_status   ON payments(status);
