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

**Add the marketplace:**

```bash
claude plugin marketplace add https://github.com/thariman/Skills-AI
```

**Install and configure:**

```bash
claude plugin install statusline
bash ~/.claude/plugins/cache/skills-ai/statusline/*/scripts/setup.sh
```

Then start a new Claude Code session — the statusline appears at the bottom of your terminal.

## Uninstalling

Run the cleanup script first to remove the statusline config from `settings.json`, then uninstall the plugin:

```bash
bash ~/.claude/plugins/cache/skills-ai/statusline/*/scripts/uninstall.sh
claude plugin uninstall statusline
```

To remove the marketplace source entirely:

```bash
claude plugin marketplace remove skills-ai
```

## Plugin Structure

Each plugin in this marketplace follows the standard Claude Code plugin layout:

```
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json        # Plugin metadata (name, version, description)
├── hooks/
│   └── hooks.json         # Hook registrations
├── scripts/
│   └── setup.sh           # Setup/install script
└── <implementation files>
```

## License

MIT
