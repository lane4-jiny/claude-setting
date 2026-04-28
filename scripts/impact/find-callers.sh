#!/bin/bash
# Find usages of a symbol or string across all Lane4 repos.
#
# Usage:
#   find-callers.sh <pattern> [--type ts|tsx|xml|all] [--exclude <repo-name>] [--word]
#
# Examples:
#   find-callers.sh "DateTimeUtils.formatKr"
#   find-callers.sh "begin-driving" --type ts
#   find-callers.sh "ServiceType" --word --exclude lane4-backend-library
#
# Output: file:line:context (one per line)

set -e

if [ $# -eq 0 ]; then
  sed -n '2,14p' "$0" | sed 's/^# \?//'
  exit 1
fi

PATTERN="$1"
shift

TYPE_FILTER="all"
EXCLUDE_REPO=""
WORD_BOUNDARY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --type) TYPE_FILTER="$2"; shift 2 ;;
    --exclude) EXCLUDE_REPO="$2"; shift 2 ;;
    --word) WORD_BOUNDARY="--word-regexp"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

source "$(dirname "$0")/lib/repos.sh"

TYPE_ARGS=()
case "$TYPE_FILTER" in
  ts|tsx) TYPE_ARGS=(--type ts) ;;
  xml) TYPE_ARGS=(--type xml) ;;
  all) TYPE_ARGS=() ;;
  *) echo "Unknown type: $TYPE_FILTER" >&2; exit 1 ;;
esac

for repo in "${LANE4_REPOS_EXISTING[@]}"; do
  [ -n "$EXCLUDE_REPO" ] && [[ "$repo" == *"/$EXCLUDE_REPO" ]] && continue
  rg \
    --line-number --no-heading --color=never \
    "${LANE4_RG_EXCLUDES[@]}" \
    "${TYPE_ARGS[@]}" \
    $WORD_BOUNDARY \
    -- "$PATTERN" "$repo" 2>/dev/null || true
done
