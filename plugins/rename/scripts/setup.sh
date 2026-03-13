#!/usr/bin/env bash
# Setup script for rename plugin.
# Copies rename.py to a persistent location (~/.claude/rename/)
# so it survives plugin cache clears.
# Runs on SessionStart — skips if already up-to-date.

# Consume stdin (SessionStart hook sends JSON on stdin; we don't need it)
cat > /dev/null

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
PERSISTENT_DIR="$HOME/.claude/rename"

# Ensure persistent directory exists
mkdir -p "$PERSISTENT_DIR"

# Copy rename.py to persistent location (always update to get latest version)
cp "$PLUGIN_DIR/rename.py" "$PERSISTENT_DIR/rename.py"
chmod +x "$PERSISTENT_DIR/rename.py"
