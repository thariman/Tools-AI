#!/usr/bin/env bash
# Setup script for statusline plugin
# Configures settings.json with the statusLine command
# Runs on SessionStart — skips if already configured
# Requires python3 for safe JSON manipulation

# Consume stdin (SessionStart hook sends JSON on stdin; we don't need it)
cat > /dev/null

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_SH="$SCRIPT_DIR/run.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Ensure settings.json exists
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
fi

# Skip if already configured with THIS version's run.sh path (exact match).
# On plugin version upgrade, the new path won't match the old → falls through
# to the python update below, which overwrites with the correct new path.
if grep -qF "$RUN_SH" "$SETTINGS_FILE" 2>/dev/null; then
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
" "$SETTINGS_FILE" "$RUN_SH" 2>&1; then
  echo "statusline setup: failed to update settings.json" >&2
  exit 1
fi

echo "StatusLine plugin configured — status bar will appear after your next interaction or restart."
