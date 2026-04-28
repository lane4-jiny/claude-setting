#!/bin/bash
REMINDER="COMPACTION REMINDER — when summarizing this conversation, preserve:
1. Current task progress and remaining TodoWrite items
2. User feedback, corrections, and validated approaches from this session
3. File paths being worked on with their current state
4. Key technical decisions and the reasoning behind them
5. In-flight investigations, hypotheses being tested, blockers encountered
Drop verbose tool output and resolved sub-tasks. Keep code paths and configuration values verbatim."

jq -nc --arg ctx "$REMINDER" '{hookSpecificOutput: {hookEventName: "PreCompact", additionalContext: $ctx}}'
