# Sound Library

This directory contains Starcraft character voice lines organized by character.

## Directory Structure

```
sounds/
├── marine/
│   ├── idle/         # Played on idle_prompt (waiting for input)
│   │   └── yes_sir.wav
│   ├── complete/     # Played on Stop (task finished)
│   │   └── job_done.wav
│   └── ready.wav     # Fallback (played if no event-specific sounds)
├── zealot/
│   ├── idle/
│   ├── complete/
│   └── (fallback sounds)
├── battlecruiser/
├── hydralisk/
├── carrier/
└── (add more characters as needed)
```

### Event-Specific Sounds

For contextually appropriate audio, organize sounds into subdirectories:

| Event | Directory | Example Lines |
|-------|-----------|---------------|
| `idle_prompt` | `{character}/idle/` | "Yes sir?", "What do you need?", questioning sounds |
| `Stop` | `{character}/complete/` | "Job's done!", "Ready!", confirmation sounds |

**Fallback behavior**: If no event-specific subdirectory exists, sounds from the root character directory are used. This maintains backwards compatibility.

## Adding Sounds

1. Place `.wav`, `.mp3`, or `.aiff` files in the appropriate character directory
2. File names don't matter - the script picks randomly from available files
3. Keep audio levels roughly consistent across clips

## Suggested Voice Lines

| Character | Lines |
|-----------|-------|
| Marine | "You want a piece of me, boy?", "Go go go!", "Ready to roll out" |
| Zealot | "My life for Aiur!", "En Taro Adun", "I have returned" |
| Battlecruiser | "Battlecruiser operational", "Set a course", "Make it happen" |
| Carrier | "Carrier has arrived", "Our enemies must be eradicated" |
| Hydralisk | (hissing/growling sounds) |

## Sourcing Sounds

### Option 1: Extract from Game Files (if you own the games)

**Starcraft Remastered / Brood War:**
- Sounds are in `.wav` format in the game's CASC archives
- Tool: [CascView](http://www.zezula.net/en/casc/main.html) can extract
- Path: `Sound/` directory contains unit responses

**Starcraft 2:**
- Sounds in CASC archives
- Tool: CascView or [SC2 Mapster tools](https://sc2mapster.gamepedia.com/)
- Higher quality audio, more voice lines

### Option 2: Fan Archives

- Various fan sites host extracted sounds
- YouTube "all unit quotes" compilations - use `yt-dlp` to download, then split with `clip-sounds-vad.py`
- Liquipedia/Wiki often link to sound files

## Splitting Audio Compilations

Two scripts are available for splitting compilation files into individual clips:

### clip-sounds-vad.py (Recommended)

Uses Voice Activity Detection (Silero VAD) to detect speech segments. Works much better than silence detection when there's background music or noise.

```bash
# Install dependencies
pip install torch torchaudio soundfile numpy packaging

# Or run with uvx (no install needed)
uvx --with torch --with torchaudio --with soundfile --with numpy --with packaging \
    python clip-sounds-vad.py marine sounds/marine/marine_quotes.wav

# Options
--min-duration 0.5   # Minimum clip length (default: 0.5s)
--max-duration 10.0  # Maximum clip length (default: 10.0s)
--threshold 0.5      # VAD threshold 0-1 (default: 0.5, higher = stricter)
--keep-original      # Don't delete source file after splitting
```

**Note**: VAD is trained for human speech. For Zerg units (hydralisk, mutalisk, zergling) and heavily processed voices (archon), use `clip-sounds.sh` instead.

### clip-sounds.sh (Fallback)

Uses ffmpeg silence detection. Works for non-human sounds but may produce long clips when there's background music.

```bash
./clip-sounds.sh marine sounds/marine/marine_quotes.wav

# Adjust threshold for different audio
NOISE_THRESHOLD=-15dB ./clip-sounds.sh battlecruiser sounds/battlecruiser/quotes.wav
```

## Audio Normalization

For consistent volume levels across clips, you can use:

```bash
# Using ffmpeg to normalize a single file
ffmpeg -i input.wav -af "loudnorm=I=-16:TP=-1.5:LRA=11" output.wav

# Batch normalize all wavs in a directory
for f in *.wav; do
  ffmpeg -i "$f" -af "loudnorm=I=-16:TP=-1.5:LRA=11" "normalized_$f"
done
```
