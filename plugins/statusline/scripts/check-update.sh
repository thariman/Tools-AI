#!/usr/bin/env bash
# Wrapper to run check-update.js with node, handling nvm/fnm environments.
# Runs from SessionStart hook — consumes stdin, then launches the checker.
# IMPORTANT: Node discovery runs in the main shell (not a subshell) so that
# PATH modifications (nvm, fnm, volta) are inherited by the node process.
# This lets check-update.js find both `node` and `claude` in PATH.

# Consume stdin (hook sends JSON payload we don't need)
cat > /dev/null

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK_UPDATE_JS="$(dirname "$SCRIPT_DIR")/check-update.js"

# Bail if check-update.js is missing
if [ ! -f "$CHECK_UPDATE_JS" ]; then
  exit 0
fi

# Find node in the main shell so PATH changes persist for the child process
NODE_BIN=""

# Try PATH first
NODE_BIN="$(command -v node 2>/dev/null)"

# Try nvm
if [ -z "$NODE_BIN" ]; then
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh" 2>/dev/null
    NODE_BIN="$(command -v node 2>/dev/null)"
  fi
fi

# Try fnm
if [ -z "$NODE_BIN" ]; then
  if command -v fnm &>/dev/null; then
    eval "$(fnm env 2>/dev/null)"
    NODE_BIN="$(command -v node 2>/dev/null)"
  fi
fi

# Try volta
if [ -z "$NODE_BIN" ]; then
  if [ -d "$HOME/.volta" ]; then
    export VOLTA_HOME="$HOME/.volta"
    export PATH="$VOLTA_HOME/bin:$PATH"
    NODE_BIN="$(command -v node 2>/dev/null)"
  fi
fi

# Try nodeenv (used by Claude Code installer)
if [ -z "$NODE_BIN" ]; then
  if [ -x "$HOME/.local/share/nodeenv/bin/node" ]; then
    NODE_BIN="$HOME/.local/share/nodeenv/bin/node"
    export PATH="$HOME/.local/share/nodeenv/bin:$PATH"
  fi
fi

# Try common locations
if [ -z "$NODE_BIN" ]; then
  for p in /usr/local/bin/node /usr/bin/node /opt/homebrew/bin/node; do
    if [ -x "$p" ]; then
      NODE_BIN="$p"
      break
    fi
  done
fi

if [ -z "$NODE_BIN" ]; then
  # No node — skip silently
  exit 0
fi

# Add node's directory to PATH so co-installed binaries (claude) are findable
export PATH="$(dirname "$NODE_BIN"):$PATH"

"$NODE_BIN" "$CHECK_UPDATE_JS" < /dev/null
