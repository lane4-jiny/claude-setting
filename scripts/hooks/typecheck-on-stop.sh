#!/bin/bash
# Stop hook — runs `tsc --noEmit` on lane4 projects with uncommitted .ts changes.
# Skips silently when no errors. On error: emits JSON with systemMessage.
#
# Strategy:
#   - For each lane4 repo with .ts/.tsx diffs, run tsc.
#   - Prefer tsconfig.build.json when present (NestJS convention excludes spec files
#     to avoid noise from missing @types/jest etc.).
#   - Run repos in parallel; total wall time ≈ slowest project.
#   - Stop hook schema does NOT support hookSpecificOutput.additionalContext, so
#     errors are emitted in systemMessage only.

source "$HOME/.claude/scripts/impact/lib/repos.sh" 2>/dev/null
[ -z "${LANE4_REPOS_EXISTING:-}" ] && exit 0

ERROR_LOG=$(mktemp)
FULL_LOG="$HOME/.claude/typecheck-last.log"
trap 'rm -f "$ERROR_LOG"' EXIT

run_tsc() {
  local repo="$1"
  local name
  name=$(basename "$repo")

  [ -d "$repo/.git" ] || return
  cd "$repo" 2>/dev/null || return

  # Any .ts/.tsx changes (staged or unstaged)?
  local changes staged
  changes=$(git diff --name-only -- '*.ts' '*.tsx' 2>/dev/null)
  staged=$(git diff --cached --name-only -- '*.ts' '*.tsx' 2>/dev/null)
  [ -z "$changes" ] && [ -z "$staged" ] && return

  # Project must have local tsc
  local TSC_BIN="$repo/node_modules/.bin/tsc"
  [ -x "$TSC_BIN" ] || return

  # Prefer tsconfig.build.json (NestJS excludes specs there); fall back to default.
  local TS_ARGS=()
  if [ -f "$repo/tsconfig.build.json" ]; then
    TS_ARGS=(-p tsconfig.build.json)
  fi

  # Run tsc with timeout if available, otherwise direct.
  local output rc
  if command -v timeout >/dev/null 2>&1; then
    output=$(timeout 30 "$TSC_BIN" "${TS_ARGS[@]}" --noEmit 2>&1)
  elif command -v gtimeout >/dev/null 2>&1; then
    output=$(gtimeout 30 "$TSC_BIN" "${TS_ARGS[@]}" --noEmit 2>&1)
  else
    output=$("$TSC_BIN" "${TS_ARGS[@]}" --noEmit 2>&1)
  fi
  rc=$?

  if [ $rc -ne 0 ]; then
    # Filter out spec/test file errors as a second safety net (in case tsconfig.build
    # didn't exclude them or the project doesn't use that convention).
    local filtered
    filtered=$(echo "$output" | grep -vE '\.(spec|test|e2e-spec)\.tsx?\(')

    # If after filtering there's nothing, this project is OK (only spec errors).
    if [ -z "$filtered" ]; then
      return
    fi

    {
      echo "===== $name ====="
      echo "$filtered" | head -20
      echo ""
    } >> "$ERROR_LOG"
  fi
}

# Run all repos in parallel
for repo in "${LANE4_REPOS_EXISTING[@]}"; do
  run_tsc "$repo" &
done
wait

# Always overwrite the full log for later inspection
cp "$ERROR_LOG" "$FULL_LOG" 2>/dev/null

if [ -s "$ERROR_LOG" ]; then
  # Truncate to keep systemMessage reasonable; full log lives at $FULL_LOG.
  ERRORS=$(head -c 4000 "$ERROR_LOG")
  COUNT=$(grep -c '^=====' "$ERROR_LOG")
  jq -nc \
    --arg msg "타입체크: ${COUNT}개 프로젝트 오류 — 상세는 ~/.claude/typecheck-last.log
$ERRORS" \
    '{systemMessage: $msg}'
fi

exit 0
