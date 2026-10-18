#!/usr/bin/env bash
# pre-commit-docs-check.sh
#
# PreToolUse hook, matched on Bash when the command is `git commit ...`.
#
# Role: if the commit touches a "significant" file (see the list below)
# WITHOUT any ADR (docs/adr/*.md) or README.md staged as well, block and
# ask Claude to invoke the `docs-curator` skill.
#
# The skill reads the diff, drafts an ADR, amends the README and stages the
# files; Claude then runs the commit again, and this hook passes because the
# second run sees the staged ADR.
#
# Loop guard: if the staged diff contains ONLY documentation files
# (`docs/adr/**` or `README.md`), let it through without asking anything.
#
# Exit code 2 = blocking (Claude reads the stderr message and acts on it).
# Code 0 = OK.

set -uo pipefail

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Filter: `git commit` only.
if ! printf '%s' "$CMD" | grep -Eq '^[[:space:]]*git[[:space:]]+commit\b'; then
  exit 0
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

# Not in a git repository: nothing to check, let it through.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

STAGED="$(git diff --staged --name-only)"

# No staged file: let it through (git refuses on its own).
if [ -z "$STAGED" ]; then
  exit 0
fi

# "Significant" patterns: MUST stay in sync with
# .claude/skills/docs-curator/SKILL.md (section "What counts as significant").
is_significant() {
  case "$1" in
    openapi/*.yaml|openapi/*.yml)        return 0 ;;
    AGENTS.md)                            return 0 ;;
    .claude/agents/*)                     return 0 ;;
    .claude/skills/*)                     return 0 ;;
    .claude/hooks/*)                      return 0 ;;
    .claude/commands/*)                   return 0 ;;
    .mcp.json)                            return 0 ;;
    pom.xml)                              return 0 ;;
    db/*.sql)                             return 0 ;;
    .spectral.yml)                        return 0 ;;
  esac
  return 1
}

is_doc() {
  case "$1" in
    docs/adr/*.md) return 0 ;;
    README.md)     return 0 ;;
  esac
  return 1
}

HAS_SIGNIFICANT=0
HAS_ADR=0
HAS_README=0
ONLY_DOCS=1
SIGNIFICANT_LIST=""

while IFS= read -r f; do
  [ -z "$f" ] && continue
  if is_significant "$f"; then
    HAS_SIGNIFICANT=1
    SIGNIFICANT_LIST="${SIGNIFICANT_LIST}  - $f"$'\n'
  fi
  if [ "$f" = "README.md" ]; then HAS_README=1; fi
  case "$f" in
    docs/adr/[0-9]*-*.md) HAS_ADR=1 ;;
  esac
  if ! is_doc "$f"; then ONLY_DOCS=0; fi
done <<< "$STAGED"

# Loop guard: if only documentation is committed (the skill has just added
# the ADR + README), let it through.
if [ "$ONLY_DOCS" = "1" ]; then
  exit 0
fi

# No significant change: nothing to require.
if [ "$HAS_SIGNIFICANT" = "0" ]; then
  exit 0
fi

# Significant AND (an ADR OR the README) staged: OK.
if [ "$HAS_ADR" = "1" ] || [ "$HAS_README" = "1" ]; then
  exit 0
fi

# Otherwise block with a structured message that Claude reads and executes.
cat >&2 <<EOF
[pre-commit-docs-check] BLOCKED

Significant files are staged but no ADR (docs/adr/*.md) nor README.md update is staged.

Significant files in this commit:
${SIGNIFICANT_LIST}
Required action before retrying the commit:
  Invoke the skill \`docs-curator\` on the staged diff.
  The skill will (1) draft an ADR under docs/adr/, (2) amend README.md
  if user-visible surface changed, (3) git add the new/modified docs.
  Then retry the same commit — this hook will pass.

This rule comes from the team convention: every significant change must
explain itself. See .claude/skills/docs-curator/SKILL.md for details.
EOF
exit 2
