-- db/schema.sql
-- DDL dump of the payments service database (current production state).
-- Not a Flyway/Liquibase migration: see docs/adr/0002.

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
