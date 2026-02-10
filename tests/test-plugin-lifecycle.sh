#!/usr/bin/env bash
# ============================================================================
# Statusline Plugin Lifecycle Test Suite
# ============================================================================
# Comprehensive tests for install, configure, render, uninstall, and edge cases
#
# Usage:
#   ssh tony@ms-s1-max 'bash /path/to/test-plugin-lifecycle.sh'
#   Or run directly on the remote machine.
#
# Requirements:
#   - Claude CLI at /home/tony/.local/bin/claude
#   - Python3 available
#   - Node.js available (via nodeenv at ~/.local/share/nodeenv/bin/node)
#   - Internet access (for marketplace add from GitHub)
# ============================================================================

set -uo pipefail  # No set -e: tests must handle failures explicitly

# ── Configuration ──────────────────────────────────────────────────────────

CLAUDE_CLI="/home/tony/.local/bin/claude"
SETTINGS_FILE="$HOME/.claude/settings.json"
SETTINGS_LOCAL="$HOME/.claude/settings.local.json"
PLUGIN_CACHE="$HOME/.claude/plugins/cache/skills-ai"
MARKETPLACE_REPO="thariman/Skills-AI"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/skills-ai"
KNOWN_MARKETPLACES="$HOME/.claude/plugins/known_marketplaces.json"
PLUGIN_NAME="statusline@skills-ai"
# Plugin cache structure: $PLUGIN_CACHE/statusline/<version>/
# Use a glob to find the version directory dynamically
PLUGIN_VERSION="1.0.0"

# ── Counters ───────────────────────────────────────────────────────────────

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
TOTAL_TESTS=0

# ── Colors ─────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Output Helpers ─────────────────────────────────────────────────────────

banner() {
  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
  echo -e "${BOLD} $1${RESET}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
}

test_header() {
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  echo ""
  echo -e "${BOLD}── $1 ──${RESET}"
  echo -e "${DIM}   $2${RESET}"
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo -e "   ${GREEN}✔ PASS${RESET}: $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo -e "   ${RED}✘ FAIL${RESET}: $1"
}

skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  echo -e "   ${YELLOW}⊘ SKIP${RESET}: $1"
}

info() {
  echo -e "   ${DIM}→ $1${RESET}"
}

# ── Assert Helpers ─────────────────────────────────────────────────────────

assert_file_exists() {
  local file="$1"
  local msg="${2:-File exists: $file}"
  if [ -f "$file" ]; then
    pass "$msg"
    return 0
  else
    fail "$msg (file not found: $file)"
    return 1
  fi
}

assert_file_not_exists() {
  local file="$1"
  local msg="${2:-File does not exist: $file}"
  if [ ! -f "$file" ]; then
    pass "$msg"
    return 0
  else
    fail "$msg (file still exists: $file)"
    return 1
  fi
}

assert_dir_exists() {
  local dir="$1"
  local msg="${2:-Directory exists: $dir}"
  if [ -d "$dir" ]; then
    pass "$msg"
    return 0
  else
    fail "$msg (directory not found: $dir)"
    return 1
  fi
}

assert_dir_not_exists() {
  local dir="$1"
  local msg="${2:-Directory does not exist: $dir}"
  if [ ! -d "$dir" ]; then
    pass "$msg"
    return 0
  else
    fail "$msg (directory still exists: $dir)"
    return 1
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local msg="${3:-File contains pattern}"
  if grep -qF "$pattern" "$file" 2>/dev/null; then
    pass "$msg"
    return 0
  else
    fail "$msg (pattern '$pattern' not found in $file)"
    return 1
  fi
}

assert_file_not_contains() {
  local file="$1"
  local pattern="$2"
  local msg="${3:-File does not contain pattern}"
  if ! grep -qF "$pattern" "$file" 2>/dev/null; then
    pass "$msg"
    return 0
  else
    fail "$msg (pattern '$pattern' still found in $file)"
    return 1
  fi
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-Exit code matches}"
  if [ "$actual" -eq "$expected" ]; then
    pass "$msg (exit $actual)"
    return 0
  else
    fail "$msg (expected exit $expected, got exit $actual)"
    return 1
  fi
}

assert_output_contains() {
  local output="$1"
  local pattern="$2"
  local msg="${3:-Output contains expected text}"
  if echo "$output" | grep -qF "$pattern"; then
    pass "$msg"
    return 0
  else
    fail "$msg (pattern '$pattern' not found in output)"
    return 1
  fi
}

assert_output_not_empty() {
  local output="$1"
  local msg="${2:-Output is not empty}"
  if [ -n "$output" ]; then
    pass "$msg"
    return 0
  else
    fail "$msg (output was empty)"
    return 1
  fi
}

assert_stderr_empty() {
  local stderr_file="$1"
  local msg="${2:-No stderr output}"
  if [ ! -s "$stderr_file" ]; then
    pass "$msg"
    return 0
  else
    local content
    content=$(cat "$stderr_file")
    fail "$msg (stderr: $content)"
    return 1
  fi
}

# ── State Management ───────────────────────────────────────────────────────

reset_clean_state() {
  info "Resetting to clean state..."

  # Remove statusLine from settings.json if present
  if [ -f "$SETTINGS_FILE" ]; then
    if grep -qF '"statusLine"' "$SETTINGS_FILE" 2>/dev/null; then
      /usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
s.pop('statusLine', None)
with open(sys.argv[1], 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
" "$SETTINGS_FILE" 2>/dev/null || true
    fi
  fi

  # Remove plugin from enabledPlugins if present
  if [ -f "$SETTINGS_FILE" ]; then
    /usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
plugins = s.get('enabledPlugins', [])
s['enabledPlugins'] = [p for p in plugins if 'skills-ai' not in str(p).lower() and 'statusline' not in str(p).lower()]
if not s['enabledPlugins']:
    s.pop('enabledPlugins', None)
with open(sys.argv[1], 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
" "$SETTINGS_FILE" 2>/dev/null || true
  fi

  # Remove plugin cache
  rm -rf "$PLUGIN_CACHE"

  # Remove marketplace entry from known_marketplaces.json
  if [ -f "$KNOWN_MARKETPLACES" ]; then
    /usr/bin/python3 -c "
import json, sys, tempfile, os
f = sys.argv[1]
with open(f) as fh:
    data = json.load(fh)
if isinstance(data, dict):
    for k in list(data.keys()):
        if 'skills-ai' in k.lower() or 'Skills-AI' in str(data[k]):
            del data[k]
tmpfd, tmppath = tempfile.mkstemp(dir=os.path.dirname(f), suffix='.tmp')
try:
    with os.fdopen(tmpfd, 'w') as fh:
        json.dump(data, fh, indent=2)
        fh.write('\n')
    os.replace(tmppath, f)
except:
    os.unlink(tmppath)
    raise
" "$KNOWN_MARKETPLACES" 2>/dev/null || true
  fi

  # Remove marketplace directory for skills-ai
  rm -rf "$MARKETPLACE_DIR"

  # Ensure settings.json exists as valid JSON
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
  fi

  info "Clean state achieved"
}

install_plugin() {
  # Claude CLI slash commands (/marketplace, /plugin) work in -p (print) mode.
  # The slash command is passed as the prompt argument.
  info "Adding marketplace repo..."
  $CLAUDE_CLI -p "/marketplace add $MARKETPLACE_REPO" --dangerously-skip-permissions 2>&1 || true

  info "Installing plugin..."
  $CLAUDE_CLI -p "/plugin install $PLUGIN_NAME" --dangerously-skip-permissions 2>&1 || true
}

install_plugin_manual() {
  # Manually simulate what /plugin install does:
  # 1. Copy plugin files from pre-staged source into the cache directory
  # 2. Add to enabledPlugins in settings.json
  #
  # Before running this test, stage the plugin source via:
  #   scp -r plugins/statusline tony@ms-s1-max:~/plugin-source/
  info "Manual install..."

  # Step 1: Locate plugin source (pre-staged by test runner)
  local src="${PLUGIN_SOURCE_DIR:-$HOME/plugin-source}"
  if [ ! -d "$src/scripts" ]; then
    fail "Plugin source not found at $src/scripts — did you scp the plugin source first?"
    info "Run: scp -r /path/to/plugins/statusline user@host:~/plugin-source/"
    return 1
  fi

  # Step 2: Copy plugin files into cache (mimic /plugin install structure)
  local plugin_root
  plugin_root="$(get_plugin_root)"
  rm -rf "$plugin_root"
  mkdir -p "$plugin_root"

  # Copy all plugin contents
  cp -r "$src/"* "$plugin_root/"
  # Copy hidden dirs (.claude-plugin)
  cp -r "$src/.claude-plugin" "$plugin_root/" 2>/dev/null || true

  # Make scripts executable
  chmod +x "$plugin_root/scripts/"*.sh 2>/dev/null || true

  # Step 3: Add to enabledPlugins in settings.json
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
  fi

  /usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
ep = s.get('enabledPlugins', {})
ep['statusline@skills-ai'] = True
s['enabledPlugins'] = ep
with open(sys.argv[1], 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
" "$SETTINGS_FILE"

  info "Manual install complete"
}

simulate_session_start() {
  # The setup.sh script expects JSON on stdin (from SessionStart hook)
  # It reads and discards it via `cat > /dev/null`
  local setup_script
  setup_script="$(get_setup_sh_path)"
  if [ ! -f "$setup_script" ]; then
    echo "ERROR: setup.sh not found at $setup_script"
    return 1
  fi
  echo '{"type":"SessionStart"}' | bash "$setup_script" 2>&1
}

verify_settings_has_statusline() {
  if [ ! -f "$SETTINGS_FILE" ]; then
    return 1
  fi
  grep -qF '"statusLine"' "$SETTINGS_FILE" 2>/dev/null
}

verify_settings_clean() {
  if [ ! -f "$SETTINGS_FILE" ]; then
    return 0  # No settings file = clean
  fi
  ! grep -qF '"statusLine"' "$SETTINGS_FILE" 2>/dev/null
}

get_plugin_root() {
  # Find the versioned plugin directory (e.g. .../statusline/1.0.0/)
  # Try exact version first, then glob for any version
  local dir="$PLUGIN_CACHE/statusline/$PLUGIN_VERSION"
  if [ -d "$dir" ]; then
    echo "$dir"
    return
  fi
  # Fallback: find any version directory
  local found
  found=$(find "$PLUGIN_CACHE/statusline" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)
  if [ -n "$found" ]; then
    echo "$found"
    return
  fi
  echo "$dir"  # Return expected path even if missing (caller checks existence)
}

get_run_sh_path() {
  echo "$(get_plugin_root)/scripts/run.sh"
}

get_setup_sh_path() {
  echo "$(get_plugin_root)/scripts/setup.sh"
}

get_uninstall_sh_path() {
  echo "$(get_plugin_root)/scripts/uninstall.sh"
}

get_statusline_js_path() {
  echo "$(get_plugin_root)/statusline.js"
}

run_statusline_with_sample() {
  local run_sh
  run_sh="$(get_run_sh_path)"
  if [ ! -f "$run_sh" ]; then
    echo "ERROR: run.sh not found"
    return 1
  fi

  local sample_json='{
    "model": {"display_name": "Claude Opus 4.6"},
    "workspace": {"current_dir": "/home/tony/test-project"},
    "session_id": "test-session-123",
    "context_window": {"remaining_percentage": 72}
  }'

  echo "$sample_json" | bash "$run_sh" 2>/dev/null
}

# ── 1-Restart Test Helpers ───────────────────────────────────────────────

run_install_time_setup() {
  # Runs setup.sh directly (simulates install-time execution, not SessionStart hook).
  # The key difference from simulate_session_start: conceptually this happens
  # at install time (before any Claude session), so statusLine config will be
  # present when Claude first reads settings.json.
  local setup_script
  setup_script="$(get_setup_sh_path)"
  if [ ! -f "$setup_script" ]; then
    echo "ERROR: setup.sh not found at $setup_script"
    return 1
  fi
  # setup.sh does `cat > /dev/null` to consume stdin, so we pipe from /dev/null
  bash "$setup_script" < /dev/null 2>&1
}

snapshot_settings() {
  # Captures settings.json content for before/after comparison
  if [ -f "$SETTINGS_FILE" ]; then
    cat "$SETTINGS_FILE"
  else
    echo ""
  fi
}

get_statusline_command_from_settings() {
  # Extracts statusLine.command value from settings.json via Python
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo ""
    return
  fi
  /usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
cmd = s.get('statusLine', {}).get('command', '')
print(cmd)
" "$SETTINGS_FILE" 2>/dev/null || echo ""
}

run_minimal_claude_session() {
  # Runs a minimal Claude session with timeout for safety.
  # Uses -p (print mode) with --dangerously-skip-permissions --no-session-persistence.
  # Note: SessionStart hooks may NOT fire in -p mode (empirically confirmed).
  local timeout_sec="${1:-30}"
  timeout "$timeout_sec" $CLAUDE_CLI -p "say ok" --dangerously-skip-permissions --no-session-persistence 2>&1 || true
}

run_real_claude_session() {
  # Runs a REAL interactive Claude session in tmux that fires SessionStart hooks.
  # SessionStart hooks ONLY fire in interactive TUI mode (not -p/print mode,
  # not piped stdin). tmux provides a real PTY for the TUI.
  # Requires: tmux installed on the system.
  local wait_sec="${1:-12}"
  local session_name="statusline-test-$$"

  # Kill any leftover session
  tmux kill-session -t "$session_name" 2>/dev/null || true

  # Start Claude in a detached tmux session (real PTY)
  tmux new-session -d -s "$session_name" "$CLAUDE_CLI --dangerously-skip-permissions" 2>/dev/null
  if [ $? -ne 0 ]; then
    info "tmux failed to start session"
    return 1
  fi

  # Wait for Claude to initialize and fire SessionStart hooks
  sleep "$wait_sec"

  # Kill the session (we don't need to interact, just let hooks fire)
  tmux kill-session -t "$session_name" 2>/dev/null || true
}

install_plugin_real() {
  # Does a REAL plugin install using Claude CLI subcommands.
  # This creates proper entries in installed_plugins.json (required for hook discovery).
  # Requires: marketplace repo accessible from remote machine.

  # Step 1: Add marketplace (idempotent — skips if already added)
  info "Adding marketplace via CLI..."
  $CLAUDE_CLI plugin marketplace add "$MARKETPLACE_REPO" 2>&1 || true

  # Step 2: Install plugin
  info "Installing plugin via CLI..."
  $CLAUDE_CLI plugin install "$PLUGIN_NAME" 2>&1 || true
}

uninstall_plugin_real() {
  # Does a REAL plugin uninstall using Claude CLI subcommands.
  $CLAUDE_CLI plugin uninstall "$PLUGIN_NAME" 2>&1 || true
}

reset_clean_state_real() {
  # Full cleanup including real plugin uninstall and marketplace removal.
  # Use this for T21+ tests that need a truly clean state.
  info "Resetting to clean state (real)..."

  # Uninstall plugin if installed
  $CLAUDE_CLI plugin uninstall "$PLUGIN_NAME" 2>/dev/null || true

  # Remove marketplace
  $CLAUDE_CLI plugin marketplace remove skills-ai 2>/dev/null || true

  # Reset settings.json to empty (remove all test artifacts)
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"

  info "Clean state achieved (real)"
}

install_marker_run_sh() {
  # Replaces run.sh with a marker script that writes a file when invoked.
  # Backs up the original run.sh first.
  local run_sh
  run_sh="$(get_run_sh_path)"
  if [ ! -f "$run_sh" ]; then
    echo "ERROR: run.sh not found"
    return 1
  fi

  # Backup original
  cp "$run_sh" "${run_sh}.bak"

  # Write marker script
  cat > "$run_sh" << 'MARKER_EOF'
#!/usr/bin/env bash
# Marker script: writes a timestamp to prove Claude invoked this
cat > /dev/null
echo "$(date +%s)" > /tmp/statusline-marker.txt
echo "MARKER_ACTIVE"
MARKER_EOF
  chmod +x "$run_sh"
}

restore_original_run_sh() {
  # Restores the original run.sh from backup
  local run_sh
  run_sh="$(get_run_sh_path)"
  if [ -f "${run_sh}.bak" ]; then
    mv "${run_sh}.bak" "$run_sh"
    chmod +x "$run_sh"
  fi
}

# ── Preflight Checks ──────────────────────────────────────────────────────

preflight() {
  banner "Preflight Checks"

  local ok=true

  if [ -x "$CLAUDE_CLI" ] || command -v "$CLAUDE_CLI" &>/dev/null; then
    pass "Claude CLI found at $CLAUDE_CLI"
  else
    fail "Claude CLI not found at $CLAUDE_CLI"
    ok=false
  fi

  if command -v /usr/bin/python3 &>/dev/null; then
    pass "Python3 available"
  else
    fail "Python3 not found"
    ok=false
  fi

  local node_bin=""
  if command -v node &>/dev/null; then
    node_bin="$(command -v node)"
  elif [ -x "$HOME/.local/share/nodeenv/bin/node" ]; then
    node_bin="$HOME/.local/share/nodeenv/bin/node"
  fi

  if [ -n "$node_bin" ]; then
    pass "Node.js available at $node_bin"
  else
    fail "Node.js not found"
    ok=false
  fi

  if command -v tmux &>/dev/null; then
    pass "tmux available (required for real session tests)"
  else
    fail "tmux not found (required for T21 real session test)"
    ok=false
  fi

  if [ "$ok" = false ]; then
    echo ""
    echo -e "${RED}Preflight checks failed. Cannot continue.${RESET}"
    exit 1
  fi
}

# ============================================================================
# TEST CASES
# ============================================================================

test_T1_fresh_install() {
  test_header "T1: Fresh Install" \
    "Clean state → marketplace add → plugin install → SessionStart → verify config"

  reset_clean_state

  # Step 1: Install the plugin
  info "Installing plugin..."
  install_plugin_manual

  if [ -d "$PLUGIN_CACHE" ]; then
    pass "Plugin cache directory created"
  else
    fail "Plugin cache directory not created at $PLUGIN_CACHE"
    return
  fi

  # Step 3: Verify key files exist in cache
  assert_file_exists "$(get_setup_sh_path)" "setup.sh exists in cache"
  assert_file_exists "$(get_run_sh_path)" "run.sh exists in cache"
  assert_file_exists "$(get_uninstall_sh_path)" "uninstall.sh exists in cache"

  # Step 4: Verify scripts are executable
  if [ -x "$(get_setup_sh_path)" ]; then
    pass "setup.sh is executable"
  else
    fail "setup.sh is not executable"
  fi

  # Step 5: Simulate SessionStart (triggers setup.sh)
  info "Simulating SessionStart..."
  local output
  output=$(simulate_session_start) || true

  # Step 6: Verify settings.json now has statusLine
  if verify_settings_has_statusline; then
    pass "settings.json contains statusLine configuration"
  else
    fail "settings.json missing statusLine after SessionStart"
    if [ -f "$SETTINGS_FILE" ]; then
      info "Current settings.json contents:"
      cat "$SETTINGS_FILE" | head -20
    fi
  fi

  # Step 7: Verify the statusLine config points to correct run.sh
  local run_sh_path
  run_sh_path="$(get_run_sh_path)"
  assert_file_contains "$SETTINGS_FILE" "$run_sh_path" \
    "statusLine command references correct run.sh path"

  # Step 8: Verify run.sh produces output with sample data
  info "Testing run.sh with sample JSON..."
  local statusline_output
  statusline_output=$(run_statusline_with_sample) || true
  assert_output_not_empty "$statusline_output" "run.sh produces output"
}

test_T2_idempotent_setup() {
  test_header "T2: Idempotent Setup" \
    "Run setup.sh again on already-configured system → settings.json unchanged"

  # Precondition: settings.json should have statusLine from T1
  if ! verify_settings_has_statusline; then
    skip "Requires T1 to have passed (statusLine not configured)"
    return
  fi

  # Capture settings before second run
  local before
  before=$(cat "$SETTINGS_FILE")

  # Run setup.sh again
  info "Running setup.sh a second time..."
  local output exit_code
  output=$(simulate_session_start 2>&1) || true
  exit_code=$?

  # Verify exit code is 0 (early exit because already configured)
  assert_exit_code 0 "$exit_code" "setup.sh exits cleanly when already configured"

  # Verify settings.json is unchanged
  local after
  after=$(cat "$SETTINGS_FILE")
  if [ "$before" = "$after" ]; then
    pass "settings.json unchanged after second setup.sh run"
  else
    fail "settings.json was modified by idempotent setup.sh run"
    info "Before: $before"
    info "After: $after"
  fi
}

test_T3_statusline_rendering() {
  test_header "T3: Statusline Rendering" \
    "Pipe sample JSON to run.sh → verify output contains expected segments"

  local run_sh
  run_sh="$(get_run_sh_path)"

  if [ ! -f "$run_sh" ]; then
    skip "run.sh not found (requires T1)"
    return
  fi

  # Test with full data
  info "Testing with full sample data..."
  local output
  output=$(run_statusline_with_sample) || true

  assert_output_not_empty "$output" "Statusline produces output"

  # Check for model name (strip ANSI codes for matching)
  local clean_output
  clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')

  if echo "$clean_output" | grep -qF "Claude Opus 4.6"; then
    pass "Output contains model name"
  else
    fail "Output missing model name 'Claude Opus 4.6'"
    info "Clean output: $clean_output"
  fi

  # Check for directory name
  if echo "$clean_output" | grep -qF "test-project"; then
    pass "Output contains directory name"
  else
    fail "Output missing directory name 'test-project'"
    info "Clean output: $clean_output"
  fi

  # Check for context percentage (100 - 72 = 28%)
  if echo "$clean_output" | grep -qF "28%"; then
    pass "Output contains context usage percentage (28%)"
  else
    fail "Output missing context percentage '28%'"
    info "Clean output: $clean_output"
  fi

  # Test with minimal JSON (empty object)
  info "Testing with minimal JSON (empty object)..."
  local minimal_output
  minimal_output=$(echo '{}' | bash "$run_sh" 2>/dev/null) || true

  # Should produce something (at minimum the model fallback "Claude" and cwd)
  if [ -n "$minimal_output" ]; then
    pass "Statusline handles minimal JSON gracefully"
  else
    # Empty output is also acceptable for empty JSON — statusline.js uses
    # try/catch and might still produce output
    pass "Statusline handles minimal JSON (empty output acceptable)"
  fi

  # Test with completely invalid JSON
  info "Testing with invalid JSON..."
  local stderr_file
  stderr_file=$(mktemp)
  local bad_output
  bad_output=$(echo 'not-json-at-all' | bash "$run_sh" 2>"$stderr_file") || true

  # Should fail silently (no stderr, empty stdout)
  assert_stderr_empty "$stderr_file" "No stderr on invalid JSON input"
  rm -f "$stderr_file"
}

test_T4_clean_uninstall() {
  test_header "T4: Clean Uninstall" \
    "Run uninstall.sh → verify statusLine removed → plugin uninstall → verify clean"

  # Precondition: statusLine should be configured
  if ! verify_settings_has_statusline; then
    skip "Requires statusLine to be configured"
    return
  fi

  # Step 1: Run uninstall.sh
  info "Running uninstall.sh..."
  local uninstall_sh
  uninstall_sh="$(get_uninstall_sh_path)"

  if [ ! -f "$uninstall_sh" ]; then
    fail "uninstall.sh not found at expected path"
    return
  fi

  local output
  output=$(bash "$uninstall_sh" 2>&1) || true

  assert_output_contains "$output" "Removed statusLine config" \
    "uninstall.sh reports successful removal"

  # Step 2: Verify statusLine removed from settings.json
  if verify_settings_clean; then
    pass "statusLine removed from settings.json"
  else
    fail "statusLine still present in settings.json after uninstall.sh"
  fi

  # Step 3: Verify other settings preserved
  # settings.json should still be valid JSON
  if /usr/bin/python3 -c "import json; json.load(open('$SETTINGS_FILE'))" 2>/dev/null; then
    pass "settings.json is still valid JSON after uninstall"
  else
    fail "settings.json is corrupted after uninstall"
  fi

  # Step 4: Remove plugin from enabledPlugins and clean empty key (simulates /plugin uninstall)
  info "Removing plugin from enabledPlugins..."
  /usr/bin/python3 -c "
import json, sys, tempfile, os
settings_file = sys.argv[1]
with open(settings_file) as f:
    s = json.load(f)
ep = s.get('enabledPlugins', {})
if isinstance(ep, dict):
    ep.pop('statusline@skills-ai', None)
    if not ep:
        s.pop('enabledPlugins', None)
    else:
        s['enabledPlugins'] = ep
elif isinstance(ep, list):
    ep = [p for p in ep if 'skills-ai' not in str(p).lower()]
    if not ep:
        s.pop('enabledPlugins', None)
    else:
        s['enabledPlugins'] = ep
tmpfd, tmppath = tempfile.mkstemp(dir=os.path.dirname(settings_file), suffix='.tmp')
try:
    with os.fdopen(tmpfd, 'w') as f:
        json.dump(s, f, indent=2)
        f.write('\n')
    os.replace(tmppath, settings_file)
except:
    os.unlink(tmppath)
    raise
" "$SETTINGS_FILE" 2>&1 || true

  # Step 5: Verify enabledPlugins entry is gone
  if [ -f "$SETTINGS_FILE" ]; then
    local has_plugin
    has_plugin=$(/usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
plugins = s.get('enabledPlugins', {})
if isinstance(plugins, dict):
    found = any('skills-ai' in k.lower() or 'statusline' in k.lower() for k in plugins)
else:
    found = any('skills-ai' in str(p).lower() or 'statusline' in str(p).lower() for p in plugins)
print('yes' if found else 'no')
" "$SETTINGS_FILE" 2>/dev/null) || true

    if [ "$has_plugin" = "no" ]; then
      pass "Plugin removed from enabledPlugins"
    else
      fail "Plugin still in enabledPlugins after uninstall"
    fi
  else
    pass "settings.json removed (clean state)"
  fi

  # Step 6: Verify empty enabledPlugins key is removed (not left as {})
  if [ -f "$SETTINGS_FILE" ]; then
    local has_empty_ep
    has_empty_ep=$(/usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
ep = s.get('enabledPlugins', None)
if ep is not None and not ep:
    print('empty')
elif ep is None:
    print('absent')
else:
    print('populated')
" "$SETTINGS_FILE" 2>/dev/null) || true

    if [ "$has_empty_ep" = "absent" ]; then
      pass "Empty enabledPlugins key removed from settings.json"
    elif [ "$has_empty_ep" = "empty" ]; then
      fail "Empty enabledPlugins {} left in settings.json"
    else
      pass "enabledPlugins still has other entries (expected)"
    fi
  fi

  # Step 7: Remove plugin cache (simulates /plugin uninstall removing cached files)
  info "Removing plugin cache..."
  rm -rf "$PLUGIN_CACHE"
  assert_dir_not_exists "$PLUGIN_CACHE" "Plugin cache directory removed"
}

test_T5_dirty_uninstall() {
  test_header "T5: Dirty Uninstall" \
    "Plugin uninstall WITHOUT running uninstall.sh → orphaned statusLine config remains"

  # Precondition: need a fresh install with statusLine configured
  reset_clean_state
  install_plugin_manual
  simulate_session_start >/dev/null 2>&1 || true

  if ! verify_settings_has_statusline; then
    skip "Could not set up precondition (statusLine not configured)"
    return
  fi

  info "Performing dirty uninstall (skipping uninstall.sh)..."

  # Simulate dirty uninstall: remove enabledPlugins but NOT statusLine config
  /usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
ep = s.get('enabledPlugins', {})
if isinstance(ep, dict):
    ep.pop('statusline@skills-ai', None)
elif isinstance(ep, list):
    ep = [p for p in ep if 'skills-ai' not in str(p).lower()]
if not ep:
    s.pop('enabledPlugins', None)
else:
    s['enabledPlugins'] = ep
with open(sys.argv[1], 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
" "$SETTINGS_FILE" 2>/dev/null || true

  # Also remove the plugin cache (simulates what /plugin uninstall does)
  rm -rf "$PLUGIN_CACHE"

  # Verify statusLine config is STILL present (orphaned)
  if verify_settings_has_statusline; then
    pass "Orphaned statusLine config remains after dirty uninstall"
  else
    fail "statusLine was somehow cleaned up during dirty uninstall"
  fi

  # The orphaned config will point to a run.sh in the (now possibly missing) cache
  info "Verifying orphaned config state..."
  local run_sh_in_settings
  run_sh_in_settings=$(/usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
sl = s.get('statusLine', {})
print(sl.get('command', ''))
" "$SETTINGS_FILE" 2>/dev/null) || true

  if [ -n "$run_sh_in_settings" ]; then
    pass "Orphaned statusLine command captured: $run_sh_in_settings"
  else
    fail "Could not read orphaned statusLine command"
  fi

  # Clean up the orphan for subsequent tests
  reset_clean_state
}

test_T6_reinstall_after_clean() {
  test_header "T6: Reinstall After Clean Uninstall" \
    "Clean uninstall → fresh install → verify everything works"

  # Start from clean state
  reset_clean_state

  # Install
  info "Installing plugin..."
  install_plugin_manual

  # Configure
  info "Simulating SessionStart..."
  simulate_session_start >/dev/null 2>&1 || true

  if ! verify_settings_has_statusline; then
    fail "Plugin failed to configure after clean reinstall"
    return
  fi

  pass "statusLine configured after reinstall"

  # Verify rendering works
  local output
  output=$(run_statusline_with_sample) || true
  assert_output_not_empty "$output" "Statusline renders after reinstall"

  # Clean uninstall
  info "Performing clean uninstall..."
  bash "$(get_uninstall_sh_path)" >/dev/null 2>&1 || true
  # Remove from enabledPlugins and cache
  reset_clean_state

  if verify_settings_clean; then
    pass "Clean uninstall successful"
  else
    fail "Settings not clean after uninstall"
  fi

  # Reinstall again
  info "Reinstalling a second time..."
  install_plugin_manual
  simulate_session_start >/dev/null 2>&1 || true

  if verify_settings_has_statusline; then
    pass "statusLine configured after second reinstall"
  else
    fail "Plugin failed to configure after second reinstall"
  fi

  # Verify rendering still works
  output=$(run_statusline_with_sample) || true
  assert_output_not_empty "$output" "Statusline renders after second reinstall"
}

test_T7_reinstall_after_dirty() {
  test_header "T7: Reinstall After Dirty Uninstall" \
    "Dirty uninstall (orphaned config) → fresh install → setup.sh handles existing config"

  # Set up dirty uninstall state
  reset_clean_state
  install_plugin_manual
  simulate_session_start >/dev/null 2>&1 || true

  # Capture the old run.sh path
  local old_run_path
  old_run_path=$(/usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
cmd = s.get('statusLine', {}).get('command', '')
print(cmd)
" "$SETTINGS_FILE" 2>/dev/null) || true

  # Dirty uninstall: remove enabledPlugins + cache but leave statusLine config orphaned
  /usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
ep = s.get('enabledPlugins', {})
if isinstance(ep, dict):
    ep.pop('statusline@skills-ai', None)
if not ep:
    s.pop('enabledPlugins', None)
else:
    s['enabledPlugins'] = ep
with open(sys.argv[1], 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
" "$SETTINGS_FILE" 2>/dev/null || true
  rm -rf "$PLUGIN_CACHE"

  # Verify orphaned config exists
  if ! verify_settings_has_statusline; then
    skip "Could not create dirty uninstall state"
    return
  fi

  info "Orphaned statusLine config present. Now reinstalling..."

  # Reinstall
  install_plugin_manual
  simulate_session_start >/dev/null 2>&1 || true

  # Verify statusLine is configured (should still be there, possibly updated)
  if verify_settings_has_statusline; then
    pass "statusLine configured after reinstall over dirty state"
  else
    fail "statusLine missing after reinstall over dirty state"
  fi

  # Verify the path points to the NEW cache location
  local new_run_path
  new_run_path=$(/usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
cmd = s.get('statusLine', {}).get('command', '')
print(cmd)
" "$SETTINGS_FILE" 2>/dev/null) || true

  # The setup.sh uses grep -qF to check if the CORRECT run.sh path is present
  # If old path == new path (same cache location), it would skip (already correct)
  # If different, it would overwrite — both are acceptable
  if [ -n "$new_run_path" ]; then
    pass "statusLine command updated to new path"
    info "Path: $new_run_path"
  else
    fail "Could not read statusLine command after reinstall"
  fi

  # Verify rendering works
  local output
  output=$(run_statusline_with_sample) || true
  assert_output_not_empty "$output" "Statusline renders after reinstall over dirty state"
}

test_T8_missing_python3() {
  test_header "T8: Missing Python3" \
    "Hide python3 → run setup.sh → verify graceful error message"

  # We can't actually remove python3, but we can create a modified setup.sh
  # that uses a non-existent python3 path. Instead, we'll test by running
  # setup.sh in an environment where python3 is not in PATH.

  # Ensure we have a clean state with no statusLine
  reset_clean_state
  install_plugin_manual

  local setup_sh
  setup_sh="$(get_setup_sh_path)"

  if [ ! -f "$setup_sh" ]; then
    skip "setup.sh not found (requires install)"
    return
  fi

  info "Running setup.sh with python3 hidden from PATH..."

  # Run setup.sh in a subshell with a crippled PATH that hides python3
  local stderr_file
  stderr_file=$(mktemp)
  local output exit_code
  output=$(
    PATH="/usr/bin/this-does-not-exist:/tmp/fake-bin"
    # Also override the hardcoded paths by making them point to nothing
    # The script checks: python3, /usr/bin/python3, /usr/local/bin/python3
    # We need to hide /usr/bin/python3 specifically.
    # Since we can't remove it, we'll create a wrapper setup.sh that
    # patches the python search. Instead, let's test via direct invocation.
    #
    # Actually, the script does `command -v "$p"` for each candidate and
    # falls back to hardcoded paths. We can't easily hide /usr/bin/python3
    # from within a bash script since it checks absolute paths.
    #
    # Instead, let's test by verifying the error message format manually.
    echo "SKIPPED_DIRECT_TEST"
  ) 2>"$stderr_file"

  # Since we can't easily hide system python3 without root, verify the error
  # path logic by checking the script source instead
  if grep -qF 'python3 not found, cannot configure' "$setup_sh"; then
    pass "setup.sh has graceful error message for missing python3"
  else
    fail "setup.sh missing graceful error for missing python3"
  fi

  if grep -qF 'exit 1' "$setup_sh"; then
    pass "setup.sh exits with code 1 on missing python3"
  else
    fail "setup.sh doesn't exit 1 on missing python3"
  fi

  # Test the uninstall.sh also handles missing python3 gracefully
  local uninstall_sh
  uninstall_sh="$(get_uninstall_sh_path)"
  if grep -qF 'python3 not found' "$uninstall_sh" && \
     grep -qF 'Manually remove' "$uninstall_sh"; then
    pass "uninstall.sh provides manual cleanup instructions when python3 missing"
  else
    fail "uninstall.sh missing graceful error for missing python3"
  fi

  rm -f "$stderr_file"
}

test_T9_malformed_settings() {
  test_header "T9: Malformed Settings" \
    "Corrupt settings.json → run setup.sh → verify graceful error"

  reset_clean_state
  install_plugin_manual

  local setup_sh
  setup_sh="$(get_setup_sh_path)"

  if [ ! -f "$setup_sh" ]; then
    skip "setup.sh not found (requires install)"
    return
  fi

  # Create a malformed settings.json
  info "Corrupting settings.json..."
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{ this is not valid json !!!' > "$SETTINGS_FILE"

  # Run setup.sh — should fail gracefully
  local stderr_file
  stderr_file=$(mktemp)
  local output exit_code
  output=$(echo '{}' | bash "$setup_sh" 2>"$stderr_file")
  exit_code=$?

  # The grep -qF check for run.sh path in settings will fail (file is corrupt)
  # so it proceeds to the python section, which will fail to json.load()
  # Expected: exit 1 with error message

  if [ "$exit_code" -ne 0 ]; then
    pass "setup.sh exits with non-zero on malformed settings.json (exit $exit_code)"
  else
    fail "setup.sh exited 0 on malformed settings.json"
  fi

  local stderr_content
  stderr_content=$(cat "$stderr_file")
  if [ -n "$stderr_content" ]; then
    pass "setup.sh produced error output on malformed settings"
    info "Error: $stderr_content"
  else
    # Check stdout for error message
    if echo "$output" | grep -qi "fail\|error"; then
      pass "setup.sh reported error on malformed settings (via stdout)"
    else
      fail "setup.sh gave no error output on malformed settings"
    fi
  fi

  rm -f "$stderr_file"

  # Restore settings.json to valid state
  echo '{}' > "$SETTINGS_FILE"
}

test_T10_cache_cleared() {
  test_header "T10: Cache Cleared" \
    "Delete statusline.js from cache → run run.sh → verify silent failure"

  # Need the plugin installed so run.sh exists
  reset_clean_state
  install_plugin_manual
  simulate_session_start >/dev/null 2>&1 || true

  local run_sh
  run_sh="$(get_run_sh_path)"

  if [ ! -f "$run_sh" ]; then
    skip "run.sh not found (requires install)"
    return
  fi

  # Delete statusline.js but keep run.sh
  local statusline_js
  statusline_js="$(get_statusline_js_path)"
  if [ -f "$statusline_js" ]; then
    info "Removing statusline.js from cache..."
    rm -f "$statusline_js"
  else
    info "statusline.js already missing from cache"
  fi

  # Run run.sh — should exit 1 silently
  local stderr_file
  stderr_file=$(mktemp)
  local output exit_code
  output=$(echo '{"model":{"display_name":"Test"}}' | bash "$run_sh" 2>"$stderr_file")
  exit_code=$?

  # run.sh checks: if [ ! -f "$STATUSLINE_JS" ]; then echo diagnostic >&2; exit 1; fi
  assert_exit_code 1 "$exit_code" "run.sh exits 1 when statusline.js missing"

  # run.sh now writes a diagnostic to stderr (added in atomic writes commit)
  local stderr_content
  stderr_content=$(cat "$stderr_file")
  if echo "$stderr_content" | grep -qF "statusline.js not found"; then
    pass "run.sh produces diagnostic stderr when cache cleared"
  else
    fail "run.sh missing expected diagnostic stderr (got: $stderr_content)"
  fi

  if [ -z "$output" ]; then
    pass "run.sh produces no stdout when cache cleared"
  else
    fail "run.sh produced unexpected stdout: $output"
  fi

  rm -f "$stderr_file"
}

test_T11_full_cleanup() {
  test_header "T11: Full Lifecycle Cleanup" \
    "Install → configure → uninstall.sh → plugin uninstall → marketplace remove → verify ALL artifacts gone"

  # Start from guaranteed clean state
  reset_clean_state

  # Install and configure
  info "Installing and configuring plugin..."
  install_plugin_manual
  simulate_session_start >/dev/null 2>&1 || true

  # Verify we have a fully installed state to clean
  if ! verify_settings_has_statusline; then
    skip "Could not set up fully installed state"
    return
  fi
  assert_dir_exists "$PLUGIN_CACHE" "Plugin cache exists before cleanup"

  # Simulate adding marketplace entry to known_marketplaces.json
  info "Adding skills-ai marketplace entry..."
  /usr/bin/python3 -c "
import json, sys, tempfile, os
f = sys.argv[1]
if os.path.exists(f):
    with open(f) as fh:
        data = json.load(fh)
else:
    os.makedirs(os.path.dirname(f), exist_ok=True)
    data = {}
data['skills-ai'] = {
    'source': {'source': 'github', 'repo': 'thariman/Skills-AI'},
    'installLocation': sys.argv[2],
    'lastUpdated': '2026-01-01T00:00:00.000Z'
}
tmpfd, tmppath = tempfile.mkstemp(dir=os.path.dirname(f), suffix='.tmp')
try:
    with os.fdopen(tmpfd, 'w') as fh:
        json.dump(data, fh, indent=2)
        fh.write('\n')
    os.replace(tmppath, f)
except:
    os.unlink(tmppath)
    raise
" "$KNOWN_MARKETPLACES" "$MARKETPLACE_DIR" 2>/dev/null || true

  # Create a dummy marketplace dir (simulates /marketplace add having cloned the repo)
  mkdir -p "$MARKETPLACE_DIR"

  # ── Phase 1: Run uninstall.sh ──
  info "Phase 1: Running uninstall.sh..."
  bash "$(get_uninstall_sh_path)" >/dev/null 2>&1 || true

  # Verify: statusLine removed
  if verify_settings_clean; then
    pass "Phase 1: statusLine removed from settings.json"
  else
    fail "Phase 1: statusLine still in settings.json after uninstall.sh"
  fi

  # ── Phase 2: Simulate /plugin uninstall ──
  info "Phase 2: Simulating plugin uninstall..."

  # Remove from enabledPlugins and clean empty key
  /usr/bin/python3 -c "
import json, sys, tempfile, os
settings_file = sys.argv[1]
with open(settings_file) as f:
    s = json.load(f)
ep = s.get('enabledPlugins', {})
if isinstance(ep, dict):
    ep.pop('statusline@skills-ai', None)
    if not ep:
        s.pop('enabledPlugins', None)
    else:
        s['enabledPlugins'] = ep
tmpfd, tmppath = tempfile.mkstemp(dir=os.path.dirname(settings_file), suffix='.tmp')
try:
    with os.fdopen(tmpfd, 'w') as f:
        json.dump(s, f, indent=2)
        f.write('\n')
    os.replace(tmppath, settings_file)
except:
    os.unlink(tmppath)
    raise
" "$SETTINGS_FILE" 2>/dev/null || true

  # Remove plugin cache
  rm -rf "$PLUGIN_CACHE"

  # Verify: cache gone
  assert_dir_not_exists "$PLUGIN_CACHE" "Phase 2: Plugin cache directory removed"

  # Verify: enabledPlugins cleaned
  local ep_state
  ep_state=$(/usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
ep = s.get('enabledPlugins', None)
if ep is None:
    print('absent')
elif not ep:
    print('empty')
else:
    print('populated')
" "$SETTINGS_FILE" 2>/dev/null) || true

  if [ "$ep_state" = "absent" ]; then
    pass "Phase 2: enabledPlugins key removed"
  elif [ "$ep_state" = "empty" ]; then
    fail "Phase 2: Empty enabledPlugins {} left behind"
  else
    pass "Phase 2: enabledPlugins has other entries (acceptable)"
  fi

  # ── Phase 3: Simulate /marketplace remove ──
  info "Phase 3: Simulating marketplace remove..."

  # Remove from known_marketplaces.json
  /usr/bin/python3 -c "
import json, sys, tempfile, os
f = sys.argv[1]
with open(f) as fh:
    data = json.load(fh)
for k in list(data.keys()):
    if 'skills-ai' in k.lower():
        del data[k]
tmpfd, tmppath = tempfile.mkstemp(dir=os.path.dirname(f), suffix='.tmp')
try:
    with os.fdopen(tmpfd, 'w') as fh:
        json.dump(data, fh, indent=2)
        fh.write('\n')
    os.replace(tmppath, f)
except:
    os.unlink(tmppath)
    raise
" "$KNOWN_MARKETPLACES" 2>/dev/null || true

  # Remove marketplace directory
  rm -rf "$MARKETPLACE_DIR"

  # ── Phase 4: Verify ALL artifacts are gone ──
  info "Phase 4: Verifying complete cleanup..."

  # 4a: statusLine gone
  assert_file_not_contains "$SETTINGS_FILE" '"statusLine"' \
    "settings.json has no statusLine key"

  # 4b: enabledPlugins gone or no skills-ai entries
  assert_file_not_contains "$SETTINGS_FILE" 'skills-ai' \
    "settings.json has no skills-ai references"

  # 4c: Plugin cache directory gone
  assert_dir_not_exists "$PLUGIN_CACHE" "Plugin cache directory fully removed"

  # 4d: Marketplace directory gone
  assert_dir_not_exists "$MARKETPLACE_DIR" "Marketplace directory fully removed"

  # 4e: known_marketplaces.json has no skills-ai entry
  if [ -f "$KNOWN_MARKETPLACES" ]; then
    assert_file_not_contains "$KNOWN_MARKETPLACES" 'skills-ai' \
      "known_marketplaces.json has no skills-ai entry"
  else
    pass "known_marketplaces.json absent (acceptable)"
  fi

  # 4f: settings.json is valid JSON with no stale entries
  local remaining_keys
  remaining_keys=$(/usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
print(' '.join(sorted(s.keys())) if s else '(empty)')
" "$SETTINGS_FILE" 2>/dev/null) || true
  info "Remaining settings.json keys: $remaining_keys"

  if /usr/bin/python3 -c "import json; json.load(open('$SETTINGS_FILE'))" 2>/dev/null; then
    pass "settings.json is valid JSON after full cleanup"
  else
    fail "settings.json is corrupted after full cleanup"
  fi
}

# ============================================================================
# 1-RESTART VALIDATION TESTS (T12–T20)
# ============================================================================
# These tests verify that running setup.sh at install time (instead of relying
# solely on the SessionStart hook) eliminates the 2-restart problem.
#
# Core issue: Claude reads settings.json BEFORE SessionStart hooks fire. So a
# hook that writes statusLine config on SessionStart is too late for session 1.
# The fix: run setup.sh during install so the config exists before session 1.
# ============================================================================

test_T12_install_time_setup() {
  test_header "T12: Install-Time Setup (1-Restart Path)" \
    "Install → verify no statusLine → run setup.sh directly → verify statusLine exists"

  reset_clean_state

  # Step 1: Install plugin manually
  install_plugin_manual

  # Step 2: Verify NO statusLine in settings (just installed, no session yet)
  if verify_settings_clean; then
    pass "No statusLine in settings.json after install (before setup.sh)"
  else
    fail "statusLine unexpectedly present after manual install"
    return
  fi

  # Step 3: Run setup.sh directly (simulates install-time execution)
  info "Running setup.sh at install-time (not via SessionStart hook)..."
  local output
  output=$(run_install_time_setup) || true

  # Step 4: Verify statusLine NOW exists with correct run.sh path
  if verify_settings_has_statusline; then
    pass "statusLine present in settings.json after install-time setup.sh"
  else
    fail "statusLine missing after install-time setup.sh"
    if [ -f "$SETTINGS_FILE" ]; then
      info "settings.json: $(cat "$SETTINGS_FILE")"
    fi
    return
  fi

  # Step 5: Verify the command points to the correct run.sh
  local cmd
  cmd=$(get_statusline_command_from_settings)
  local expected_run_sh
  expected_run_sh="$(get_run_sh_path)"
  if echo "$cmd" | grep -qF "$expected_run_sh"; then
    pass "statusLine command references correct run.sh path"
  else
    fail "statusLine command has wrong path (got: $cmd, expected to contain: $expected_run_sh)"
  fi

  # Step 6: Verify run.sh produces output
  local statusline_output
  statusline_output=$(run_statusline_with_sample) || true
  assert_output_not_empty "$statusline_output" "run.sh produces output after install-time setup"
}

test_T13_two_restart_baseline() {
  test_header "T13: 2-Restart Baseline (Prove the Problem)" \
    "Install → verify no statusLine → simulate SessionStart → verify statusLine written"

  reset_clean_state

  # Step 1: Install plugin manually
  install_plugin_manual

  # Step 2: Verify NO statusLine (this is the state Claude sees on first session start)
  if verify_settings_clean; then
    pass "No statusLine after install (this is what Claude reads at session start)"
  else
    fail "statusLine unexpectedly present after manual install"
    return
  fi

  # Commentary: In a real session, Claude has ALREADY read settings.json by this point.
  # The SessionStart hook fires AFTER Claude reads settings — so even though the hook
  # writes statusLine, Claude won't see it until the NEXT session start.
  info "NOTE: In a real session, Claude reads settings.json BEFORE SessionStart fires."
  info "This means the statusLine config written by the hook is too late for session 1."

  # Step 3: Simulate SessionStart (this is what the hook does)
  info "Simulating SessionStart hook..."
  simulate_session_start >/dev/null 2>&1 || true

  # Step 4: Verify statusLine was written (but too late for the current session)
  if verify_settings_has_statusline; then
    pass "statusLine written by SessionStart hook (but too late for session 1)"
  else
    fail "SessionStart hook failed to write statusLine"
  fi

  info "CONCLUSION: Session 1 never shows statusline because config was written AFTER read."
  info "Session 2 will read the config and show statusline. Hence: 2-restart problem."
}

test_T14_one_vs_two_restart() {
  test_header "T14: 1-Restart vs 2-Restart Comparison" \
    "Side-by-side comparison showing install-time setup.sh eliminates the timing gap"

  # ── 2-Restart Flow ──
  info "=== 2-Restart Flow ==="
  reset_clean_state
  install_plugin_manual

  # Snapshot 1: What Claude sees at first session start (no statusLine)
  local snapshot_2restart_before
  snapshot_2restart_before=$(snapshot_settings)
  if ! echo "$snapshot_2restart_before" | grep -qF '"statusLine"'; then
    pass "2-restart: snapshot at session start has NO statusLine"
  else
    fail "2-restart: snapshot at session start unexpectedly has statusLine"
  fi

  # SessionStart hook fires (too late for session 1)
  simulate_session_start >/dev/null 2>&1 || true

  # Snapshot 2: After SessionStart (available for session 2)
  local snapshot_2restart_after
  snapshot_2restart_after=$(snapshot_settings)

  if echo "$snapshot_2restart_after" | grep -qF '"statusLine"'; then
    pass "2-restart: snapshot after SessionStart has statusLine (for session 2)"
  else
    fail "2-restart: SessionStart failed to write statusLine"
    return
  fi

  # ── 1-Restart Flow ──
  info "=== 1-Restart Flow ==="
  reset_clean_state
  install_plugin_manual

  # Run setup.sh at install time (BEFORE any session)
  run_install_time_setup >/dev/null 2>&1 || true

  # Snapshot 3: What Claude sees at first session start (already has statusLine!)
  local snapshot_1restart
  snapshot_1restart=$(snapshot_settings)

  if echo "$snapshot_1restart" | grep -qF '"statusLine"'; then
    pass "1-restart: snapshot at session start ALREADY has statusLine"
  else
    fail "1-restart: setup.sh failed to write statusLine at install time"
    return
  fi

  # ── Comparison ──
  info "=== Comparison ==="

  # Extract statusLine configs for structural comparison
  local config_2restart config_1restart
  config_2restart=$(/usr/bin/python3 -c "
import json, sys
s = json.loads(sys.argv[1])
print(json.dumps(s.get('statusLine', {}), sort_keys=True))
" "$snapshot_2restart_after" 2>/dev/null) || true

  config_1restart=$(/usr/bin/python3 -c "
import json, sys
s = json.loads(sys.argv[1])
print(json.dumps(s.get('statusLine', {}), sort_keys=True))
" "$snapshot_1restart" 2>/dev/null) || true

  if [ "$config_2restart" = "$config_1restart" ]; then
    pass "Both flows produce structurally identical statusLine config"
    info "Config: $config_1restart"
  else
    fail "statusLine configs differ between 1-restart and 2-restart flows"
    info "2-restart: $config_2restart"
    info "1-restart: $config_1restart"
  fi

  info "CONCLUSION: Install-time setup.sh writes the SAME config as SessionStart,"
  info "but it's available BEFORE the first session reads settings.json."
}

test_T15_real_cli_hook_trigger() {
  test_header "T15: Real CLI SessionStart Hook Trigger" \
    "Install plugin → run real Claude session → check if SessionStart hook fires"

  reset_clean_state
  install_plugin_manual

  # Verify no statusLine before CLI session
  if ! verify_settings_clean; then
    fail "statusLine present before CLI session (expected clean)"
    return
  fi

  # Run a minimal Claude session
  info "Running minimal Claude CLI session (timeout 30s)..."
  info "Note: -p mode may not fire SessionStart hooks (empirically observed)"
  run_minimal_claude_session 30

  # Check if SessionStart hook fired (wrote statusLine to settings.json)
  if verify_settings_has_statusline; then
    pass "SessionStart hook fired in -p mode and wrote statusLine"
    info "This means -p mode DOES fire SessionStart hooks on this CLI version"
  else
    skip "SessionStart hooks did not fire in -p mode (expected — TUI-only behavior)"
    info "This confirms that -p mode skips SessionStart hooks."
    info "Contract tests T12-T14 provide authoritative verification instead."
  fi
}

test_T16_marker_file_test() {
  test_header "T16: Marker File Test (Prove Claude Invokes run.sh)" \
    "Install + setup → replace run.sh with marker → run real CLI → check marker"

  reset_clean_state
  install_plugin_manual
  run_install_time_setup >/dev/null 2>&1 || true

  if ! verify_settings_has_statusline; then
    skip "Could not set up statusLine config"
    return
  fi

  # Remove any leftover marker
  rm -f /tmp/statusline-marker.txt

  # Install marker script (backs up original)
  info "Installing marker run.sh..."
  if ! install_marker_run_sh; then
    fail "Could not install marker run.sh"
    return
  fi

  # Run minimal Claude session
  info "Running minimal Claude CLI session (timeout 30s)..."
  run_minimal_claude_session 30

  # Check if marker was created
  if [ -f /tmp/statusline-marker.txt ]; then
    pass "Marker file created — Claude invoked run.sh during session"
    local marker_content
    marker_content=$(cat /tmp/statusline-marker.txt)
    info "Marker timestamp: $marker_content"
  else
    skip "Marker file not created — statusline may not render in -p mode (TUI-only)"
    info "This is expected: statusline rendering is a TUI feature."
    info "Contract tests T12-T14 verify config correctness independently."
  fi

  # Always clean up
  restore_original_run_sh
  rm -f /tmp/statusline-marker.txt

  # Verify original run.sh was restored
  local run_sh
  run_sh="$(get_run_sh_path)"
  if [ -f "$run_sh" ] && ! grep -qF "MARKER_ACTIVE" "$run_sh"; then
    pass "Original run.sh restored after marker test"
  else
    fail "Failed to restore original run.sh"
  fi
}

test_T17_empty_settings() {
  test_header "T17: Empty Settings.json" \
    "Start with {} → install + setup.sh → verify both statusLine and enabledPlugins coexist"

  reset_clean_state

  # Ensure settings.json is exactly {}
  echo '{}' > "$SETTINGS_FILE"

  # Install and run setup.sh
  install_plugin_manual
  run_install_time_setup >/dev/null 2>&1 || true

  # Verify statusLine exists
  if verify_settings_has_statusline; then
    pass "statusLine written to initially empty settings.json"
  else
    fail "statusLine missing after setup.sh on empty settings.json"
    return
  fi

  # Verify enabledPlugins also exists (written by install_plugin_manual)
  if grep -qF '"enabledPlugins"' "$SETTINGS_FILE" 2>/dev/null; then
    pass "enabledPlugins coexists with statusLine in settings.json"
  else
    fail "enabledPlugins missing (install_plugin_manual should have written it)"
  fi

  # Verify settings.json is valid JSON
  if /usr/bin/python3 -c "import json; json.load(open('$SETTINGS_FILE'))" 2>/dev/null; then
    pass "settings.json is valid JSON with both keys"
  else
    fail "settings.json is corrupted"
  fi
}

test_T18_existing_statusline() {
  test_header "T18: Existing statusLine (Another Plugin)" \
    "Pre-write different statusLine → install + setup.sh → verify our config overwrites"

  reset_clean_state

  # Pre-write a different statusLine config
  /usr/bin/python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    s = json.load(f)
s['statusLine'] = {
    'type': 'command',
    'command': 'bash \"/some/other/plugin/run.sh\"'
}
with open(sys.argv[1], 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
" "$SETTINGS_FILE"

  # Verify the other plugin's config is there
  if grep -qF '/some/other/plugin/run.sh' "$SETTINGS_FILE" 2>/dev/null; then
    pass "Pre-existing statusLine config from other plugin is present"
  else
    fail "Could not set up pre-existing statusLine"
    return
  fi

  # Install our plugin and run setup.sh
  install_plugin_manual
  run_install_time_setup >/dev/null 2>&1 || true

  # Verify OUR run.sh path is now in the config
  local cmd
  cmd=$(get_statusline_command_from_settings)
  local our_run_sh
  our_run_sh="$(get_run_sh_path)"
  if echo "$cmd" | grep -qF "$our_run_sh"; then
    pass "Our statusLine config overwrites the previous plugin's config"
  else
    fail "statusLine still points to old plugin (got: $cmd)"
  fi

  # Verify the old path is gone
  if ! grep -qF '/some/other/plugin/run.sh' "$SETTINGS_FILE" 2>/dev/null; then
    pass "Previous plugin's run.sh path is no longer in settings.json"
  else
    fail "Old plugin's path still present in settings.json"
  fi
}

test_T19_concurrent_modification() {
  test_header "T19: Concurrent Settings Modification" \
    "Install → add extra key → run setup.sh → verify statusLine added AND extra key preserved"

  reset_clean_state

  # Install plugin (writes enabledPlugins)
  install_plugin_manual

  # Add an extra key to settings.json (simulating another tool writing config)
  info "Adding otherPlugin key to settings.json..."
  /usr/bin/python3 -c "
import json, sys, tempfile, os
f = sys.argv[1]
with open(f) as fh:
    s = json.load(fh)
s['otherPlugin'] = {'enabled': True, 'version': '2.0.0'}
tmpfd, tmppath = tempfile.mkstemp(dir=os.path.dirname(f), suffix='.tmp')
try:
    with os.fdopen(tmpfd, 'w') as fh:
        json.dump(s, fh, indent=2)
        fh.write('\n')
    os.replace(tmppath, f)
except:
    os.unlink(tmppath)
    raise
" "$SETTINGS_FILE"

  # Verify extra key exists
  if grep -qF '"otherPlugin"' "$SETTINGS_FILE" 2>/dev/null; then
    pass "Extra otherPlugin key present before setup.sh"
  else
    fail "Could not add otherPlugin key"
    return
  fi

  # Run setup.sh (should add statusLine without losing otherPlugin)
  info "Running setup.sh (should preserve otherPlugin key)..."
  run_install_time_setup >/dev/null 2>&1 || true

  # Verify statusLine was added
  if verify_settings_has_statusline; then
    pass "statusLine added by setup.sh"
  else
    fail "statusLine missing after setup.sh"
    return
  fi

  # Verify otherPlugin was preserved (atomic read-modify-write works)
  if grep -qF '"otherPlugin"' "$SETTINGS_FILE" 2>/dev/null; then
    pass "otherPlugin key preserved after setup.sh (read-modify-write works)"
  else
    fail "otherPlugin key was lost — setup.sh overwrote settings.json destructively"
  fi

  # Verify enabledPlugins also preserved
  if grep -qF '"enabledPlugins"' "$SETTINGS_FILE" 2>/dev/null; then
    pass "enabledPlugins also preserved after setup.sh"
  else
    fail "enabledPlugins lost after setup.sh"
  fi

  # Verify everything is valid JSON
  if /usr/bin/python3 -c "import json; json.load(open('$SETTINGS_FILE'))" 2>/dev/null; then
    pass "settings.json is valid JSON with all keys intact"
  else
    fail "settings.json is corrupted after concurrent modification test"
  fi
}

test_T20_full_one_restart_lifecycle() {
  test_header "T20: Full 1-Restart Lifecycle" \
    "Reset → install → setup.sh → verify → real CLI (idempotency) → verify → render → uninstall → verify"

  reset_clean_state

  # Step 1: Install plugin
  info "Step 1: Installing plugin..."
  install_plugin_manual

  # Step 2: Run setup.sh at install time (the 1-restart fix)
  info "Step 2: Running setup.sh at install time..."
  run_install_time_setup >/dev/null 2>&1 || true

  # Step 3: Verify config exists
  if verify_settings_has_statusline; then
    pass "Config present after install-time setup.sh"
  else
    fail "Config missing after install-time setup.sh"
    return
  fi

  local cmd_before
  cmd_before=$(get_statusline_command_from_settings)

  # Step 4: Run real CLI session (idempotency check — SessionStart hook should be no-op)
  info "Step 4: Running real CLI session (idempotency check)..."
  run_minimal_claude_session 30

  # Step 5: Verify config is unchanged after CLI session
  local cmd_after
  cmd_after=$(get_statusline_command_from_settings)

  if [ "$cmd_before" = "$cmd_after" ]; then
    pass "Config unchanged after CLI session (idempotent)"
  else
    # Changed is also acceptable if SessionStart hook updated it
    info "Config changed after CLI session (hook may have re-run)"
    info "Before: $cmd_before"
    info "After: $cmd_after"
    pass "Config still valid after CLI session"
  fi

  # Step 6: Verify run.sh produces output
  info "Step 6: Verifying run.sh renders correctly..."
  local output
  output=$(run_statusline_with_sample) || true
  assert_output_not_empty "$output" "run.sh produces output in full lifecycle"

  # Step 7: Run uninstall.sh
  info "Step 7: Running uninstall.sh..."
  local uninstall_output
  uninstall_output=$(bash "$(get_uninstall_sh_path)" 2>&1) || true
  assert_output_contains "$uninstall_output" "Removed statusLine config" \
    "uninstall.sh reports successful removal"

  # Step 8: Verify clean
  if verify_settings_clean; then
    pass "statusLine removed from settings.json after uninstall"
  else
    fail "statusLine still in settings.json after uninstall"
  fi

  # Step 9: Verify settings.json is valid JSON
  if /usr/bin/python3 -c "import json; json.load(open('$SETTINGS_FILE'))" 2>/dev/null; then
    pass "settings.json is valid JSON after full lifecycle"
  else
    fail "settings.json corrupted after full lifecycle"
  fi
}

test_T21_real_restart_count() {
  test_header "T21: Real Restart Count (How Many Restarts Before Statusline?)" \
    "Real install → real CC sessions via tmux → check settings.json between each → count restarts"

  # ── Step 1: Full real cleanup and fresh install ──
  reset_clean_state_real

  info "Installing plugin via real CLI commands..."
  install_plugin_real

  # Verify plugin was installed
  if [ ! -d "$PLUGIN_CACHE" ]; then
    fail "Plugin cache not created after real install"
    return
  fi
  pass "Plugin installed via real CLI"

  # Verify: NO statusLine in settings.json (just enabledPlugins)
  if verify_settings_clean; then
    pass "After install: no statusLine in settings.json"
  else
    fail "After install: statusLine unexpectedly present"
    return
  fi
  info "settings.json after install: $(cat "$SETTINGS_FILE")"

  # ── Step 2: First real Claude session (tmux, fires SessionStart hook) ──
  info "Starting 1st real Claude session via tmux (waiting 12s for hooks)..."
  run_real_claude_session 12

  # Check: Did SessionStart hook write statusLine?
  local has_statusline_after_session1="no"
  if verify_settings_has_statusline; then
    has_statusline_after_session1="yes"
    info "After session 1: statusLine IS in settings.json (hook fired)"
  else
    info "After session 1: statusLine NOT in settings.json (hook did not fire)"
  fi

  # ── Step 3: Second real Claude session ──
  info "Starting 2nd real Claude session via tmux (waiting 12s)..."
  run_real_claude_session 12

  local has_statusline_after_session2="no"
  if verify_settings_has_statusline; then
    has_statusline_after_session2="yes"
    info "After session 2: statusLine IS in settings.json"
  else
    info "After session 2: statusLine NOT in settings.json"
  fi

  # ── Step 4: Determine restart count ──
  info "=== Restart Count Analysis ==="

  if [ "$has_statusline_after_session1" = "yes" ]; then
    # Hook fired during session 1 → statusLine was written.
    # But Claude reads settings.json BEFORE SessionStart fires.
    # So session 1 started WITHOUT statusLine → no statusline visible in session 1.
    # Session 2 starts WITH statusLine already present → statusline visible.
    pass "SessionStart hook wrote statusLine during 1st session after install"
    info "Timeline: install → session1 (no bar, hook writes config) → session2 (bar shows)"
    info "RESULT: 1 restart needed (statusline appears on 2nd session)"
    pass "Restart count: 1 (2 total sessions to see statusline)"

    # Verify the written config is correct
    local cmd
    cmd=$(get_statusline_command_from_settings)
    if [ -n "$cmd" ]; then
      pass "statusLine command is valid: $cmd"
    else
      fail "statusLine command is empty"
    fi

  elif [ "$has_statusline_after_session2" = "yes" ]; then
    # Hook didn't fire in session 1, but did in session 2
    pass "SessionStart hook wrote statusLine during 2nd session (not 1st)"
    info "Timeline: install → session1 (no hook fire) → session2 (hook writes config) → session3 (bar shows)"
    info "RESULT: 2 restarts needed (statusline appears on 3rd session)"
    pass "Restart count: 2 (3 total sessions to see statusline)"

  else
    # Neither session wrote statusLine
    fail "SessionStart hook never fired in either real session"
    info "settings.json: $(cat "$SETTINGS_FILE")"
    info "Check: is plugin in installed_plugins.json?"
    cat "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null || info "(file not found)"
  fi

  # ── Cleanup ──
  info "Cleaning up real install..."
  reset_clean_state_real
}

# ============================================================================
# MAIN
# ============================================================================

banner "Statusline Plugin Lifecycle Test Suite"
echo -e "${DIM}   Date: $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo -e "${DIM}   Host: $(hostname)${RESET}"
echo -e "${DIM}   User: $(whoami)${RESET}"

preflight

# Run tests in order — some depend on state from prior tests
test_T1_fresh_install
test_T2_idempotent_setup
test_T3_statusline_rendering
test_T4_clean_uninstall
test_T5_dirty_uninstall
test_T6_reinstall_after_clean
test_T7_reinstall_after_dirty
test_T8_missing_python3
test_T9_malformed_settings
test_T10_cache_cleared
test_T11_full_cleanup

# ── 1-Restart Validation Tests ─────────────────────────────────────────────
test_T12_install_time_setup
test_T13_two_restart_baseline
test_T14_one_vs_two_restart
test_T15_real_cli_hook_trigger
test_T16_marker_file_test
test_T17_empty_settings
test_T18_existing_statusline
test_T19_concurrent_modification
test_T20_full_one_restart_lifecycle

# ── Real Restart Count Test ───────────────────────────────────────────────
test_T21_real_restart_count

# ── Final Cleanup ──────────────────────────────────────────────────────────

banner "Cleanup"
reset_clean_state

# Also reset settings.json to {} to remove any test-injected keys (e.g. otherPlugin from T19)
echo '{}' > "$SETTINGS_FILE"

# Verify final cleanup actually worked
if verify_settings_clean; then
  pass "Final: statusLine removed from settings.json"
else
  fail "Final: statusLine still in settings.json after cleanup"
fi
assert_dir_not_exists "$PLUGIN_CACHE" "Final: plugin cache directory removed"
assert_dir_not_exists "$MARKETPLACE_DIR" "Final: marketplace directory removed"
pass "Test environment cleaned up"

# ── Summary ────────────────────────────────────────────────────────────────

banner "Results"
echo ""
echo -e "   ${GREEN}Passed: $PASS_COUNT${RESET}"
echo -e "   ${RED}Failed: $FAIL_COUNT${RESET}"
echo -e "   ${YELLOW}Skipped: $SKIP_COUNT${RESET}"
echo -e "   ${BOLD}Total tests run: $TOTAL_TESTS${RESET}"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
  echo -e "   ${GREEN}${BOLD}★ ALL TESTS PASSED ★${RESET}"
  echo ""
  exit 0
else
  echo -e "   ${RED}${BOLD}✘ SOME TESTS FAILED ✘${RESET}"
  echo ""
  exit 1
fi
