#!/usr/bin/env bash
# Setup script for statusline plugin
# Configures settings.json to use the plugin's statusline.js

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
STATUSLINE_JS="$PLUGIN_ROOT/statusline.js"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Ensure settings.json exists
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Use node to safely update settings.json with the statusLine config
node -e "
const fs = require('fs');
const settingsFile = process.argv[1];
const statuslineJs = process.argv[2];

const settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8'));
settings.statusLine = {
  type: 'command',
  command: 'node \"' + statuslineJs + '\"'
};
fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2) + '\n');
" "$SETTINGS_FILE" "$STATUSLINE_JS"

echo "Statusline configured: $STATUSLINE_JS"
