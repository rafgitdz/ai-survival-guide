-- examples/design-output/schema-refunds.sql
-- Reference output of use case 1 (DESIGN): the `refunds` DDL proposed by the
-- openapi-designer skill for ticket API-1247, after a human validated it
-- (AGENTS.md §6: never invent a schema without validation).
-- Naming choice: snake_case columns with technical suffixes
-- (`amount_cents`, `currency_iso`), consistent with the `payments` table.

CREATE TABLE refunds (
    id            UUID         PRIMARY KEY,
    payment_id    UUID         NOT NULL REFERENCES payments(id),
    amount_cents  BIGINT       NOT NULL CHECK (amount_cents > 0),
    currency_iso  CHAR(3)      NOT NULL,
    status        VARCHAR(20)  NOT NULL,
    reason        VARCHAR(280),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refunds_payment ON refunds(payment_id);
CREATE INDEX idx_refunds_status  ON refunds(status);
