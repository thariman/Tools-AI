#!/usr/bin/env bash
# Removes the statusLine config from settings.json
# Run this BEFORE "/plugin uninstall statusline@skills-ai"

SETTINGS_FILE="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "No settings.json found — nothing to clean up"
  exit 0
fi

if ! grep -qF '"statusLine"' "$SETTINGS_FILE" 2>/dev/null; then
  echo "No statusLine config found — already clean"
  exit 0
fi

# Find python3
PYTHON=""
for p in python3 /usr/bin/python3 /usr/local/bin/python3; do
  if command -v "$p" &>/dev/null; then
    PYTHON="$p"
    break
  fi
done

if [ -z "$PYTHON" ]; then
  echo "Error: python3 not found. Manually remove the \"statusLine\" key from $SETTINGS_FILE" >&2
  exit 1
fi

if ! "$PYTHON" -c "
import json, sys

settings_file = sys.argv[1]

with open(settings_file) as f:
    settings = json.load(f)

settings.pop('statusLine', None)

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
" "$SETTINGS_FILE" 2>&1; then
  echo "Error: failed to update settings.json" >&2
  exit 1
fi

echo "Removed statusLine config from settings.json"
