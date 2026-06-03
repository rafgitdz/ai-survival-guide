#!/usr/bin/env bash
# pre-commit-openapi.sh
# Déclenché par PreToolUse quand Claude s'apprête à exécuter `git commit ...`.
# Rôle : refuser le commit si la spec OpenAPI ne passe pas spectral OU si les
#        contract tests échouent.
#
# Le hook reçoit sur stdin un JSON Claude Code:
#   { "tool_name": "Bash", "tool_input": { "command": "..." }, ... }
# On regarde si la commande est un `git commit`. Sinon on passe.
#
# Code de sortie 2 = bloquant (Claude voit le message stderr).
# Code 0 = OK.

set -uo pipefail

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# On filtre : seuls les `git commit` (pas `git status`, `git log`, ...).
if ! printf '%s' "$CMD" | grep -Eq '^[[:space:]]*git[[:space:]]+commit\b'; then
  exit 0
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

fail() {
  echo "[pre-commit hook] BLOCKED: $1" >&2
  exit 2
}

# 1) Spectral lint sur toutes les specs OpenAPI sous openapi/
# NOTE: openapi/payments.yaml est volontairement imparfaite (use cases SECURE
# et AUDIT). Elle est exclue du lint bloquant — les défauts plantés sont
# justement ce que la démo doit faire trouver.
if ls openapi/*.yaml >/dev/null 2>&1; then
  if command -v spectral >/dev/null 2>&1; then
    for spec in openapi/*.yaml; do
      case "$spec" in
        openapi/payments.yaml) continue ;;
      esac
      if ! spectral lint --ruleset .spectral.yml --fail-severity=error "$spec" >/tmp/spectral.out 2>&1; then
        cat /tmp/spectral.out >&2
        fail "spectral lint failed on $spec"
      fi
    done
  else
    echo "[pre-commit hook] WARN: spectral not installed — skipping lint." >&2
  fi
fi

# 2) Contract tests
if [ -f "./mvnw" ]; then
  if ! ./mvnw -q -DskipITs=false -Dtest='*ContractTest' test >/tmp/mvn.out 2>&1; then
    tail -n 60 /tmp/mvn.out >&2
    fail "contract tests failed"
  fi
fi

echo "[pre-commit hook] OK — spec lint + contract tests passed."
exit 0
