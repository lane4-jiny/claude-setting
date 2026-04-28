#!/bin/bash
# Stop hook: macOS notification + sound + ntfy push, with brief session summary.
#
# Reads session_id from hook input, finds the transcript JSONL, extracts the last
# assistant text response, and includes a truncated snippet in the notification body.
#
# Privacy note: ntfy.sh topics are public (only obscured by random topic name).
# Snippet is truncated to ~180 chars and obvious secrets are not specifically filtered —
# don't run this hook for sessions where you handle sensitive data.

# 1) Read hook input synchronously (so notifications can include the summary).
INPUT=$(cat 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

# 2) Build summary from last assistant text in the transcript.
SUMMARY=""
if [ -n "$SESSION_ID" ]; then
  TRANSCRIPT=$(find "$HOME/.claude/projects" -name "${SESSION_ID}.jsonl" -type f 2>/dev/null | head -1)
  if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    SUMMARY=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$TRANSCRIPT" 2>/dev/null \
      | tail -1 \
      | tr '\n' ' ' \
      | sed 's/  */ /g' \
      | cut -c1-180)
  fi
fi

# Fallback message
[ -z "$SUMMARY" ] && SUMMARY="응답 도착"

HOST=$(hostname -s)

# 3) macOS notification (visible regardless of mute)
osascript -e "display notification \"${SUMMARY//\"/\\\"}\" with title \"Claude Code\" sound name \"Glass\"" 2>/dev/null &

# 4) System sound (no-op when muted)
afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &

# 5) ntfy.sh push (silent fail if offline or topic missing)
TOPIC_FILE="$HOME/.claude/ntfy-topic"
if [ -f "$TOPIC_FILE" ]; then
  TOPIC=$(cat "$TOPIC_FILE")
  curl -fsS --max-time 3 \
    -H "Title: Claude Code [$HOST]" \
    -H "Tags: white_check_mark" \
    -H "Priority: default" \
    -d "$SUMMARY" \
    "https://ntfy.sh/$TOPIC" >/dev/null 2>&1 &
fi

exit 0
