---
description: Runs a full security audit (use case 3, SECURE) through the security-audit-agent subagent.
argument-hint: "[optional spec path, defaults to openapi/payments.yaml]"
---

Run the `security-audit-agent` subagent with the following instruction:

> Audit target: `openapi/payments.yaml` (or `$ARGUMENTS` if provided) + all of
> `src/main/java/com/franceapi/demo/`. Follow exactly the workflow described in
> your system prompt: Phase 1 scope → Phase 2 skills → Phase 3 consolidated
> report → Phase 4 patch proposals (DO NOT APPLY).

The `post-audit-report.sh` hook captures your final report automatically.
