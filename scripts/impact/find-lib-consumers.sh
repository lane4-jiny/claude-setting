#!/bin/bash
# Find consumers of a specific named export from @lane4company/lane4-backend-library.
#
# Strategy:
#   1. Find all files that import from '@lane4company/lane4-backend-library'
#   2. Within those files, find lines that reference the export name (excluding import lines)
#
# Usage:
#   find-lib-consumers.sh <export-name>
#
# Known top-level exports (as of analysis):
#   TMapUtils, DateTimeUtils, NotificationUtils, FlightAwareUtils, OpenAIUtils,
#   FirebaseModule, TaskType, ProjectType, ServiceType, SlackChannelType
#
# Output sections:
#   ## Importing files
#   ## Usage sites (excluding the import statement itself)

set -e

EXPORT_NAME="$1"

if [ -z "$EXPORT_NAME" ]; then
  sed -n '2,15p' "$0" | sed 's/^# \?//'
  exit 1
fi

source "$(dirname "$0")/lib/repos.sh"

LIB_PKG="@lane4company/lane4-backend-library"

echo "## Importing files"
echo ""
for repo in "${LANE4_REPOS_EXISTING[@]}"; do
  [[ "$repo" == *"/lane4-backend-library" ]] && continue
  rg \
    --line-number --no-heading --color=never \
    "${LANE4_RG_EXCLUDES[@]}" \
    --type ts \
    -F "from '$LIB_PKG'" "$repo" 2>/dev/null || true
done

echo ""
echo "## Usage sites for: $EXPORT_NAME"
echo ""
for repo in "${LANE4_REPOS_EXISTING[@]}"; do
  [[ "$repo" == *"/lane4-backend-library" ]] && continue

  # Files in this repo that import the library
  files=$(rg -l \
    "${LANE4_RG_EXCLUDES[@]}" \
    --type ts \
    -F "from '$LIB_PKG'" "$repo" 2>/dev/null || true)

  [ -z "$files" ] && continue

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # Word-boundary match for the export, excluding the bare import line
    rg --line-number --no-heading --with-filename --color=never \
      --word-regexp "$EXPORT_NAME" "$f" 2>/dev/null | \
      grep -v "from '$LIB_PKG'" || true
  done <<< "$files"
done
