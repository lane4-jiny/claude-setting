#!/bin/bash
# Inject git context for the current working directory at session start.
INPUT=$(cat 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"
cd "$CWD" 2>/dev/null || cd "$PWD"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

BRANCH=$(git branch --show-current 2>/dev/null)
COMMITS=$(git log --oneline -5 2>/dev/null)
STATUS=$(git status --short 2>/dev/null | head -10)

CTX="## Git Context (auto-injected)
**Branch:** ${BRANCH:-<detached>}

**Recent commits:**
${COMMITS:-<none>}"

if [ -n "$STATUS" ]; then
  CTX="${CTX}

**Modified files:**
${STATUS}"
fi

jq -nc --arg ctx "$CTX" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
