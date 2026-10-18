# Expected output of use case 1 (DESIGN)

What the `openapi-designer` skill produced for ticket
[API-1247](../../tickets/API-1247.md) during a rehearsal, once the human had
answered its questions:

| File | Content |
|---|---|
| [`refunds.yaml`](./refunds.yaml) | The `POST /v1/refunds` contract, in a dedicated spec |
| [`schema-refunds.sql`](./schema-refunds.sql) | The `refunds` table DDL proposed alongside |

In that run, the human chose the database names (`amountCents`,
`currencyIso`) over the ticket's business names (`amount`, `currency`), for
consistency with the existing `payments` table. Both answers are valid: what
the demo shows is that the agent **asks** instead of choosing alone. Expect the
live output to follow whatever you answer on stage.

These files are kept here, outside `openapi/` and `db/`, so that the starting
state of the demo stays intact: `db/schema.sql` must not contain a `refunds`
table, otherwise the agent has nothing to ask about.

Use them to compare a live run against a known answer, or as a fallback if a
demo goes wrong on stage.
