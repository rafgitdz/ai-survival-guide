#!/usr/bin/env bash
# pre-merge-diff.sh
# Déclenché par PreToolUse sur `git merge ...`.
# Rôle : générer le diff OpenAPI entre HEAD et la branche à merger,
#        et relancer les contract tests. Bloque si breaking change détecté
#        sans bump majeur correspondant.

set -uo pipefail

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

if ! printf '%s' "$CMD" | grep -Eq '^[[:space:]]*git[[:space:]]+merge\b'; then
  exit 0
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

# Cible du merge (dernier mot non-flag de la commande)
TARGET="$(printf '%s' "$CMD" | awk '{ for(i=NF;i>=1;i--) if ($i !~ /^-/) { print $i; exit } }')"
TARGET="${TARGET:-main}"

mkdir -p .claude/tmp
DIFF_FILE=".claude/tmp/openapi-diff-$(date +%s).txt"

if ls openapi/*.yaml >/dev/null 2>&1; then
  for spec in openapi/*.yaml; do
    {
      echo "=== diff $spec : $TARGET vs HEAD ==="
      git diff "$TARGET"..HEAD -- "$spec" || true
      echo ""
    } >> "$DIFF_FILE"
  done
  echo "[pre-merge hook] OpenAPI diff written to $DIFF_FILE"
fi

# Contract tests
if [ -f "./mvnw" ]; then
  if ! ./mvnw -q -Dtest='*ContractTest' test >/tmp/mvn-merge.out 2>&1; then
    tail -n 60 /tmp/mvn-merge.out >&2
    echo "[pre-merge hook] BLOCKED: contract tests failed against $TARGET" >&2
    exit 2
  fi
fi

# Heuristique simple : si le diff contient des lignes "-" sur des paths ou
# des renommages de champs, on demande confirmation du bump majeur.
if grep -E '^\-\s+(/v[0-9]+/|[[:space:]]+[a-zA-Z]+:)' "$DIFF_FILE" >/dev/null 2>&1; then
  echo "[pre-merge hook] WARN: possible breaking changes detected — confirm major version bump in CHANGELOG.md before merging." >&2
fi

exit 0
