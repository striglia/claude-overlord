# Claude Overlord

Starcraft notification sounds for Claude Code - plays character voice lines when agents need attention.

## Quick Reference

| Task | Command |
|------|---------|
| Test sound script | `echo '{"session_id":"test123"}' \| ./claude-overlord.sh` |
| Play test sound | `afplay sounds/marine/ready.wav` |
| Watch hooks live | `./watch.sh` |
| Check jq installed | `jq --version` |
| Install jq | `brew install jq` |

## Architecture

This is a Claude Code hook that installs into `~/.claude/`:

```
~/.claude/
├── settings.json                    # Hook config (merge with existing)
├── hooks/
│   └── claude-overlord.sh           # Main script (from this repo)
└── claude-overlord/
    └── sounds/{character}/*.wav     # Sound files
```

### Key Files

- `plan.md` - Full spec with implementation details
- `claude-overlord.sh` - Main hook script (to be created)
- `sounds/` - Sound library organized by character (to be populated)
- `install.sh` - Installation script (to be created)

### How It Works

1. Claude Code fires `Notification` (idle_prompt) or `Stop` hook
2. Hook passes JSON with `session_id` via stdin
3. Script hashes `session_id` → deterministic character selection
4. Random sound from that character's directory plays via `afplay`

## Development

### Testing the script locally

```bash
# Simulate a hook call
echo '{"session_id":"abc123","hook_event_name":"Stop"}' | ./claude-overlord.sh

# Different session_id = different character
echo '{"session_id":"xyz789","hook_event_name":"Stop"}' | ./claude-overlord.sh
```

### Adding sounds

1. Create character directory: `mkdir -p sounds/marine`
2. Add .wav/.mp3/.aiff files
3. Test: `afplay sounds/marine/ready.wav`

### Live hook monitoring

Run `./watch.sh` to see a colorized, real-time view of hook events:

```
Claude Overlord - Live Hook Monitor
====================================

Recent history:
12:34:56 [abc123] Stop    marine       ready.wav

--- Live ---

12:35:02 [xyz789] Notify  zealot       my-life-for-aiur.wav
12:35:10 [abc123] Stop    marine       job-done.wav
```

Each session gets a consistent color based on its ID, making it easy to track multiple Claude sessions at once.

### Optional: Statusline integration

Add your session ID and assigned unit to Claude Code's statusline. Add this snippet to your `~/.claude/statusline-command.sh`:

```bash
# Session ID colors - 16 distinct colors matching watch.sh
SESSION_COLORS=(196 208 220 82 46 51 39 27 93 201 213 172 35 99 214 160)

# Add claude-overlord info (only if installed)
session_id=$(echo "$input" | jq -r '.session_id // empty' | cut -c1-6)
if [ -n "$session_id" ]; then
    if jq -e '.hooks[][] | .hooks[]? | select(.command | contains("claude-overlord"))' ~/.claude/settings.json &>/dev/null; then
        SOUND_DIR="$HOME/.claude/claude-overlord/sounds"
        if [ -d "$SOUND_DIR" ]; then
            characters=()
            while IFS= read -r -d '' dir; do
                characters+=("$(basename "$dir")")
            done < <(find "$SOUND_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
            if [ ${#characters[@]} -gt 0 ]; then
                full_session=$(echo "$input" | jq -r '.session_id // empty')
                char_hash=$(echo -n "$full_session" | md5 | cut -c1-8)
                char_index=$(( 16#$char_hash % ${#characters[@]} ))
                character="${characters[$char_index]}"

                color_hash=$(echo -n "$session_id" | cksum | cut -d' ' -f1)
                color_index=$((color_hash % ${#SESSION_COLORS[@]}))
                session_color="\x1b[38;5;${SESSION_COLORS[$color_index]}m"
                reset='\x1b[0m'

                # Append to your status variable:
                status="${status}\n${session_color}[claude-overlord: ${session_id} ${character}]${reset}"
            fi
        fi
    fi
fi
```

This displays `[claude-overlord: 1caa40 marine]` with the same color coding as `watch.sh`, making it easy to correlate sessions.

## Installation (for users)

```bash
# 1. Clone repo
git clone https://github.com/striglia/claude-overlord.git

# 2. Run installer (once created)
./install.sh

# Or manually:
# - Copy claude-overlord.sh to ~/.claude/hooks/
# - Copy sounds/ to ~/.claude/claude-overlord/sounds/
# - Merge hook config into ~/.claude/settings.json
```

## Gotchas

- **macOS only** - uses `afplay` which is macOS-specific
- **jq required** - install via `brew install jq`
- **Sound files not included** - must be sourced separately (see plan.md)
- **Tilde expansion** - `~/.claude/hooks/claude-overlord.sh` in settings.json may need full path on some systems
