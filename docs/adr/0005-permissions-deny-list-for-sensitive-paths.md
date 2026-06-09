# ADR-0005: Lock down sensitive paths via deny-list + a duplicate hook

- **Date**: 2026-06-09
- **Status**: Accepted
- **Deciders**: Backend team, Security

## Context

`AGENTS.md §8` mandates "pas de secret en clair dans le repo". The demo repo ships two folders that simulate sensitive content (`prod-config/`, `secrets/`) plus generic credential file shapes (`.env`, `*.pem`, `*.key`, `id_rsa`, `id_ed25519`). Agents — including helpful ones — must not be able to read, edit, or write these, even by accident or via creative file paths.

Claude Code has two independent mechanisms to prevent this: the `permissions` block in `.claude/settings.json` and PreToolUse hooks. Either alone is a single point of failure (a misconfigured `permissions` allow rule; a typo in the hook regex). Both together fail closed.

## Decision

Apply the deny twice:

1. **`.claude/settings.json` `permissions.deny`**: a list of `Read(...)`, `Edit(...)`, `Write(...)` patterns covering `prod-config/**`, `secrets/**`, `**/.env`, `**/*.pem`, `**/*.key`. Plus three destructive `Bash` patterns: `rm -rf:*`, `git push --force:*`, `git push -f:*`.
2. **`.claude/hooks/block-sensitive-paths.sh`**: a PreToolUse hook matched on `Read|Edit|Write|MultiEdit|NotebookEdit|Bash` that regex-checks the file path or command for the same set, plus `id_rsa` / `id_ed25519`. Exits 2 (blocks) on match.

The `permissions.allow` list explicitly enumerates which directories the agent **may** touch (`openapi/`, `src/`, `tickets/`, `db/`, `docs/`, `README.md`) — narrower than default, by design.

## Consequences

### Positive

- Defense in depth: a permissions rule typo no longer leads to a leak.
- The destructive `Bash` denies (force-push, `rm -rf`) extend the same model to outbound damage, not just inbound secrets.
- The allow-list is small and readable — easy to audit.

### Negative

- A new sensitive folder pattern must be added in two places (settings + hook). Drift means the hook still protects, but the settings UI shows the path as readable, which is misleading.
- A legitimate need to touch `prod-config/` (e.g. a future config-schema audit) requires changing both layers.

### Neutral

- The pedagogical demo step "ask Claude to read `prod-config/db.yml` → watch it refuse" demonstrates both layers firing.

## Alternatives considered

- **Allow-list only (no hook)**: simpler, but leaves no audit trail when an agent attempts a denied path — the hook logs the attempt to stderr.
- **Hook only (no permissions)**: would still let the UI surface the path as readable to the model's context window before the hook fires. Rejected — defense in depth.
- **`.gitignore` / file-system permissions**: orthogonal — they protect the file at rest, not the agent's tool calls. Kept as well, but not a substitute.

## Links

- Config: `.claude/settings.json` (`permissions.deny`, `permissions.allow`)
- Hook: `.claude/hooks/block-sensitive-paths.sh`
- Rule: `AGENTS.md §8`
