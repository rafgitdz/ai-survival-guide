#!/usr/bin/env bash
# block-sensitive-paths.sh
# Triggered by PreToolUse on the Read/Edit/Write/MultiEdit/Bash tools.
# Role: deny any access to the `prod-config/` and `secrets/` folders
#       (and to .env, *.pem, *.key files).
#
# Policy: DENY-LIST (defense in depth). Claude Code's native permissions
# should already block these, but this hook doubles them for the demo.

set -uo pipefail

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"

# Extract a "candidate path" depending on the tool
PATHS=""
case "$TOOL" in
  Read|Edit|Write|MultiEdit|NotebookEdit)
    PATHS="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""')"
    ;;
  Bash)
    PATHS="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"
    ;;
  *)
    exit 0
    ;;
esac

is_blocked() {
  local s="$1"
  printf '%s' "$s" | grep -Eq '(^|[[:space:]/"'"'"'])((\./)?(prod-config|secrets)(/|$))' && return 0
  printf '%s' "$s" | grep -Eq '(\.env(\.|$)|\.pem(\s|$|")|\.key(\s|$|")|id_rsa|id_ed25519)' && return 0
  return 1
}

if is_blocked "$PATHS"; then
  echo "[block-sensitive-paths] DENY: access to prod-config/, secrets/, or credential files is forbidden by AGENTS.md §8. Tool: $TOOL." >&2
  exit 2
fi

exit 0
