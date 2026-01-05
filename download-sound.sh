#!/bin/bash

# download-sound.sh - Download and normalize audio from YouTube for claude-overlord
#
# Usage: ./download-sound.sh <character> <youtube-url> [output-filename]
#
# Example:
#   ./download-sound.sh marine "https://www.youtube.com/watch?v=bes0WtDCq0Q"
#   ./download-sound.sh marine "https://www.youtube.com/watch?v=bes0WtDCq0Q" go_go_go.wav
#
# Source: https://www.youtube.com/@starcraft2units has unit quote compilations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check dependencies
check_deps() {
    local missing=()
    command -v yt-dlp &>/dev/null || missing+=("yt-dlp")
    command -v ffmpeg &>/dev/null || missing+=("ffmpeg")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Missing dependencies: ${missing[*]}${NC}"
        echo "Install with: brew install ${missing[*]}"
        exit 1
    fi
}

# Usage info
usage() {
    echo "Usage: $0 <character> <youtube-url> [output-filename]"
    echo ""
    echo "Arguments:"
    echo "  character       Character name (e.g., marine, zealot, hellbat)"
    echo "  youtube-url     YouTube video URL"
    echo "  output-filename Optional output filename (default: derived from video title)"
    echo ""
    echo "Example:"
    echo "  $0 marine 'https://www.youtube.com/watch?v=xyz123'"
    echo "  $0 marine 'https://www.youtube.com/watch?v=xyz123' go_go_go.wav"
    echo ""
    echo "Sound Source:"
    echo "  https://www.youtube.com/@starcraft2units - SC2 unit quote compilations"
    exit 1
}

# Main
check_deps

if [ $# -lt 2 ]; then
    usage
fi

CHARACTER="$1"
URL="$2"
OUTPUT_NAME="${3:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUNDS_DIR="$SCRIPT_DIR/sounds/$CHARACTER"
TMP_DIR=$(mktemp -d)

# Create character directory if needed
mkdir -p "$SOUNDS_DIR"

echo -e "${YELLOW}Downloading audio from YouTube...${NC}"

# Download audio
cd "$TMP_DIR"
yt-dlp -x --audio-format wav -o "download.%(ext)s" "$URL" 2>&1

# Check if download succeeded
if [ ! -f "download.wav" ]; then
    echo -e "${RED}Download failed${NC}"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Determine output filename
if [ -z "$OUTPUT_NAME" ]; then
    # Get video title and sanitize it
    VIDEO_TITLE=$(yt-dlp --get-title "$URL" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g' | cut -c1-50)
    OUTPUT_NAME="${VIDEO_TITLE}.wav"
fi

# Ensure .wav extension
if [[ "$OUTPUT_NAME" != *.wav ]]; then
    OUTPUT_NAME="${OUTPUT_NAME}.wav"
fi

echo -e "${YELLOW}Normalizing audio...${NC}"

# Normalize audio using loudnorm filter
ffmpeg -y -i "download.wav" \
    -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
    -ar 44100 \
    "$SOUNDS_DIR/$OUTPUT_NAME" 2>/dev/null

# Cleanup
rm -rf "$TMP_DIR"

echo -e "${GREEN}Saved: sounds/$CHARACTER/$OUTPUT_NAME${NC}"
echo ""
echo "Test with:"
echo "  afplay \"$SOUNDS_DIR/$OUTPUT_NAME\""
