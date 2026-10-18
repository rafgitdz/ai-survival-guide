#!/usr/bin/env bash
# pre-commit-openapi.sh
# Triggered by PreToolUse when Claude is about to run `git commit ...`.
# Role: refuse the commit if the OpenAPI spec fails Spectral OR if the
#       contract tests fail.
#
# The hook receives a Claude Code JSON on stdin:
#   { "tool_name": "Bash", "tool_input": { "command": "..." }, ... }
# Check whether the command is a `git commit`. Otherwise let it through.
#
# Exit code 2 = blocking (Claude reads the stderr message).
# Code 0 = OK.

set -uo pipefail

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# Filter: `git commit` only (not `git status`, `git log`, ...).
if ! printf '%s' "$CMD" | grep -Eq '^[[:space:]]*git[[:space:]]+commit\b'; then
  exit 0
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

fail() {
  echo "[pre-commit hook] BLOCKED: $1" >&2
  exit 2
}

# 1) Spectral lint on every OpenAPI spec under openapi/
# NOTE: openapi/payments.yaml is deliberately flawed (SECURE and AUDIT use
# cases). It is excluded from the blocking lint: the planted defects are
# exactly what the demo must surface.
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
