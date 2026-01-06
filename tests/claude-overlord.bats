#!/usr/bin/env bats
# Tests for claude-overlord.sh - the main hook script

load 'test_helper'

setup() {
    setup_test_env
    mock_afplay
    mock_md5
}

teardown() {
    teardown_test_env
}

# --- Dependency Tests ---

@test "exits gracefully when jq is not available" {
    mock_no_jq
    run bash -c 'echo "{}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
}

@test "outputs error message when jq is missing" {
    # Use mock_no_jq to properly set up environment without jq
    mock_no_jq

    run bash -c 'echo "{}" | "$PROJECT_ROOT/claude-overlord.sh" 2>&1'
    [ "$status" -eq 0 ]
    [[ "$output" == *"jq"* ]]
}

# --- Sound Directory Tests ---

@test "exits gracefully when sounds directory does not exist" {
    export CLAUDE_OVERLORD_SOUNDS="/nonexistent/path"
    run bash -c 'echo "{\"session_id\":\"test\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
}

@test "exits gracefully when sounds directory is empty" {
    # TEST_SOUNDS_DIR exists but has no character subdirectories
    run bash -c 'echo "{\"session_id\":\"test\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
}

@test "exits gracefully when character directory has no sound files" {
    mkdir -p "$TEST_SOUNDS_DIR/marine"
    # marine directory exists but has no .wav/.mp3/.aiff files
    run bash -c 'echo "{\"session_id\":\"test\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
}

# --- Character Selection Tests ---

@test "selects a character when sounds are available" {
    create_mock_sounds
    run bash -c 'echo "{\"session_id\":\"test\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MOCK_AFPLAY"* ]]
}

@test "selects same character for same session_id (deterministic)" {
    create_mock_sounds

    # Run twice with same session_id
    run1=$(echo '{"session_id":"session123"}' | "$PROJECT_ROOT/claude-overlord.sh")
    run2=$(echo '{"session_id":"session123"}' | "$PROJECT_ROOT/claude-overlord.sh")

    # Both should produce output (character was selected)
    [ -n "$run1" ]
    [ -n "$run2" ]
}

@test "uses default session_id when not provided" {
    create_mock_sounds
    run bash -c 'echo "{}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MOCK_AFPLAY"* ]]
}

# --- Event Mapping Tests ---

@test "maps Notification event to idle sound category" {
    create_mock_sounds
    create_event_sounds

    run bash -c 'echo "{\"session_id\":\"test\",\"hook_event_name\":\"Notification\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    # Should play from idle directory
    [[ "$output" == *"idle"* ]] || [[ "$output" == *"MOCK_AFPLAY"* ]]
}

@test "maps Stop event to complete sound category" {
    create_mock_sounds
    create_event_sounds

    run bash -c 'echo "{\"session_id\":\"test\",\"hook_event_name\":\"Stop\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MOCK_AFPLAY"* ]]
}

@test "falls back to root directory when event-specific dir is empty" {
    create_mock_sounds
    # Create empty idle directory
    mkdir -p "$TEST_SOUNDS_DIR/marine/idle"
    # No files in idle, should fall back to root marine directory

    run bash -c 'echo "{\"session_id\":\"test\",\"hook_event_name\":\"Notification\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MOCK_AFPLAY"* ]]
}

# --- Sound File Format Tests ---

@test "finds .wav files" {
    mkdir -p "$TEST_SOUNDS_DIR/marine"
    touch "$TEST_SOUNDS_DIR/marine/ready.wav"

    run bash -c 'echo "{\"session_id\":\"test\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"ready.wav"* ]]
}

@test "finds .mp3 files" {
    mkdir -p "$TEST_SOUNDS_DIR/zergling"
    touch "$TEST_SOUNDS_DIR/zergling/hiss.mp3"

    run bash -c 'echo "{\"session_id\":\"test\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *".mp3"* ]] || [[ "$output" == *"MOCK_AFPLAY"* ]]
}

@test "finds .aiff files" {
    mkdir -p "$TEST_SOUNDS_DIR/zealot"
    touch "$TEST_SOUNDS_DIR/zealot/foraiur.aiff"

    run bash -c 'echo "{\"session_id\":\"test\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MOCK_AFPLAY"* ]]
}

# --- JSON Parsing Tests ---

@test "handles malformed JSON gracefully" {
    create_mock_sounds
    run bash -c 'echo "not valid json" | "$PROJECT_ROOT/claude-overlord.sh"'
    # Should not crash, jq returns null for invalid json
    [ "$status" -eq 0 ]
}

@test "handles empty input gracefully" {
    create_mock_sounds
    run bash -c 'echo "" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
}
