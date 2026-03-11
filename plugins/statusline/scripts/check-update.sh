#!/usr/bin/env bash
# Wrapper to run check-update.js with node, handling nvm/fnm environments.
# Runs from SessionStart hook — consumes stdin, then launches the checker.

# Consume stdin (hook sends JSON payload we don't need)
cat > /dev/null

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK_UPDATE_JS="$(dirname "$SCRIPT_DIR")/check-update.js"

# Bail if check-update.js is missing
if [ ! -f "$CHECK_UPDATE_JS" ]; then
  exit 0
fi

# Find node: try PATH first, then load nvm/fnm if needed
find_node() {
  command -v node 2>/dev/null && return
  # Try nvm
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh" 2>/dev/null
    command -v node 2>/dev/null && return
  fi
  # Try fnm
  if command -v fnm &>/dev/null; then
    eval "$(fnm env 2>/dev/null)"
    command -v node 2>/dev/null && return
  fi
  # Try volta
  if [ -d "$HOME/.volta" ]; then
    export VOLTA_HOME="$HOME/.volta"
    PATH="$VOLTA_HOME/bin:$PATH"
    command -v node 2>/dev/null && return
  fi
  # Try nodeenv (used by Claude Code installer)
  for p in "$HOME/.local/share/nodeenv/bin/node"; do
    [ -x "$p" ] && echo "$p" && return
  done
  # Try common locations
  for p in /usr/local/bin/node /usr/bin/node /opt/homebrew/bin/node; do
    [ -x "$p" ] && echo "$p" && return
  done
}

NODE_BIN="$(find_node)"
if [ -z "$NODE_BIN" ]; then
  # No node — skip silently
  exit 0
fi

"$NODE_BIN" "$CHECK_UPDATE_JS" < /dev/null
