# Add Sound Skill

Add and normalize a sound file to the claude-overlord sound library.

## Usage

```
/add-sound <character> <path-to-sound-file>
```

Examples:
- `/add-sound marine ~/Downloads/go_go_go.wav`
- `/add-sound zealot /tmp/my_life_for_aiur.mp3`

## Arguments

- `character`: The character name (e.g., marine, zealot, battlecruiser). Directory will be created if it doesn't exist.
- `path`: Path to the audio file (.wav, .mp3, or .aiff)

## Instructions

When this skill is invoked:

1. **Parse arguments**: Extract the character name and file path from the args.

2. **Validate the input file**:
   - Check the file exists
   - Verify it has a supported extension (.wav, .mp3, .aiff)
   - If invalid, explain the issue and exit

3. **Check for ffmpeg**:
   - Run `which ffmpeg` to verify ffmpeg is installed
   - If not installed, tell the user to run `brew install ffmpeg`

4. **Determine the target directory**:
   - Target is `sounds/{character}/` in this project
   - Create the directory if it doesn't exist: `mkdir -p sounds/{character}`

5. **Normalize and copy the audio**:
   - Use ffmpeg with loudnorm filter for consistent volume:
   ```bash
   ffmpeg -i "{input_file}" -af "loudnorm=I=-16:TP=-1.5:LRA=11" -ar 44100 "sounds/{character}/{filename}"
   ```
   - Keep the original filename but ensure .wav output for consistency

6. **Confirm success**:
   - Tell the user the file was added
   - Show the path: `sounds/{character}/{filename}`
   - Remind them to test with: `afplay sounds/{character}/{filename}`

## Error Handling

- If file doesn't exist: "File not found: {path}"
- If unsupported format: "Unsupported format. Use .wav, .mp3, or .aiff"
- If ffmpeg not installed: "ffmpeg is required. Install with: brew install ffmpeg"
- If ffmpeg fails: Show the error output for debugging
