# Skills-AI

A Claude Code plugin marketplace with productivity-focused plugins.

## Plugins

### Statusline

A rich status line for Claude Code that displays at-a-glance session info:

- **Model** — current Claude model in use
- **Active task** — what Claude is currently working on (from the task list)
- **Directory** — current working directory
- **Git branch & status** — branch name with clean (✔) or dirty (●) indicator
- **Context window usage** — 10-segment progress bar with color-coded thresholds

```
Opus 4.6 │ Fixing auth bug │ my-project │ main ✔ █████░░░░░ 50%
```

Context window colors shift from green → yellow → orange → red as usage increases, with a skull (💀) warning above 80%.

## Installation

Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v1.0.33+.

**1. Add the marketplace:**

```
/plugin marketplace add thariman/Skills-AI
```

**2. Install the plugin:**

```
/plugin install statusline@skills-ai
```

**3. Start using Claude Code** — the statusline is automatically configured on the first session start via a `SessionStart` hook and appears after your first interaction (no restart needed).

> **How it works:** On the first session after install, a `SessionStart` hook runs `setup.sh` which writes the `statusLine` config to `~/.claude/settings.json`. Claude Code auto-reloads settings after each interaction, so the status bar appears as soon as you send your first message. A `UserPromptSubmit` hook also runs `setup.sh` as a safety net, ensuring the config is written before any interaction triggers the reload.

## Uninstalling

**1. Remove the statusLine config:**

```bash
bash ~/.claude/plugins/cache/skills-ai/statusline/*/scripts/uninstall.sh
```

**2. Uninstall the plugin:**

```
/plugin uninstall statusline@skills-ai
```

> **Important:** Run `uninstall.sh` first. The plugin system doesn't have a lifecycle hook for uninstall, so if you skip step 1, the `statusLine` config will remain orphaned in `settings.json` (it won't cause errors, but you'll need to manually remove the `statusLine` key).

To remove the marketplace source entirely:

```
/plugin marketplace remove skills-ai
```

## How It Works

```
Plugin Install
  └─ adds to enabledPlugins, caches plugin files

First Session Start
  └─ SessionStart hook fires → setup.sh runs (~500ms)
       └─ python3 writes statusLine config to ~/.claude/settings.json

First User Interaction (same session)
  └─ UserPromptSubmit hook fires → setup.sh runs (idempotent, ~7ms)
  └─ Claude auto-reloads settings.json
       └─ reads statusLine config → runs bash run.sh
            └─ run.sh finds node → exec node statusline.js
                 └─ reads JSON from stdin → renders status bar
```

The `SessionStart` and `UserPromptSubmit` hooks also act as a **self-healing mechanism**: if the `statusLine` config is accidentally removed from `settings.json`, the next session start or prompt will re-add it automatically.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `python3` not available | `setup.sh` fails with clear error message |
| `settings.json` missing | Created from scratch with valid JSON |
| `settings.json` malformed | `setup.sh` fails gracefully, doesn't corrupt further |
| Plugin cache cleared | `run.sh` exits silently (no crash) |
| Config manually deleted | Self-heals on next session start |
| Existing manual statusLine | Overwritten by plugin config |

## Compatibility

The statusline plugin works across different Node.js installation methods:

- System node (`/usr/local/bin/node`)
- **nvm** / **fnm** (sourced automatically)
- **volta** (detected via `VOLTA_HOME`)
- **nodeenv** (used by Claude Code's own installer)
- **Homebrew** (`/opt/homebrew/bin/node`)

No global `node` in PATH is required — the plugin discovers it automatically.

## Plugin Structure

Each plugin in this marketplace follows the standard Claude Code plugin layout:

```
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json        # Plugin metadata (name, version, description)
├── hooks/
│   └── hooks.json         # Hook event registrations (SessionStart)
├── scripts/
│   ├── setup.sh           # Auto-configuration on session start
│   ├── run.sh             # Runtime wrapper (node discovery)
│   └── uninstall.sh       # Pre-uninstall cleanup
└── statusline.js          # Status bar renderer (Node.js)
```

## License

MIT
