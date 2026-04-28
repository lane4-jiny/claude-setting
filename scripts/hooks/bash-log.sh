#!/bin/bash
LOG_FILE="$HOME/.claude/bash-log.txt"
INPUT=$(cat)
TS=$(date '+%Y-%m-%d %H:%M:%S')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
SESSION=$(echo "$INPUT" | jq -r '.session_id // "?"' | cut -c1-8)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' | sed "s|^$HOME|~|")
[ -n "$CMD" ] && printf '%s [%s] (%s) %s\n' "$TS" "$SESSION" "$CWD" "$CMD" >> "$LOG_FILE"
exit 0
