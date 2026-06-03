-- db/schema.sql
-- Fixture pédagogique pour la démo France API 2026 — use case DESIGN.
--
-- Pas une vraie migration Flyway/Liquibase volontairement (sinon Spring Boot
-- autoconfigure le DataSource et plante au démarrage). C'est un DUMP DDL
-- que les skills doivent lire pour respecter AGENTS.md §6 :
--   "jamais supposer un schéma de base de données sans le lire".
--
-- Pièges plantés pour forcer un moment "agent qui pose une question" en live :
--   1) `amount_cents` (DB) vs `amount` (ticket API-1247)  → choix nommage business/technique
--   2) `currency_iso` (DB) vs `currency` (ticket)          → idem
--   3) La table `refunds` N'EXISTE PAS. C'est l'objet du ticket.
--      L'agent doit le constater et proposer un DDL ou demander.

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

-- Table `refunds` : ajoutée dans le cadre du ticket API-1247.
-- DDL proposé par l'agent openapi-designer, à VALIDER par un humain
-- avant merge (cf. AGENTS.md §6 — jamais inventer un schéma sans validation).
-- Choix de nommage : colonnes en snake_case + suffixes techniques
-- (`amount_cents`, `currency_iso`) pour rester cohérent avec la table `payments`.
-- L'API expose les noms business (`amount`, `currency`) — voir openapi/refunds.yaml.

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
