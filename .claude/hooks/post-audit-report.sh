#!/usr/bin/env bash
# post-audit-report.sh
# Triggered by SubagentStop, matched on the `security-audit-agent` subagent.
# Role:
#   1) Persist the latest audit report under docs/audits/audit-<timestamp>.md
#   2) If the environment has a real integration (MCP issue tracker, gh CLI),
#      open one issue per CRITICAL/HIGH finding.
#
# The hook receives the Claude Code subagent-stop JSON:
# { "subagent_name": "...", "transcript_path": "...", ... }

set -uo pipefail

INPUT="$(cat)"
SUBAGENT="$(printf '%s' "$INPUT" | jq -r '.subagent_name // .agent_name // ""')"
TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""')"

# Only act for our agent
if [ "$SUBAGENT" != "security-audit-agent" ]; then
  exit 0
fi

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

mkdir -p docs/audits
TS="$(date +%Y%m%d-%H%M%S)"
OUT="docs/audits/audit-$TS.md"

{
  echo "# Security audit — $TS"
  echo ""
  echo "_Captured automatically by post-audit-report hook from subagent \`security-audit-agent\`._"
  echo ""
  if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    # On extrait le dernier message assistant du transcript JSONL.
    jq -r 'select(.type=="assistant" or .role=="assistant") | .message.content // .content // empty
           | if type=="array" then map(.text // empty) | join("\n") else . end' \
       "$TRANSCRIPT" 2>/dev/null | tail -n 400
  else
    echo "(transcript unavailable — paste audit manually)"
  fi
} > "$OUT"

echo "[post-audit] Report persisted to $OUT" >&2

# Issue creation: best effort, never blocks.
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  grep -E '^- \[(CRITICAL|HIGH)\]' "$OUT" 2>/dev/null | while IFS= read -r line; do
    title="$(printf '%s' "$line" | sed -E 's/^- //; s/[[:space:]]+/ /g' | cut -c1-100)"
    gh issue create --title "[security] $title" --body "Source audit: $OUT" --label security >/dev/null 2>&1 \
      && echo "[post-audit] issue opened: $title" >&2
  done
fi

exit 0
