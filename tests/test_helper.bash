#!/bin/bash
# Test helper functions and setup for BATS tests
#
# Philosophy:
# - Tests should run in isolation without affecting the real system
# - Mock external commands (afplay, md5) to avoid side effects
# - Use temporary directories for all file operations
# - Save references to real commands before PATH manipulation
#   (needed because some tests verify behavior when tools are missing)

# Project root directory
export PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Save paths to essential commands at load time (before any PATH manipulation)
# This is necessary because some tests manipulate PATH to simulate missing tools
REAL_MKDIR=$(command -v mkdir)
REAL_RM=$(command -v rm)
REAL_MKTEMP=$(command -v mktemp)
REAL_CHMOD=$(command -v chmod)
REAL_CP=$(command -v cp)
REAL_LN=$(command -v ln)
REAL_CAT=$(command -v cat)
REAL_TOUCH=$(command -v touch)

# Create a temporary test environment
setup_test_env() {
    # Save original PATH to restore later
    export ORIGINAL_PATH="$PATH"
    export TEST_HOME=$($REAL_MKTEMP -d)
    export HOME="$TEST_HOME"
    export TEST_SOUNDS_DIR=$($REAL_MKTEMP -d)
    export CLAUDE_OVERLORD_SOUNDS="$TEST_SOUNDS_DIR"
}

# Clean up test environment
teardown_test_env() {
    # Restore original PATH before cleanup
    [ -n "$ORIGINAL_PATH" ] && export PATH="$ORIGINAL_PATH"
    [ -n "$TEST_HOME" ] && $REAL_RM -rf "$TEST_HOME"
    [ -n "$TEST_SOUNDS_DIR" ] && $REAL_RM -rf "$TEST_SOUNDS_DIR"
}

# Create mock character directories with sound files
create_mock_sounds() {
    local sounds_dir="${1:-$TEST_SOUNDS_DIR}"

    # Create character directories
    $REAL_MKDIR -p "$sounds_dir/marine"
    $REAL_MKDIR -p "$sounds_dir/zealot"
    $REAL_MKDIR -p "$sounds_dir/zergling"

    # Create dummy sound files (empty wav files for testing)
    $REAL_TOUCH "$sounds_dir/marine/ready.wav"
    $REAL_TOUCH "$sounds_dir/marine/attack.wav"
    $REAL_TOUCH "$sounds_dir/zealot/foraiur.wav"
    $REAL_TOUCH "$sounds_dir/zergling/hiss.mp3"
}

# Create event-specific sound subdirectories
create_event_sounds() {
    local sounds_dir="${1:-$TEST_SOUNDS_DIR}"

    $REAL_MKDIR -p "$sounds_dir/marine/idle"
    $REAL_MKDIR -p "$sounds_dir/marine/complete"

    $REAL_TOUCH "$sounds_dir/marine/idle/waiting.wav"
    $REAL_TOUCH "$sounds_dir/marine/complete/done.wav"
}

# Mock afplay to avoid actual audio playback
mock_afplay() {
    export PATH="$TEST_HOME/bin:$PATH"
    $REAL_MKDIR -p "$TEST_HOME/bin"
    $REAL_CAT > "$TEST_HOME/bin/afplay" << 'EOF'
#!/bin/bash
echo "MOCK_AFPLAY: $1"
exit 0
EOF
    $REAL_CHMOD +x "$TEST_HOME/bin/afplay"
}

# Mock jq as unavailable by removing it from PATH
mock_no_jq() {
    # Create a PATH that excludes jq
    # Keep essential commands but remove directories containing jq
    $REAL_MKDIR -p "$TEST_HOME/bin"
    # Link essential commands
    for cmd in bash cat echo mkdir rm chmod cp find touch tr cut sed grep wc tail bc paste head basename dirname pwd read mktemp; do
        local cmd_path=$(command -v $cmd 2>/dev/null)
        [ -n "$cmd_path" ] && $REAL_LN -sf "$cmd_path" "$TEST_HOME/bin/$cmd" 2>/dev/null || true
    done
    export PATH="$TEST_HOME/bin"
}

# Mock md5 command (BSD style used on macOS)
mock_md5() {
    export PATH="$TEST_HOME/bin:$PATH"
    $REAL_MKDIR -p "$TEST_HOME/bin"
    $REAL_CAT > "$TEST_HOME/bin/md5" << 'EOF'
#!/bin/bash
# Simple mock that returns a consistent hash for testing
# Read from stdin if no file argument
input=$(cat)
# Use a simple checksum for testing
echo "d41d8cd98f00b204e9800998ecf8427e"
EOF
    $REAL_CHMOD +x "$TEST_HOME/bin/md5"
}
