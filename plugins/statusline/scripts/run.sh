#!/usr/bin/env bash
# Wrapper to run statusline.js with node, handling nvm/fnm environments
# where node isn't in PATH for non-interactive shells

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUSLINE_JS="$(dirname "$SCRIPT_DIR")/statusline.js"

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
  # Try common locations
  for p in /usr/local/bin/node /usr/bin/node; do
    [ -x "$p" ] && echo "$p" && return
  done
}

NODE_BIN="$(find_node)"
if [ -z "$NODE_BIN" ]; then
  exit 1
fi

exec "$NODE_BIN" "$STATUSLINE_JS"
