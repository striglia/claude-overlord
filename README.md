# Claude Overmind

Starcraft notification sounds for Claude Code. Because we're all managing the swarm now. 

## What it does

Claude Overmind is a [Claude Code hook](https://docs.anthropic.com/en/docs/claude-code/hooks) that plays Starcraft voice lines when:

- **Agent is idle** (Notification hook) - questioning sounds like "Yes sir?" or "What do you need?"
- **Agent finishes a task** (Stop hook) - confirmation sounds like "Job's done!" or "Ready!"

Each terminal session gets assigned a consistent character based on `session_id`, so your different tabs each have their own personality.

## Requirements

- macOS (uses `afplay`)
- `jq` (`brew install jq`)
- Sound files (not included - see [sounds/README.md](sounds/README.md))

## Installation

```bash
git clone https://github.com/striglia/claude-overmind.git
cd claude-overmind
./install.sh
```

## Supported Characters

- Marine
- Zealot
- Hydralisk
- Battlecruiser
- Carrier
- And more...

## Live Monitoring

Run `./watch.sh` to see a colorized, real-time view of hook events:

```
Claude Overmind - Live Hook Monitor
====================================

Recent history:
12:34:56 [abc123] Stop    marine       ready.wav

--- Live ---

12:35:02 [xyz789] Notify  zealot       my-life-for-aiur.wav
```

Each session gets a consistent color based on its ID, making it easy to track multiple Claude sessions at once.
