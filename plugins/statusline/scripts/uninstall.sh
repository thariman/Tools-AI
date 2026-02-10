#!/usr/bin/env bash
# Removes the statusLine config from settings.json
# Run this BEFORE "claude plugin uninstall statusline"

SETTINGS_FILE="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "No settings.json found"
  exit 0
fi

if ! grep -q '"statusLine"' "$SETTINGS_FILE" 2>/dev/null; then
  echo "No statusLine config found in settings.json"
  exit 0
fi

python3 -c "
import json, sys

settings_file = sys.argv[1]

with open(settings_file) as f:
    settings = json.load(f)

settings.pop('statusLine', None)

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
" "$SETTINGS_FILE"

echo "Removed statusLine config from settings.json"
