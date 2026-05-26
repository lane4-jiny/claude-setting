#!/bin/bash
# Install this Claude Code setup into ~/.claude/.
#
# Strategy: symlink each top-level item from this repo into ~/.claude/, so editing
# files in either path stays in sync.
#
# Usage:
#   ./install.sh             # dry run — show what would happen
#   ./install.sh --apply     # actually create symlinks
#
# Items installed:
#   settings.json
#   skills/
#   agents/
#   scripts/

set -e

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
APPLY=""

[ "$1" = "--apply" ] && APPLY="yes"

ITEMS=("settings.json" "skills" "agents" "scripts" "commands")

mkdir -p "$CLAUDE_DIR"

echo "Setup repo: $SETUP_DIR"
echo "Target dir: $CLAUDE_DIR"
echo ""
[ -z "$APPLY" ] && echo "DRY RUN — no changes will be made. Re-run with --apply." && echo ""

for item in "${ITEMS[@]}"; do
  src="$SETUP_DIR/$item"
  dst="$CLAUDE_DIR/$item"

  if [ ! -e "$src" ]; then
    echo "skip $item (not in repo)"
    continue
  fi

  if [ -L "$dst" ]; then
    actual=$(readlink "$dst")
    if [ "$actual" = "$src" ]; then
      echo "ok   $item (already linked)"
      continue
    fi
    echo "fix  $item (replace symlink: $actual → $src)"
    [ -n "$APPLY" ] && rm "$dst"
  elif [ -e "$dst" ]; then
    bak="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "back $item → $(basename "$bak")"
    [ -n "$APPLY" ] && mv "$dst" "$bak"
  fi

  echo "link $item ($dst → $src)"
  [ -n "$APPLY" ] && ln -s "$src" "$dst"
done

# Generate per-machine ntfy topic if missing (notifications opt-in)
TOPIC_FILE="$CLAUDE_DIR/ntfy-topic"
if [ ! -f "$TOPIC_FILE" ]; then
  if [ -n "$APPLY" ]; then
    TOPIC="claude-$(whoami)-$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 16)"
    echo "$TOPIC" > "$TOPIC_FILE"
    chmod 600 "$TOPIC_FILE"
    echo ""
    echo "ntfy: generated topic — https://ntfy.sh/$TOPIC"
    echo "      subscribe in the ntfy mobile app to receive Stop notifications."
  else
    echo ""
    echo "ntfy: would generate a new ntfy-topic at $TOPIC_FILE"
  fi
fi

echo ""
if [ -z "$APPLY" ]; then
  echo "Re-run: ./install.sh --apply"
else
  echo "Done. Restart Claude Code (or run /hooks) to load new hooks."
fi
