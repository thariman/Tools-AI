#!/usr/bin/env bash
# Setup script for statusline plugin
# Configures settings.json to use the plugin's statusline.js
# Runs on SessionStart — skips if already configured
# No external dependencies (no node/python/jq required)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
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

# Remove any existing statusLine config (handles upgrades from older versions)
CONTENTS="$(grep -v '"statusLine"' "$SETTINGS_FILE")"
# Clean up trailing comma before closing brace if removal left one
CONTENTS="$(echo "$CONTENTS" | sed 's/,[[:space:]]*$//' | sed '/^$/d')"
echo "$CONTENTS" > "$SETTINGS_FILE"

# Build the statusLine JSON value — uses run.sh wrapper to handle nvm/fnm
SL_VALUE="\"statusLine\": { \"type\": \"command\", \"command\": \"bash \\\"${RUN_SH}\\\"\" }"

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
echo "Statusline configured: $RUN_SH"
