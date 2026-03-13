#!/usr/bin/env bash
# Removes persistent rename files and state.
# Run this BEFORE "/plugin uninstall rename@tools-ai"

PERSISTENT_DIR="$HOME/.claude/rename"

if [ -d "$PERSISTENT_DIR" ]; then
  rm -rf "$PERSISTENT_DIR"
  echo "Removed rename plugin files and state from $PERSISTENT_DIR"
else
  echo "No rename plugin files found — already clean"
fi
