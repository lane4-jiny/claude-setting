#!/bin/bash
# Search MyBatis XML mapper files for raw SQL references to a column or table.
# This is critical because TypeORM analysis cannot see raw SQL in *.xml mappers.
#
# Usage:
#   find-mybatis-refs.sh <pattern>
#
# Examples:
#   find-mybatis-refs.sh "DRIVER_SCHEDULE_ID"   # column ref
#   find-mybatis-refs.sh "T_LANE_DRIVER"        # table ref

set -e

PATTERN="$1"

if [ -z "$PATTERN" ]; then
  sed -n '2,11p' "$0" | sed 's/^# \?//'
  exit 1
fi

source "$(dirname "$0")/lib/repos.sh"

for repo in "${LANE4_REPOS_EXISTING[@]}"; do
  rg \
    --line-number --no-heading --color=never \
    "${LANE4_RG_EXCLUDES[@]}" \
    --type xml \
    -F "$PATTERN" "$repo" 2>/dev/null || true
done
