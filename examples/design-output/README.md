# Expected output of use case 1 (DESIGN)

`schema-refunds.sql` is the DDL that the `openapi-designer` skill proposed for
ticket [API-1247](../../tickets/API-1247.md) during a rehearsal, once the human
had answered its questions (business names `amount` and `currency` in the
contract, technical names kept in the database).

It is kept here, outside `db/`, so that the starting state of the demo stays
intact: `db/schema.sql` must not contain a `refunds` table, otherwise the agent
has nothing to ask about.

Use it to compare a live run against a known good answer, or as a fallback if a
demo goes wrong on stage.
