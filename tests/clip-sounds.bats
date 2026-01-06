#!/usr/bin/env bats
# Tests for clip-sounds.sh - argument validation and usage

load 'test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# --- Dependency Check Tests ---

@test "checks for ffmpeg dependency before anything else" {
    # Mock environment with no ffmpeg
    $REAL_MKDIR -p "$TEST_HOME/bin"
    # Link basic commands but not ffmpeg
    for cmd in bash cat echo; do
        local cmd_path=$(command -v $cmd 2>/dev/null)
        [ -n "$cmd_path" ] && $REAL_LN -sf "$cmd_path" "$TEST_HOME/bin/$cmd" 2>/dev/null || true
    done
    export PATH="$TEST_HOME/bin:$PATH"

    run "$PROJECT_ROOT/clip-sounds.sh" marine "$TEST_HOME/input.wav"
    # Should fail with dependency error
    [ "$status" -ne 0 ]
    [[ "$output" == *"ffmpeg"* ]] || [[ "$output" == *"Missing"* ]] || [[ "$output" == *"Usage"* ]]
}

# --- Argument Validation Tests ---
# These run only if ffmpeg is available

@test "shows usage when no arguments provided" {
    command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not installed"

    run "$PROJECT_ROOT/clip-sounds.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "shows usage when only one argument provided" {
    command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not installed"

    run "$PROJECT_ROOT/clip-sounds.sh" marine
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "usage shows character argument" {
    command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not installed"

    run "$PROJECT_ROOT/clip-sounds.sh"
    [[ "$output" == *"character"* ]]
}

@test "usage shows input-file argument" {
    command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not installed"

    run "$PROJECT_ROOT/clip-sounds.sh"
    [[ "$output" == *"input-file"* ]]
}

@test "usage explains what script does" {
    command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not installed"

    run "$PROJECT_ROOT/clip-sounds.sh"
    [[ "$output" == *"silence"* ]] || [[ "$output" == *"split"* ]] || [[ "$output" == *"clip"* ]]
}

# --- File Validation Tests ---

@test "exits with error when input file does not exist" {
    command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not installed"

    run "$PROJECT_ROOT/clip-sounds.sh" marine "/nonexistent/file.wav"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"Error"* ]]
}
