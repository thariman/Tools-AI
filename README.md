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
Claude Opus 4.6 │ Fixing auth bug │ my-project │ main ✔ █████░░░░░ 50%
```

Context window colors shift from green → yellow → orange → red as usage increases, with a skull (💀) warning above 80%.

## Installation

Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

**1. Add the marketplace:**

```bash
claude plugin marketplace add https://github.com/thariman/Skills-AI
```

**2. Install and configure:**

```bash
claude plugin install statusline
bash ~/.claude/plugins/cache/skills-ai/statusline/*/scripts/setup.sh
```

**3. Start Claude Code** — the statusline appears at the bottom of your terminal.

> **Note:** The setup script must be run once after install to configure `~/.claude/settings.json`. A SessionStart hook also runs this automatically, but takes effect on the next session.

## Uninstalling

```bash
claude plugin uninstall statusline
```

The statusline config is automatically removed from `settings.json` on the next session.

To remove the marketplace source entirely:

```bash
claude plugin marketplace remove skills-ai
```

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
│   └── hooks.json         # Hook event registrations
├── scripts/
│   ├── setup.sh           # Post-install configuration
│   ├── run.sh             # Runtime wrapper (node discovery)
│   └── uninstall.sh       # Pre-uninstall cleanup
└── <implementation files>
```

## License

MIT
