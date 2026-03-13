# Tools-AI

A Claude Code plugin marketplace with productivity-focused plugins.

## Plugins

### Statusline

A rich status line for Claude Code that displays at-a-glance session info:

- **Model** — current Claude model in use
- **Active task** — what Claude is currently working on (from the task list)
- **Directory** — current working directory
- **Git branch & status** — branch name with clean (✔) or dirty (●) indicator
- **Context window usage** — 10-segment progress bar with color-coded thresholds
- **Update checker** — notifies when a new Claude Code version is available

```
Opus 4.6 │ Fixing auth bug │ my-project │ main ✔ █████░░░░░ 50% │ ⬆ v2.2.0
```

Context window colors shift from green → yellow → orange → red as usage increases, with a skull (💀) warning above 80%.

The update checker queries the npm registry on session start (with a 4-hour cooldown) and compares against your running version. When a new version is found, the `⬆ v{version}` indicator appears in the status bar and a full notification with GitHub release notes is displayed at session start.

### Rename

Automatically names Claude Code sessions on startup using the current directory name plus an incrementing counter:

```
Tools-AI-1    Tools-AI-2    my-project-1    my-project-2
```

- Names sessions instantly on `SessionStart` — no manual `/rename` needed
- Counter is per-directory, stored in `~/.claude/rename/state.json`
- Writes directly to the session JSONL file for immediate effect
- Falls back gracefully if `python3` is unavailable

**Install:**

```
/plugin install rename@tools-ai
```

**Uninstall:**

```bash
bash ~/.claude/plugins/cache/tools-ai/rename/*/scripts/uninstall.sh
/plugin uninstall rename@tools-ai
```

### Export Claude-Mem Memories

A standalone script to export memories from [claude-mem](https://github.com/thedotmack/claude-mem) to JSON. By default exports all data (observations, sessions, and prompts). Use `--prompts-only` to export just user prompts.

**HTTP API mode** (default) — queries a running claude-mem server:

```bash
# Full export: observations, sessions, and prompts
./export-claude-mem-prompts.sh

# User prompts only
./export-claude-mem-prompts.sh --prompts-only

# Custom output file and port
./export-claude-mem-prompts.sh my-memories.json 38888
```

Requires `curl` and a running claude-mem server.

**SQLite mode** (`--db`) — reads the database directly:

```bash
# Full export
./export-claude-mem-prompts.sh --db

# User prompts only
./export-claude-mem-prompts.sh --db --prompts-only

# Custom output file and db path
./export-claude-mem-prompts.sh --db my-prompts.json /path/to/claude-mem.db
```

Requires `sqlite3`. Flags (`--db`, `--prompts-only`) can be combined in any order.

## Installation

Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.33+.

**1. Add the marketplace:**

```
/plugin marketplace add thariman/Tools-AI
```

**2. Install plugins:**

```
/plugin install statusline@tools-ai
/plugin install rename@tools-ai
```

**3. Start using Claude Code** — both plugins are automatically configured on the first session start via `SessionStart` hooks. The statusline appears after your first interaction and sessions are auto-named immediately (no restart needed).

> **How it works:** On the first session after install, a `SessionStart` hook runs `setup.sh` which copies the statusline files to a persistent location (`~/.claude/statusline/`) and writes the `statusLine` config to `~/.claude/settings.json`. This ensures the status line survives plugin cache clears and Claude Code updates. Claude Code auto-reloads settings after each interaction, so the status bar appears as soon as you send your first message. A `UserPromptSubmit` hook also runs `setup.sh` as a safety net, ensuring the config is written before any interaction triggers the reload.

## Uninstalling

**1. Run the uninstall script for the plugin(s) you want to remove:**

```bash
# Statusline
bash ~/.claude/plugins/cache/tools-ai/statusline/*/scripts/uninstall.sh

# Rename
bash ~/.claude/plugins/cache/tools-ai/rename/*/scripts/uninstall.sh
```

**2. Uninstall the plugin(s):**

```
/plugin uninstall statusline@tools-ai
/plugin uninstall rename@tools-ai
```

> **Important:** Run `uninstall.sh` first. The plugin system doesn't have a lifecycle hook for uninstall, so if you skip step 1, persistent files and config will remain orphaned (they won't cause errors, but you'll need to manually clean up `~/.claude/statusline/` or `~/.claude/rename/`).

To remove the marketplace source entirely:

```
/plugin marketplace remove tools-ai
```

## How It Works

```
Plugin Install
  └─ adds to enabledPlugins, caches plugin files

First Session Start
  └─ SessionStart hook fires
       ├─ setup.sh runs (~500ms)
       │    ├─ copies run.sh + statusline.js + check-update files to ~/.claude/statusline/
       │    └─ python3 writes statusLine config to ~/.claude/settings.json
       └─ check-update.sh runs
            └─ node check-update.js
                 ├─ claude --version → current version
                 ├─ npm registry → latest version
                 ├─ GitHub releases → release notes (if update available)
                 └─ writes ~/.claude/statusline/update-cache.json

First User Interaction (same session)
  └─ UserPromptSubmit hook fires → setup.sh runs (idempotent, ~7ms)
  └─ Claude auto-reloads settings.json
       └─ reads statusLine config → runs bash ~/.claude/statusline/run.sh
            └─ run.sh finds node → exec node statusline.js
                 ├─ reads JSON from stdin → renders status bar
                 └─ reads update-cache.json → shows ⬆ indicator if update available
```

The `SessionStart` and `UserPromptSubmit` hooks also act as a **self-healing mechanism**: if the `statusLine` config is accidentally removed from `settings.json`, or if the persistent files are deleted, the next session start or prompt will restore them automatically.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `python3` not available | `setup.sh` fails with clear error message |
| `settings.json` missing | Created from scratch with valid JSON |
| `settings.json` malformed | `setup.sh` fails gracefully, doesn't corrupt further |
| Plugin cache cleared | Status line keeps working (files persisted to `~/.claude/statusline/`) |
| Persistent files deleted | Self-heals on next session start (re-copies from cache) |
| Config manually deleted | Self-heals on next session start |
| Existing manual statusLine | Overwritten by plugin config |
| npm registry unreachable | Update check skipped silently, status bar still renders |
| GitHub API unavailable | Update shown without release notes |
| `claude --version` fails | Update check skipped, cached result used if available |

## Compatibility

The statusline plugin works across different Node.js installation methods:

- System node (`/usr/local/bin/node`)
- **nvm** / **fnm** (sourced automatically)
- **volta** (detected via `VOLTA_HOME`)
- **nodeenv** (used by Claude Code's own installer)
- **Homebrew** (`/opt/homebrew/bin/node`)

No global `node` in PATH is required — the plugin discovers it automatically.

## Plugin Structure

Each plugin follows the standard Claude Code plugin layout:

```
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json        # Plugin metadata (name, version, description)
├── hooks/
│   └── hooks.json         # Hook event registrations (SessionStart, etc.)
├── scripts/
│   ├── setup.sh           # Auto-configuration + persistent file copy
│   └── uninstall.sh       # Pre-uninstall cleanup (removes persistent files)
└── <plugin files>         # Plugin-specific scripts and logic
```

## License

MIT
