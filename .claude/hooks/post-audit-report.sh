#!/usr/bin/env bash
# post-audit-report.sh
# Triggered by SubagentStop, matched on the `security-audit-agent` subagent.
# Role:
#   1) Persist the latest audit report under docs/audits/audit-<timestamp>.md
#   2) If the environment has a real integration (MCP issue tracker, gh CLI),
#      open one issue per CRITICAL/HIGH finding.
#
# The hook receives the Claude Code SubagentStop JSON (Claude Code 2.1):
# { "agent_type": "security-audit-agent", "agent_id": "...",
#   "last_assistant_message": "<final report>", "transcript_path": "...", ... }

set -uo pipefail

INPUT="$(cat)"
SUBAGENT="$(printf '%s' "$INPUT" | jq -r '.agent_type // .subagent_name // .agent_name // ""')"
TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // .transcript_path // ""')"
LAST_MESSAGE="$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""')"

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
  if [ -n "$LAST_MESSAGE" ]; then
    # Claude Code hands the final report directly (preferred: the transcript may lag).
    printf '%s\n' "$LAST_MESSAGE"
  elif [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    # Fallback: extract the last assistant message from the JSONL transcript.
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
