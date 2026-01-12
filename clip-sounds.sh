#!/bin/bash

# clip-sounds.sh - Split audio compilations into individual clips using silence detection
#
# Usage: ./clip-sounds.sh <character> <input-file>
#
# Example:
#   ./clip-sounds.sh marine sounds/marine/all_quotes.wav

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parameters (NOISE_THRESHOLD can be overridden via environment variable)
NOISE_THRESHOLD="${NOISE_THRESHOLD:--20dB}"
MIN_SILENCE_DURATION="0.3"
MIN_CLIP_DURATION="0.5"
MAX_CLIP_DURATION="10"

# Sanity check thresholds
# SC2 voice lines are typically 1-5 seconds
# A file should have roughly duration/3 clips (assuming ~3s average)
MIN_EXPECTED_RATIO="0.1"   # At least 1 clip per 10 seconds
MAX_EXPECTED_RATIO="2.0"   # At most 2 clips per second

# Check dependencies
check_deps() {
    if ! command -v ffmpeg &>/dev/null; then
        echo -e "${RED}Missing dependency: ffmpeg${NC}"
        echo "Install with: brew install ffmpeg"
        exit 1
    fi
}

# Sanity check: verify clip count is plausible for file duration
# Returns 0 if OK, 1 if suspicious
sanity_check() {
    local num_clips="$1"
    local duration="$2"
    local threshold="$3"

    # Calculate clips per second ratio
    local ratio=$(echo "scale=4; $num_clips / $duration" | bc -l)

    # Check if ratio is within expected bounds
    local too_few=$(echo "$ratio < $MIN_EXPECTED_RATIO" | bc -l)
    local too_many=$(echo "$ratio > $MAX_EXPECTED_RATIO" | bc -l)

    if [ "$too_few" -eq 1 ]; then
        local avg_duration=$(echo "scale=1; $duration / $num_clips" | bc -l)
        echo -e "${RED}Warning: Only $num_clips clips detected for ${duration}s file (avg ${avg_duration}s per clip)${NC}"
        echo -e "${YELLOW}This suggests the silence threshold ($threshold) is too conservative.${NC}"
        echo -e "${YELLOW}The audio's 'silence' may be louder than $threshold.${NC}"
        echo ""
        echo "Options:"
        echo "  1. Try a higher threshold: NOISE_THRESHOLD=-15dB $0 $CHARACTER \"$INPUT_FILE\""
        echo "  2. Use subdivide-clip.sh after splitting to fix long clips"
        echo ""
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    if [ "$too_many" -eq 1 ]; then
        local avg_duration=$(echo "scale=2; $duration / $num_clips" | bc -l)
        echo -e "${YELLOW}Warning: $num_clips clips detected for ${duration}s file (avg ${avg_duration}s per clip)${NC}"
        echo -e "${YELLOW}This may indicate over-splitting. Consider a lower threshold.${NC}"
        echo ""
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    return 0
}

# Usage info
usage() {
    echo "Usage: $0 <character> <input-file>"
    echo ""
    echo "Arguments:"
    echo "  character    Character name (e.g., marine, zealot, hellbat)"
    echo "  input-file   Audio file to split (wav/mp3/aiff)"
    echo ""
    echo "Example:"
    echo "  $0 marine sounds/marine/all_quotes.wav"
    echo ""
    echo "Environment variables:"
    echo "  NOISE_THRESHOLD  Silence detection threshold (default: -20dB)"
    echo "                   Higher values (e.g., -15dB) detect more silence"
    echo "                   Lower values (e.g., -25dB) detect less silence"
    echo ""
    echo "Example with custom threshold:"
    echo "  NOISE_THRESHOLD=-15dB $0 battlecruiser sounds/battlecruiser/quotes.wav"
    echo ""
    echo "The script will:"
    echo "  1. Detect silence gaps in the audio"
    echo "  2. Validate clip count is plausible (prompt if suspicious)"
    echo "  3. Split into individual clips"
    echo "  4. Normalize each clip"
    echo "  5. Save as clip_001.wav, clip_002.wav, etc."
    echo "  6. Delete the original file"
    exit 1
}

# Main
check_deps

if [ $# -lt 2 ]; then
    usage
fi

CHARACTER="$1"
INPUT_FILE="$2"

if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: File not found: $INPUT_FILE${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUNDS_DIR="$SCRIPT_DIR/sounds/$CHARACTER"
TMP_DIR=$(mktemp -d)

# Ensure output directory exists
mkdir -p "$SOUNDS_DIR"

echo -e "${YELLOW}Analyzing: $INPUT_FILE${NC}"

# Run silence detection and capture output
SILENCE_OUTPUT=$(ffmpeg -i "$INPUT_FILE" -af "silencedetect=noise=$NOISE_THRESHOLD:d=$MIN_SILENCE_DURATION" -f null - 2>&1)

# Parse silence_end timestamps (these mark the start of voice lines)
# Also parse silence_start timestamps (these mark the end of voice lines)
SILENCE_ENDS=$(echo "$SILENCE_OUTPUT" | grep "silence_end" | sed -n 's/.*silence_end: \([0-9.]*\).*/\1/p')
SILENCE_STARTS=$(echo "$SILENCE_OUTPUT" | grep "silence_start" | sed -n 's/.*silence_start: \([0-9.]*\).*/\1/p')

# Get total duration
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")

# Build clip boundaries
# Voice clips go from silence_end[i] to silence_start[i+1]
# Write timestamps to temp files for processing
echo "$SILENCE_ENDS" > "$TMP_DIR/silence_ends.txt"
echo "$SILENCE_STARTS" > "$TMP_DIR/silence_starts.txt"

# Check if we found any silence
if [ ! -s "$TMP_DIR/silence_ends.txt" ]; then
    echo -e "${RED}Error: No silence detected. Try adjusting the noise threshold.${NC}"
    echo "Current threshold: $NOISE_THRESHOLD"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Build clip list: each clip starts at silence_end and ends at the NEXT silence_start
# Skip the first silence_start (it's before the first clip)
tail -n +2 "$TMP_DIR/silence_starts.txt" > "$TMP_DIR/clip_ends.txt"
# Add duration as the final clip end
echo "$DURATION" >> "$TMP_DIR/clip_ends.txt"

# Clip starts are all silence_ends
cp "$TMP_DIR/silence_ends.txt" "$TMP_DIR/clip_starts.txt"

# Count clips
NUM_CLIPS=$(wc -l < "$TMP_DIR/clip_starts.txt" | tr -d ' ')

if [ "$NUM_CLIPS" -eq 1 ]; then
    echo -e "${YELLOW}Warning: Only 1 clip detected. File may already be a single sound bite.${NC}"
fi

echo "Found $NUM_CLIPS voice lines (threshold: $NOISE_THRESHOLD)"

# Sanity check before proceeding
if ! sanity_check "$NUM_CLIPS" "$DURATION" "$NOISE_THRESHOLD"; then
    echo -e "${RED}Aborted.${NC}"
    rm -rf "$TMP_DIR"
    exit 1
fi

echo "Extracting clips..."

SAVED_COUNT=0
SKIPPED_COUNT=0
CLIP_INDEX=0

# Read clip boundaries and process each
paste "$TMP_DIR/clip_starts.txt" "$TMP_DIR/clip_ends.txt" | while IFS=$'\t' read -r START END; do
    CLIP_INDEX=$((CLIP_INDEX + 1))

    # Calculate duration
    CLIP_DURATION=$(echo "$END - $START" | bc -l)

    # Skip clips that are too short
    if [ "$(echo "$CLIP_DURATION < $MIN_CLIP_DURATION" | bc -l)" -eq 1 ]; then
        echo "$CLIP_INDEX:skip" >> "$TMP_DIR/results.txt"
        continue
    fi

    # Warn if clip is too long
    if [ "$(echo "$CLIP_DURATION > $MAX_CLIP_DURATION" | bc -l)" -eq 1 ]; then
        echo -e "${YELLOW}  Warning: Clip $CLIP_INDEX is ${CLIP_DURATION}s (may have missed a split)${NC}"
    fi

    # Generate output filename (count saved clips so far)
    SAVED_SO_FAR=$(grep -c ":save" "$TMP_DIR/results.txt" 2>/dev/null || echo "0")
    CLIP_NUM=$(printf "%03d" $((SAVED_SO_FAR + 1)))
    OUTPUT_FILE="$SOUNDS_DIR/clip_${CLIP_NUM}.wav"

    # Extract and normalize clip
    ffmpeg -y -i "$INPUT_FILE" -ss "$START" -to "$END" \
        -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
        -ar 44100 \
        "$OUTPUT_FILE" 2>/dev/null

    DURATION_DISPLAY=$(printf "%.1f" "$CLIP_DURATION")
    echo "  [$CLIP_INDEX/$NUM_CLIPS] clip_${CLIP_NUM}.wav (${DURATION_DISPLAY}s)"

    echo "$CLIP_INDEX:save" >> "$TMP_DIR/results.txt"
done

# Count results
SAVED_COUNT=$(grep -c ":save" "$TMP_DIR/results.txt" 2>/dev/null || echo "0")
SKIPPED_COUNT=$(grep -c ":skip" "$TMP_DIR/results.txt" 2>/dev/null || echo "0")

# Clean up
rm -rf "$TMP_DIR"

# Remove original file
ORIGINAL_BASENAME=$(basename "$INPUT_FILE")
rm "$INPUT_FILE"

echo -e "${GREEN}Saved $SAVED_COUNT clips to sounds/$CHARACTER/${NC}"
if [ "$SKIPPED_COUNT" -gt 0 ]; then
    echo "Skipped $SKIPPED_COUNT clips (shorter than ${MIN_CLIP_DURATION}s)"
fi
echo "Removed original file: $ORIGINAL_BASENAME"
