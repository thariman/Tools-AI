#!/usr/bin/env bash
# Setup script for statusline plugin
# Copies statusline files to a persistent location (~/.claude/statusline/)
# so they survive plugin cache clears and Claude Code updates.
# Configures settings.json to point to the persistent copy.
# Runs on SessionStart — skips if already configured and up-to-date.
# Requires python3 for safe JSON manipulation.

# Consume stdin (SessionStart hook sends JSON on stdin; we don't need it)
cat > /dev/null

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
PERSISTENT_DIR="$HOME/.claude/statusline"
PERSISTENT_RUN_SH="$PERSISTENT_DIR/run.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Ensure persistent directory exists
mkdir -p "$PERSISTENT_DIR"

# Copy files to persistent location (always update to get latest version)
cp "$PLUGIN_DIR/statusline.js" "$PERSISTENT_DIR/statusline.js"
cp "$PLUGIN_DIR/check-update.js" "$PERSISTENT_DIR/check-update.js" 2>/dev/null || true
cp "$SCRIPT_DIR/run.sh" "$PERSISTENT_DIR/run.sh"
cp "$SCRIPT_DIR/check-update.sh" "$PERSISTENT_DIR/check-update.sh" 2>/dev/null || true
chmod +x "$PERSISTENT_DIR/run.sh"
chmod +x "$PERSISTENT_DIR/check-update.sh" 2>/dev/null || true

# Patch the persistent run.sh so it finds statusline.js in the same directory
# (original looks in parent dir since repo layout is scripts/run.sh + ../statusline.js)
sed -i 's|STATUSLINE_JS="$(dirname "$SCRIPT_DIR")/statusline.js"|STATUSLINE_JS="$SCRIPT_DIR/statusline.js"|' "$PERSISTENT_DIR/run.sh"

# Ensure settings.json exists
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
fi

# Skip JSON update if already pointing to the persistent path
if grep -qF "$PERSISTENT_RUN_SH" "$SETTINGS_FILE" 2>/dev/null; then
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
  echo "statusline setup: python3 not found, cannot configure" >&2
  exit 1
fi

# Use python3 to safely read/write JSON
if ! "$PYTHON" -c "
import json, sys, tempfile, os

settings_file = sys.argv[1]
run_sh = sys.argv[2]

with open(settings_file) as f:
    settings = json.load(f)

settings['statusLine'] = {
    'type': 'command',
    'command': 'bash \"' + run_sh + '\"'
}

tmpfd, tmppath = tempfile.mkstemp(dir=os.path.dirname(settings_file), suffix='.tmp')
try:
    with os.fdopen(tmpfd, 'w') as f:
        json.dump(settings, f, indent=2)
        f.write('\n')
    os.replace(tmppath, settings_file)
except:
    os.unlink(tmppath)
    raise
" "$SETTINGS_FILE" "$PERSISTENT_RUN_SH" 2>&1; then
  echo "statusline setup: failed to update settings.json" >&2
  exit 1
fi

echo "StatusLine plugin configured — status bar will appear after your next interaction or restart."
