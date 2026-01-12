#!/bin/bash

# Test that character assignment is deterministic and consistent
# across claude-overlord.sh and statusline

set -e

SOUND_DIR="${CLAUDE_OVERLORD_SOUNDS:-$HOME/.claude/claude-overlord/sounds}"
TEST_SESSION_ID="test-session-12345"

echo "Testing character assignment consistency..."
echo "Sound dir: $SOUND_DIR"
echo "Test session: $TEST_SESSION_ID"
echo ""

# Get sorted character list (same as claude-overlord.sh)
characters=()
while IFS= read -r -d '' dir; do
  characters+=("$(basename "$dir")")
done < <(find "$SOUND_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

echo "Characters found (${#characters[@]}): ${characters[*]}"
echo ""

# Compute character assignment (same algorithm as claude-overlord.sh)
hash=$(echo -n "$TEST_SESSION_ID" | md5 | cut -c1-8)
char_index=$(( 16#$hash % ${#characters[@]} ))
expected_character="${characters[$char_index]}"

echo "Hash: $hash"
echo "Index: $char_index"
echo "Expected character: $expected_character"
echo ""

# Test claude-overlord.sh directly
echo "Testing claude-overlord.sh..."
LOG_FILE="/tmp/test-character-assignment.log"
rm -f "$LOG_FILE"

echo "{\"session_id\":\"$TEST_SESSION_ID\",\"hook_event_name\":\"Stop\"}" | \
  CLAUDE_OVERLORD_SOUNDS="$SOUND_DIR" \
  CLAUDE_OVERLORD_LOG="$LOG_FILE" \
  ./claude-overlord.sh

# Wait for log to be written
sleep 0.5

if [ -f "$LOG_FILE" ]; then
  actual_character=$(awk '{print $4}' "$LOG_FILE")
  echo "Actual character from hook: $actual_character"

  if [ "$actual_character" = "$expected_character" ]; then
    echo "PASS: Character assignment matches"
  else
    echo "FAIL: Expected '$expected_character' but got '$actual_character'"
    exit 1
  fi
else
  echo "FAIL: Log file not created"
  exit 1
fi

echo ""

# Test multiple session IDs for consistency
echo "Testing multiple sessions..."
for i in 1 2 3 4 5; do
  session="session-$i-$RANDOM"
  rm -f "$LOG_FILE"

  echo "{\"session_id\":\"$session\",\"hook_event_name\":\"Stop\"}" | \
    CLAUDE_OVERLORD_SOUNDS="$SOUND_DIR" \
    CLAUDE_OVERLORD_LOG="$LOG_FILE" \
    ./claude-overlord.sh

  sleep 0.2

  # Run again with same session, should get same character
  char1=$(awk '{print $4}' "$LOG_FILE")
  rm -f "$LOG_FILE"

  echo "{\"session_id\":\"$session\",\"hook_event_name\":\"Stop\"}" | \
    CLAUDE_OVERLORD_SOUNDS="$SOUND_DIR" \
    CLAUDE_OVERLORD_LOG="$LOG_FILE" \
    ./claude-overlord.sh

  sleep 0.2
  char2=$(awk '{print $4}' "$LOG_FILE")

  if [ "$char1" = "$char2" ]; then
    echo "  PASS: $session -> $char1 (consistent)"
  else
    echo "  FAIL: $session -> $char1 then $char2 (inconsistent!)"
    exit 1
  fi
done

echo ""
echo "All tests passed!"
rm -f "$LOG_FILE"
