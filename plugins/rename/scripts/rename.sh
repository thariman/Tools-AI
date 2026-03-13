#!/usr/bin/env bash
# Auto-rename session on startup.
# Reads SessionStart hook JSON from stdin, passes to rename.py.
# Falls back to persistent copy if plugin cache is missing.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RENAME_PY="$(dirname "$SCRIPT_DIR")/rename.py"
PERSISTENT_PY="$HOME/.claude/rename/rename.py"

# Find python3
PYTHON=""
for p in python3 /usr/bin/python3 /usr/local/bin/python3; do
  if command -v "$p" &>/dev/null; then
    PYTHON="$p"
    break
  fi
done

if [ -z "$PYTHON" ]; then
  cat > /dev/null  # consume stdin
  exit 0
fi

# Use plugin copy, fall back to persistent copy
if [ -f "$RENAME_PY" ]; then
  "$PYTHON" "$RENAME_PY"
elif [ -f "$PERSISTENT_PY" ]; then
  "$PYTHON" "$PERSISTENT_PY"
else
  cat > /dev/null  # consume stdin
fi
