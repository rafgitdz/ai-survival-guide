#!/usr/bin/env bash
# pre-commit-docs-check.sh
#
# Hook PreToolUse — matché sur Bash quand la commande est `git commit ...`.
#
# Rôle : si le commit touche un fichier "significatif" (cf. liste ci-dessous)
# SANS qu'aucun ADR (docs/adr/*.md) ni README.md ne soit également staged,
# on bloque et on demande à Claude d'invoquer le skill `docs-curator`.
#
# Le skill va lire le diff, drafter un ADR + amender le README, stage les
# fichiers, puis Claude relance le commit — ce hook passera car la 2ème
# exécution verra l'ADR staged.
#
# Anti-boucle : si le diff staged ne contient QUE des fichiers de doc
# (`docs/adr/**` ou `README.md`), on laisse passer sans rien demander.
#
# Code de sortie 2 = bloquant (Claude voit le message stderr et agit).
# Code 0 = OK.

set -uo pipefail

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# On filtre : seuls les `git commit`.
if ! printf '%s' "$CMD" | grep -Eq '^[[:space:]]*git[[:space:]]+commit\b'; then
  exit 0
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

# Pas dans un repo git → on ne peut rien vérifier, on passe.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

STAGED="$(git diff --staged --name-only)"

# Aucun fichier staged → laisse passer (git refusera tout seul).
if [ -z "$STAGED" ]; then
  exit 0
fi

# Liste des patterns "significatifs" — DOIT rester en miroir avec
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

# Anti-boucle : si on ne commit QUE de la doc (le skill vient de poser
# l'ADR + README), on laisse passer.
if [ "$ONLY_DOCS" = "1" ]; then
  exit 0
fi

# Pas de changement significatif → on n'a rien à exiger.
if [ "$HAS_SIGNIFICANT" = "0" ]; then
  exit 0
fi

# Significatif ET (un ADR OU le README) staged → OK.
if [ "$HAS_ADR" = "1" ] || [ "$HAS_README" = "1" ]; then
  exit 0
fi

# Sinon on bloque avec un message structuré que Claude va lire et exécuter.
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
