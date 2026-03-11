#!/usr/bin/env bash
# Wrapper to run statusline with node (preferred) or python3 (fallback).
# Handles nvm/fnm environments where node isn't in PATH for non-interactive shells.
# stdin: JSON from Claude Code's statusLine system (passed through to the renderer)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUSLINE_JS="$(dirname "$SCRIPT_DIR")/statusline.js"
STATUSLINE_PY="$(dirname "$SCRIPT_DIR")/statusline.py"

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

# Prefer node (faster startup)
NODE_BIN="$(find_node)"
if [ -n "$NODE_BIN" ] && [ -f "$STATUSLINE_JS" ]; then
  exec "$NODE_BIN" "$STATUSLINE_JS"
fi

# Fall back to python3
find_python() {
  for p in python3 /usr/bin/python3 /usr/local/bin/python3; do
    command -v "$p" &>/dev/null && echo "$p" && return
  done
}

PYTHON_BIN="$(find_python)"
if [ -n "$PYTHON_BIN" ] && [ -f "$STATUSLINE_PY" ]; then
  exec "$PYTHON_BIN" "$STATUSLINE_PY"
fi

echo "statusline: neither node nor python3 found" >&2
exit 1
