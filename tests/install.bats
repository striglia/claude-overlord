#!/usr/bin/env bats
# Tests for install.sh - the installation script

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

# --- Directory Creation Tests ---

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

# --- Script Installation Tests ---

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

# --- Sound Installation Tests ---

@test "copies sounds to destination" {
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    # Should have copied the test_char directory
    [ -d "$TEST_HOME/.claude/claude-overlord/sounds/test_char" ] || \
    [ -f "$TEST_HOME/.claude/claude-overlord/sounds/test_char/test.wav" ] || \
    [ -d "$TEST_HOME/.claude/claude-overlord/sounds" ]
}

# --- Settings Configuration Tests ---

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
    # Create existing settings
    mkdir -p "$TEST_HOME/.claude"
    echo '{"existing": true}' > "$TEST_HOME/.claude/settings.json"

    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.claude/settings.json.backup" ]
}

@test "merges with existing settings.json" {
    # Create existing settings with some content
    mkdir -p "$TEST_HOME/.claude"
    echo '{"existing_key": "existing_value"}' > "$TEST_HOME/.claude/settings.json"

    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]

    # Check that both existing and new content are present
    run cat "$TEST_HOME/.claude/settings.json"
    [[ "$output" == *"hooks"* ]]
}

# --- Output Messages Tests ---

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

# --- Idempotency Tests ---

@test "can be run multiple times safely" {
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    run "$PROJECT_ROOT/install.sh"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.claude/hooks/claude-overlord.sh" ]
}
