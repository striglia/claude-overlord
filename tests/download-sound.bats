#!/usr/bin/env bats
# Tests for download-sound.sh - argument validation and usage

load 'test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# --- Dependency Check Tests ---
# Note: dependency checks run before argument validation

@test "checks for yt-dlp dependency before anything else" {
    # Mock environment with no yt-dlp
    $REAL_MKDIR -p "$TEST_HOME/bin"
    # Ensure ffmpeg exists but not yt-dlp
    which ffmpeg >/dev/null 2>&1 && $REAL_LN -sf "$(which ffmpeg)" "$TEST_HOME/bin/ffmpeg"
    export PATH="$TEST_HOME/bin:$PATH"

    run "$PROJECT_ROOT/download-sound.sh" marine "https://youtube.com/watch?v=test"
    # Should fail with dependency error
    [ "$status" -ne 0 ]
    [[ "$output" == *"yt-dlp"* ]] || [[ "$output" == *"Missing"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "checks for ffmpeg dependency" {
    # Mock environment with yt-dlp but no ffmpeg
    $REAL_MKDIR -p "$TEST_HOME/bin"
    # Create mock yt-dlp
    $REAL_CAT > "$TEST_HOME/bin/yt-dlp" << 'EOF'
#!/bin/bash
exit 0
EOF
    $REAL_CHMOD +x "$TEST_HOME/bin/yt-dlp"
    export PATH="$TEST_HOME/bin:$PATH"

    run "$PROJECT_ROOT/download-sound.sh" marine "https://youtube.com/watch?v=test"
    # Should fail with dependency error
    [ "$status" -ne 0 ]
    [[ "$output" == *"ffmpeg"* ]] || [[ "$output" == *"Missing"* ]] || [[ "$output" == *"Usage"* ]]
}

# --- Argument Validation Tests ---
# These run only if dependencies are available

@test "shows usage when no arguments provided and deps available" {
    # Skip if dependencies aren't installed
    command -v yt-dlp >/dev/null 2>&1 || skip "yt-dlp not installed"
    command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not installed"

    run "$PROJECT_ROOT/download-sound.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "shows usage when only one argument provided and deps available" {
    command -v yt-dlp >/dev/null 2>&1 || skip "yt-dlp not installed"
    command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not installed"

    run "$PROJECT_ROOT/download-sound.sh" marine
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "usage includes sound source recommendation" {
    command -v yt-dlp >/dev/null 2>&1 || skip "yt-dlp not installed"
    command -v ffmpeg >/dev/null 2>&1 || skip "ffmpeg not installed"

    run "$PROJECT_ROOT/download-sound.sh"
    [[ "$output" == *"starcraft2units"* ]] || [[ "$output" == *"Sound Source"* ]]
}
