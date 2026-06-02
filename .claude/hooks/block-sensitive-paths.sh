#!/usr/bin/env bash
# block-sensitive-paths.sh
# Déclenché par PreToolUse sur les outils Read/Edit/Write/MultiEdit/Bash.
# Rôle : interdire tout accès aux dossiers `prod-config/` et `secrets/`
#        (et fichiers .env, *.pem, *.key).
#
# Politique : DENY-LIST (defense in depth). Les permissions natives Claude Code
# devraient déjà bloquer, mais on double avec ce hook pour la démo.

set -uo pipefail

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"

# Récupère un "candidat chemin" selon l'outil
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
