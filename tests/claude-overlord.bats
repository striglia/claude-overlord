#!/usr/bin/env bats
#
# Tests for claude-overlord.sh - the main hook script
#
# What we test:
# - Graceful degradation when dependencies (jq) or resources (sounds) are missing
# - Core behavior: character selection, sound file discovery, event mapping
# - Input handling: valid JSON, malformed input, missing fields
#
# What we don't test:
# - Actual audio playback (mocked via mock_afplay)
# - Randomness of sound selection (non-deterministic, not worth testing)
#
# Why these tests matter:
# This script runs as a Claude Code hook. If it crashes or hangs, it blocks
# the user's workflow. These tests verify it always exits cleanly (exit 0)
# even when things go wrong.

load 'test_helper'

setup() {
    setup_test_env
    mock_afplay
    mock_md5
}

teardown() {
    teardown_test_env
}

# --- Graceful Degradation ---
# The hook must never crash or hang. These tests verify it exits cleanly
# when dependencies or resources are missing.

@test "exits gracefully when jq is not available" {
    mock_no_jq
    run bash -c 'echo "{}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
}

@test "outputs error message when jq is missing" {
    mock_no_jq
    run bash -c 'echo "{}" | "$PROJECT_ROOT/claude-overlord.sh" 2>&1'
    [ "$status" -eq 0 ]
    [[ "$output" == *"jq"* ]]
}

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

# --- Core Behavior ---
# These tests verify the main functionality works correctly.

@test "plays a sound when sounds are available" {
    create_mock_sounds
    run bash -c 'echo "{\"session_id\":\"test\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MOCK_AFPLAY"* ]]
}

@test "uses default session_id when not provided in input" {
    create_mock_sounds
    run bash -c 'echo "{}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MOCK_AFPLAY"* ]]
}

# --- Event Mapping ---
# Notification events should play "idle" sounds (questioning tone)
# Stop events should play "complete" sounds (confirmation tone)

@test "maps Notification event to idle sound category" {
    create_mock_sounds
    create_event_sounds
    run bash -c 'echo "{\"session_id\":\"test\",\"hook_event_name\":\"Notification\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MOCK_AFPLAY"* ]]
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
    mkdir -p "$TEST_SOUNDS_DIR/marine/idle"
    # idle directory exists but is empty - should fall back to marine/
    run bash -c 'echo "{\"session_id\":\"test\",\"hook_event_name\":\"Notification\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MOCK_AFPLAY"* ]]
}

# --- Sound File Discovery ---
# Verify all supported audio formats are found.

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
    [[ "$output" == *"MOCK_AFPLAY"* ]]
}

@test "finds .aiff files" {
    mkdir -p "$TEST_SOUNDS_DIR/zealot"
    touch "$TEST_SOUNDS_DIR/zealot/foraiur.aiff"
    run bash -c 'echo "{\"session_id\":\"test\"}" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"MOCK_AFPLAY"* ]]
}

# --- Input Handling ---
# The hook receives JSON via stdin. It should handle bad input gracefully.

@test "handles malformed JSON gracefully" {
    create_mock_sounds
    run bash -c 'echo "not valid json" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
}

@test "handles empty input gracefully" {
    create_mock_sounds
    run bash -c 'echo "" | "$PROJECT_ROOT/claude-overlord.sh"'
    [ "$status" -eq 0 ]
}
