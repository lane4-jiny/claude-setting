#!/bin/bash
# Find Redis cache key sites that mention a given table/column/symbol.
# Filters results to lines that look cache-related (redis, cache, key prefixes).
#
# Usage:
#   find-cache-refs.sh <pattern>
#
# Examples:
#   find-cache-refs.sh "driver"          # cache keys mentioning 'driver'
#   find-cache-refs.sh "WORK_HISTORY"    # may match key constants
#
# Note: this is heuristic. False positives (non-cache lines mentioning the
# pattern in a redis-adjacent file) are possible. Always verify with file:line
# context. Both Redis instances in lane4-driver-api are scanned.

set -e

PATTERN="$1"

if [ -z "$PATTERN" ]; then
  sed -n '2,15p' "$0" | sed 's/^# \?//'
  exit 1
fi

source "$(dirname "$0")/lib/repos.sh"

# Step 1: find all files that look cache-related (path or content)
# Step 2: within those files, search for the pattern

for repo in "${LANE4_REPOS_EXISTING[@]}"; do
  # Files whose path contains 'redis' or 'cache' (case-insensitive)
  cache_files=$(find "$repo" \
    -type f \( -name '*.ts' -o -name '*.tsx' \) \
    \( -path '*/redis/*' -o -path '*/cache/*' -o -iname '*redis*' -o -iname '*cache*' \) \
    -not -path '*/node_modules/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -not -path '*/.next/*' \
    2>/dev/null || true)

  [ -z "$cache_files" ] && continue

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    rg --line-number --no-heading --with-filename --color=never \
      -F "$PATTERN" "$f" 2>/dev/null || true
  done <<< "$cache_files"
done
