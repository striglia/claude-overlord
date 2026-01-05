#!/bin/bash

# Claude Overlord Installer
# Sets up Starcraft notification sounds for Claude Code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SOUNDS_DIR="$CLAUDE_DIR/claude-overlord/sounds"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

echo "Installing Claude Overlord..."

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    echo ""
    echo "WARNING: jq is not installed. The hook script requires jq."
    echo "Install it with: brew install jq"
    echo ""
fi

# Create directory structure
echo "Creating directories..."
mkdir -p "$HOOKS_DIR"
mkdir -p "$SOUNDS_DIR"

# Copy the hook script
echo "Installing hook script..."
cp "$SCRIPT_DIR/claude-overlord.sh" "$HOOKS_DIR/claude-overlord.sh"
chmod +x "$HOOKS_DIR/claude-overlord.sh"

# Copy sounds directory (preserving structure)
echo "Installing sounds..."
if [ -d "$SCRIPT_DIR/sounds" ]; then
    cp -r "$SCRIPT_DIR/sounds/"* "$SOUNDS_DIR/" 2>/dev/null || true
fi

# Define the hook configuration to add
HOOK_CONFIG='{
  "hooks": {
    "Notification": [
      {
        "matcher": "idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claude-overlord.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/claude-overlord.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}'

# Merge or create settings.json
echo "Configuring Claude Code hooks..."
if [ -f "$SETTINGS_FILE" ]; then
    # Backup existing settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"

    if command -v jq &> /dev/null; then
        # Merge hooks using jq (* does recursive object merge)
        MERGED=$(jq -s '.[0] * .[1]' "$SETTINGS_FILE" <(echo "$HOOK_CONFIG"))

        echo "$MERGED" > "$SETTINGS_FILE"
        echo "Merged hooks into existing settings.json (backup at settings.json.backup)"
    else
        echo "WARNING: Cannot merge settings.json without jq installed."
        echo "Please manually add hooks configuration. See sounds/README.md for details."
    fi
else
    # Create new settings.json
    echo "$HOOK_CONFIG" > "$SETTINGS_FILE"
    echo "Created new settings.json with hooks configuration"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Add sound files to ~/.claude/claude-overlord/sounds/{character}/"
echo "     (see sounds/README.md for sourcing options)"
echo "  2. Restart Claude Code to activate hooks"
echo ""
echo "Test the installation:"
echo "  echo '{\"session_id\":\"test\"}' | ~/.claude/hooks/claude-overlord.sh"
echo ""
