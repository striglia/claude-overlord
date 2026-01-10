# Claude Overlord

Starcraft notification sounds for Claude Code. When your AI agent needs attention, it speaks to you in the voice of iconic SC2 units.

## What it does

Claude Overlord is a [Claude Code hook](https://docs.anthropic.com/en/docs/claude-code/hooks) that plays Starcraft voice lines when:

- **Agent is idle** (Notification hook) - questioning sounds like "Yes sir?" or "What do you need?"
- **Agent finishes a task** (Stop hook) - confirmation sounds like "Job's done!" or "Ready!"

Each terminal session gets assigned a consistent character based on `session_id`, so your different tabs each have their own personality.

## Requirements

- macOS (uses `afplay`)
- `jq` (`brew install jq`)
- Sound files (not included - see [sounds/README.md](sounds/README.md))

## Installation

```bash
git clone https://github.com/striglia/claude-overlord.git
cd claude-overlord
./install.sh
```

## Supported Characters

- Marine
- Zealot
- Hydralisk
- Battlecruiser
- Carrier
- And more...

## License

MIT
