#!/usr/bin/env bash
# Setup script for statusline plugin
# Configures settings.json to use the plugin's statusline.js
# Runs on SessionStart — skips if already configured
# No external dependencies (no node/python/jq required)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
STATUSLINE_JS="$PLUGIN_ROOT/statusline.js"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Ensure settings.json exists
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Skip if already configured with the correct path
if grep -q "$STATUSLINE_JS" "$SETTINGS_FILE" 2>/dev/null; then
  exit 0
fi

# Build the statusLine JSON value
SL_VALUE="\"statusLine\": { \"type\": \"command\", \"command\": \"node \\\"${STATUSLINE_JS}\\\"\" }"

# Insert into settings.json using pure bash string manipulation
CONTENTS="$(cat "$SETTINGS_FILE")"

if echo "$CONTENTS" | grep -q '"'; then
  # Has existing keys — strip trailing whitespace/newlines and closing brace, append our block
  TRIMMED="${CONTENTS%\}*}"
  printf '%s,\n  %s\n}\n' "$TRIMMED" "$SL_VALUE" > "$SETTINGS_FILE"
else
  # Empty object
  printf '{\n  %s\n}\n' "$SL_VALUE" > "$SETTINGS_FILE"
fi
echo "Statusline configured: $STATUSLINE_JS"
