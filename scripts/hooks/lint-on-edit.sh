#!/bin/bash
# PostToolUse hook for Edit/Write — runs eslint --fix on the changed file.
# Silent on success; logs errors. Skips if eslint not installed in project.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)

[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

# Only TS/TSX/JS/JSX
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

# Skip vendored dirs
case "$FILE" in
  */node_modules/*|*/dist/*|*/build/*|*/.next/*|*/coverage/*) exit 0 ;;
esac

# Find project root (walk up to find package.json)
DIR="$(dirname "$FILE")"
while [ "$DIR" != "/" ] && [ ! -f "$DIR/package.json" ]; do
  DIR="$(dirname "$DIR")"
done
[ -f "$DIR/package.json" ] || exit 0

# Use project-local eslint if present; otherwise skip silently
ESLINT_BIN="$DIR/node_modules/.bin/eslint"
[ -x "$ESLINT_BIN" ] || exit 0

# Run lint with timeout (10s should be plenty for one file)
# macOS lacks `timeout`; fall back to `gtimeout` (coreutils) or run directly.
cd "$DIR" || exit 0
if command -v timeout >/dev/null 2>&1; then
  timeout 10 "$ESLINT_BIN" --fix --no-error-on-unmatched-pattern "$FILE" 2>&1 | tail -30 >&2
elif command -v gtimeout >/dev/null 2>&1; then
  gtimeout 10 "$ESLINT_BIN" --fix --no-error-on-unmatched-pattern "$FILE" 2>&1 | tail -30 >&2
else
  "$ESLINT_BIN" --fix --no-error-on-unmatched-pattern "$FILE" 2>&1 | tail -30 >&2
fi

# Always exit 0 — lint errors shouldn't block subsequent tools
exit 0
