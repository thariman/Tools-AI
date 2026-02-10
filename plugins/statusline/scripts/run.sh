#!/usr/bin/env bash
# Wrapper to run statusline.js with node, handling nvm/fnm environments
# where node isn't in PATH for non-interactive shells
# stdin: JSON from Claude Code's statusLine system (passed through to node)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUSLINE_JS="$(dirname "$SCRIPT_DIR")/statusline.js"

# Bail if statusline.js is missing (e.g. cache was cleared)
if [ ! -f "$STATUSLINE_JS" ]; then
  exit 1
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
  exit 1
fi

exec "$NODE_BIN" "$STATUSLINE_JS"
