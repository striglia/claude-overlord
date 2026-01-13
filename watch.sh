#!/bin/bash

# watch.sh - Live hook monitoring for Claude Overmind
# Shows colorized, formatted view of hook events as they fire

# 16 distinct, readable colors (256-color mode)
# Chosen for visibility on both light and dark terminals
COLORS=(
  196  # red
  208  # orange
  220  # yellow
  82   # green
  46   # bright green
  51   # cyan
  39   # light blue
  27   # blue
  93   # purple
  201  # magenta
  213  # pink
  172  # brown/orange
  35   # teal
  99   # lavender
  214  # gold
  160  # dark red
)

# Log file location
LOG_FILE="${CLAUDE_OVERMIND_LOG:-$HOME/.claude/claude-overmind/playback.log}"

# Number of historical entries to show on startup
HISTORY_COUNT=5

# Reset color
RESET="\033[0m"

# Get a consistent color for a session ID (hash to color index)
get_color() {
  local session_id="$1"
  # Use cksum for a simple hash, extract numeric value
  local hash=$(echo -n "$session_id" | cksum | cut -d' ' -f1)
  local index=$((hash % ${#COLORS[@]}))
  echo "${COLORS[$index]}"
}

# Format and colorize a log line
format_line() {
  local line="$1"

  # Parse: 2024-01-10T12:34:56Z abc123 Stop marine ready.wav
  # Fields: timestamp session_prefix hook_event character sound_file
  local timestamp=$(echo "$line" | awk '{print $1}')
  local session=$(echo "$line" | awk '{print $2}')
  local event=$(echo "$line" | awk '{print $3}')
  local character=$(echo "$line" | awk '{print $4}')
  local sound=$(echo "$line" | awk '{print $5}')

  # Skip malformed lines (old format without session/event)
  if [ -z "$sound" ]; then
    return
  fi

  # Extract just time portion (HH:MM:SS) from ISO timestamp
  local time_only=$(echo "$timestamp" | sed 's/.*T\([0-9:]*\)Z/\1/')

  # Get color for this session
  local color=$(get_color "$session")
  local color_code="\033[38;5;${color}m"

  # Format event name (pad to 6 chars for alignment)
  local event_display
  case "$event" in
    "Notification") event_display="Notify" ;;
    "Stop") event_display="Stop  " ;;
    *) event_display=$(printf "%-6s" "$event") ;;
  esac

  # Output formatted line with color on session ID
  printf "%s ${color_code}[%s]${RESET} %s  %-12s %s\n" \
    "$time_only" "$session" "$event_display" "$character" "$sound"
}

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
  echo "Log file not found: $LOG_FILE"
  echo "Waiting for first hook event..."
  echo ""
  # Wait for file to appear, then continue
  while [ ! -f "$LOG_FILE" ]; do
    sleep 1
  done
fi

echo "Claude Overmind - Live Hook Monitor"
echo "===================================="
echo ""

# Show last N historical entries
if [ -f "$LOG_FILE" ]; then
  history_lines=$(tail -n "$HISTORY_COUNT" "$LOG_FILE")
  if [ -n "$history_lines" ]; then
    echo "Recent history:"
    while IFS= read -r line; do
      format_line "$line"
    done <<< "$history_lines"
    echo ""
    echo "--- Live ---"
    echo ""
  fi
fi

# Tail the log file and format each new line
tail -F "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
  format_line "$line"
done
