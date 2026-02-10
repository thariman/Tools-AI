#!/usr/bin/env bash
# Setup script for statusline plugin
# Configures settings.json with the statusLine command
# Runs on SessionStart — skips if already configured
# Requires python3 for safe JSON manipulation

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_SH="$SCRIPT_DIR/run.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Ensure settings.json exists
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Skip if already configured with the correct path
if grep -q "$RUN_SH" "$SETTINGS_FILE" 2>/dev/null; then
  exit 0
fi

# Use python3 to safely read/write JSON (available on macOS and most Linux)
python3 -c "
import json, sys

settings_file = sys.argv[1]
run_sh = sys.argv[2]

with open(settings_file) as f:
    settings = json.load(f)

settings['statusLine'] = {
    'type': 'command',
    'command': 'bash \"' + run_sh + '\"'
}

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
" "$SETTINGS_FILE" "$RUN_SH"

echo "Statusline configured: $RUN_SH"
