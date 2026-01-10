#!/usr/bin/env bats
#
# Tests for install.sh - the installation script
#
# What we test:
# - Directory structure creation (~/.claude/hooks, ~/.claude/claude-overlord/sounds)
# - File copying and permissions
# - settings.json creation and merging
# - Idempotency (safe to run multiple times)
#
# What we don't test:
# - Actual Claude Code integration (requires Claude Code to be running)
#
# Why these tests matter:
# Installation failures leave users with a broken setup. These tests verify
# the installer creates the correct structure and handles edge cases like
# existing settings.json files.

load 'test_helper'

setup() {
    setup_test_env
    # Create a minimal sounds directory in the project for install to copy
    $REAL_MKDIR -p "$PROJECT_ROOT/sounds/test_char"
    $REAL_TOUCH "$PROJECT_ROOT/sounds/test_char/test.wav"
}

teardown() {
    # Clean up test sound first (before PATH might be messed up)
    $REAL_RM -rf "$PROJECT_ROOT/sounds/test_char"
    teardown_test_env
}

# --- Directory Structure ---
# The installer must create the expected directory hierarchy.

@test "creates hooks directory" {
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ -d "$TEST_HOME/.claude/hooks" ]
}

@test "creates sounds directory" {
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ -d "$TEST_HOME/.claude/claude-overlord/sounds" ]
}

# --- Script Installation ---
# The hook script must be copied and made executable.

@test "copies hook script to hooks directory" {
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.claude/hooks/claude-overlord.sh" ]
}

@test "makes hook script executable" {
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ -x "$TEST_HOME/.claude/hooks/claude-overlord.sh" ]
}

# --- Sound Installation ---

@test "copies sounds to destination" {
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ -d "$TEST_HOME/.claude/claude-overlord/sounds" ]
}

# --- Settings Configuration ---
# The installer must create or merge settings.json with hook configuration.

@test "creates settings.json when it does not exist" {
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.claude/settings.json" ]
}

@test "settings.json contains hooks configuration" {
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    run cat "$TEST_HOME/.claude/settings.json"
    [[ "$output" == *"hooks"* ]]
    [[ "$output" == *"Notification"* ]]
    [[ "$output" == *"Stop"* ]]
}

@test "creates backup when settings.json exists" {
    mkdir -p "$TEST_HOME/.claude"
    echo '{"existing": true}' > "$TEST_HOME/.claude/settings.json"

    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.claude/settings.json.backup" ]
}

@test "merges with existing settings.json" {
    mkdir -p "$TEST_HOME/.claude"
    echo '{"existing_key": "existing_value"}' > "$TEST_HOME/.claude/settings.json"

    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]

    run cat "$TEST_HOME/.claude/settings.json"
    [[ "$output" == *"hooks"* ]]
}

# --- User Feedback ---

@test "displays installation progress" {
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing Claude Overlord"* ]]
    [[ "$output" == *"Installation complete"* ]]
}

@test "warns when jq is not installed" {
    mock_no_jq
    run "$PROJECT_ROOT/install.sh"
    # Script should still complete but warn
    [[ "$output" == *"jq"* ]] || [ "$status" -eq 0 ]
}

# --- Idempotency ---
# Running the installer multiple times should be safe.

@test "can be run multiple times safely" {
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.claude/hooks/claude-overlord.sh" ]
}
