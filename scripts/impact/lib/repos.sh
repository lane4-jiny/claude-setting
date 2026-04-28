#!/bin/bash
# Source this file to populate LANE4_REPOS_EXISTING with all live lane4-* projects.
# Set LANE4_ROOT to override the default workspace root.

LANE4_ROOT="${LANE4_ROOT:-$HOME/IdeaProjects}"

LANE4_REPOS_BACKEND=(
  "$LANE4_ROOT/lane4-admin-api"
  "$LANE4_ROOT/lane4-app-api"
  "$LANE4_ROOT/lane4-driver-api"
  "$LANE4_ROOT/lane4-allocation-api"
  "$LANE4_ROOT/lane4-monitoring-api"
  "$LANE4_ROOT/lane4-notification-api"
  "$LANE4_ROOT/lane4-notification-server"
  "$LANE4_ROOT/lane4-scheduler"
  "$LANE4_ROOT/lane4-guest-api"
  "$LANE4_ROOT/lane4-partner-api"
  "$LANE4_ROOT/lane4-emirates-api"
  "$LANE4_ROOT/lane4-klook-api"
  "$LANE4_ROOT/lane4-web-api"
  "$LANE4_ROOT/lane4_backend"
)

LANE4_REPOS_FRONTEND=(
  "$LANE4_ROOT/lane4-admin"
  "$LANE4_ROOT/lane4-web"
  "$LANE4_ROOT/lane4-biz"
)

LANE4_REPOS_MOBILE=(
  "$LANE4_ROOT/lane4-app-driver"
  "$LANE4_ROOT/lane4-app-user"
)

LANE4_REPOS_SHARED=(
  "$LANE4_ROOT/lane4-backend-library"
  "$LANE4_ROOT/lane4-achakey"
)

LANE4_REPOS_ALL=(
  "${LANE4_REPOS_BACKEND[@]}"
  "${LANE4_REPOS_FRONTEND[@]}"
  "${LANE4_REPOS_MOBILE[@]}"
  "${LANE4_REPOS_SHARED[@]}"
)

# Filter to repos that actually exist on disk
LANE4_REPOS_EXISTING=()
for repo in "${LANE4_REPOS_ALL[@]}"; do
  [ -d "$repo" ] && LANE4_REPOS_EXISTING+=("$repo")
done

# Standard rg excludes — pass as: "${LANE4_RG_EXCLUDES[@]}"
LANE4_RG_EXCLUDES=(
  --glob '!node_modules/**'
  --glob '!dist/**'
  --glob '!build/**'
  --glob '!.next/**'
  --glob '!.git/**'
  --glob '!coverage/**'
  --glob '!8081s/**'
  --glob '!claudedocs/**'
  --glob '!*.lock'
  --glob '!yarn.lock'
  --glob '!package-lock.json'
  --glob '!pnpm-lock.yaml'
)

# Helper: rg invocation with standard excludes
lane4_rg() {
  rg --line-number --no-heading --color=never "${LANE4_RG_EXCLUDES[@]}" "$@"
}

export LANE4_ROOT
