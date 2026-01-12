#!/bin/bash

# Claude Overlord - Starcraft notification sounds for Claude Code
# Plays character voice lines when hooks trigger

# Read hook input from stdin (JSON with session_id, hook_event_name, etc.)
read -r hook_input

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  echo "jq is required but not installed. Run: brew install jq" >&2
  exit 0
fi

# Extract session_id for deterministic character assignment
session_id=$(echo "$hook_input" | jq -r '.session_id // "default"')

# Extract hook event name for event-specific sounds
hook_event=$(echo "$hook_input" | jq -r '.hook_event_name // ""')

# Map hook events to sound categories
# - Notification (idle_prompt): questioning sounds ("Yes sir?", "What do you need?")
# - Stop: confirmation sounds ("Job's done!", "Ready!")
case "$hook_event" in
  "Notification") sound_category="idle" ;;
  "Stop") sound_category="complete" ;;
  *) sound_category="" ;;
esac

# Sound library location (can be overridden via env var)
SOUND_DIR="${CLAUDE_OVERLORD_SOUNDS:-$HOME/.claude/claude-overlord/sounds}"

# Exit gracefully if sounds directory doesn't exist
if [ ! -d "$SOUND_DIR" ]; then
  exit 0
fi

# Get list of character directories (sorted for deterministic assignment)
characters=()
while IFS= read -r -d '' dir; do
  characters+=("$(basename "$dir")")
done < <(find "$SOUND_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

if [ ${#characters[@]} -eq 0 ]; then
  exit 0
fi

# Hash session_id to pick a character (deterministic per-tab)
hash=$(echo -n "$session_id" | md5 | cut -c1-8)
char_index=$(( 16#$hash % ${#characters[@]} ))
character="${characters[$char_index]}"

# Collect sound files - try event-specific subdirectory first, then fall back to root
sounds=()

# Try event-specific subdirectory first (e.g., sounds/marine/idle/)
if [ -n "$sound_category" ] && [ -d "$SOUND_DIR/$character/$sound_category" ]; then
  while IFS= read -r -d '' file; do
    sounds+=("$file")
  done < <(find "$SOUND_DIR/$character/$sound_category" -maxdepth 1 -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.aiff" \) -print0 2>/dev/null)
fi

# Fall back to root character directory for backwards compatibility
if [ ${#sounds[@]} -eq 0 ]; then
  while IFS= read -r -d '' file; do
    sounds+=("$file")
  done < <(find "$SOUND_DIR/$character" -maxdepth 1 -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.aiff" \) -print0 2>/dev/null)
fi

if [ ${#sounds[@]} -eq 0 ]; then
  exit 0
fi

# Pick a random sound
sound_index=$((RANDOM % ${#sounds[@]}))
sound_file="${sounds[$sound_index]}"

# Play sound (non-blocking via &, afplay is macOS native)
afplay "$sound_file" &

# Log playback for debugging and clip analysis
LOG_FILE="${CLAUDE_OVERLORD_LOG:-$HOME/.claude/claude-overlord/playback.log}"
LOG_DIR=$(dirname "$LOG_FILE")
if [ -d "$LOG_DIR" ]; then
  # Log format: timestamp session_prefix hook_event character sound_file
  session_prefix="${session_id:0:6}"
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") $session_prefix $hook_event $character $(basename "$sound_file")" >> "$LOG_FILE"
fi

exit 0
