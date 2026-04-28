#!/bin/bash
# Find frontend/mobile call sites for a backend API path.
#
# Searches lane4-web/admin/biz/app-user/app-driver for the path appearing in
# string contexts (single, double, or template-literal quotes).
#
# Usage:
#   find-api-consumers.sh <api-path>
#
# Examples:
#   find-api-consumers.sh "auth/login"
#   find-api-consumers.sh "drivers/begin-work"
#   find-api-consumers.sh "allocations"        # finds 'allocations/' too
#
# Tip: use the static prefix only — for templated paths like
# `drivers/${id}/cars`, search for "drivers" or "drivers/" and filter manually.

set -e

API_PATH="$1"

if [ -z "$API_PATH" ]; then
  sed -n '2,16p' "$0" | sed 's/^# \?//'
  exit 1
fi

source "$(dirname "$0")/lib/repos.sh"

API_PATH="${API_PATH#/}"
API_PATH="${API_PATH%/}"

# Match path inside ', ", or ` quotes
# Pattern: <quote><path><quote-or-/-or-${>
PATTERN="['\"\`]${API_PATH}([/'\"\`]|\\\$)"

CONSUMER_REPOS=(
  "$LANE4_ROOT/lane4-web"
  "$LANE4_ROOT/lane4-admin"
  "$LANE4_ROOT/lane4-biz"
  "$LANE4_ROOT/lane4-app-user"
  "$LANE4_ROOT/lane4-app-driver"
)

for repo in "${CONSUMER_REPOS[@]}"; do
  [ -d "$repo" ] || continue
  rg --line-number --no-heading --color=never \
    "${LANE4_RG_EXCLUDES[@]}" \
    --type ts \
    "$PATTERN" "$repo" 2>/dev/null || true
done
