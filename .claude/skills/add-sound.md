# Add Sound Skill

Add and normalize a sound file to the claude-overlord sound library.

## Usage

```
/add-sound <character> <source> [output-filename]
```

### From local file:
- `/add-sound marine ~/Downloads/go_go_go.wav`
- `/add-sound zealot /tmp/my_life_for_aiur.mp3`

### From YouTube:
- `/add-sound marine https://www.youtube.com/watch?v=xyz123`
- `/add-sound marine https://www.youtube.com/watch?v=xyz123 go_go_go.wav`

## Sound Source

**Recommended**: https://www.youtube.com/@starcraft2units

This YouTube channel has individual unit quote compilations for SC2 units. Search for the character name to find their quotes video.

## Arguments

- `character`: The character name (e.g., marine, zealot, hellbat). Directory will be created if it doesn't exist.
- `source`: Either a local file path (.wav, .mp3, .aiff) OR a YouTube URL
- `output-filename`: Optional. For YouTube downloads, specify the output filename.

## Instructions

When this skill is invoked:

1. **Parse arguments**: Extract the character name and source from the args.

2. **Detect source type**:
   - If source starts with `http` or contains `youtube.com` or `youtu.be` → YouTube URL
   - Otherwise → local file path

### For YouTube URLs:

3. **Use the download script**:
   ```bash
   ./download-sound.sh <character> "<youtube-url>" [output-filename]
   ```
   This script handles:
   - Downloading audio via yt-dlp
   - Converting to wav via ffmpeg
   - Normalizing volume with loudnorm filter
   - Saving to `sounds/{character}/`

4. **Confirm success**: Show the saved path and test command.

### For Local Files:

3. **Validate the input file**:
   - Check the file exists
   - Verify it has a supported extension (.wav, .mp3, .aiff)
   - If invalid, explain the issue and exit

4. **Check for ffmpeg**:
   - Run `which ffmpeg` to verify ffmpeg is installed
   - If not installed, tell the user to run `brew install ffmpeg`

5. **Determine the target directory**:
   - Target is `sounds/{character}/` in this project
   - Create the directory if it doesn't exist: `mkdir -p sounds/{character}`

6. **Normalize and copy the audio**:
   - Use ffmpeg with loudnorm filter for consistent volume:
   ```bash
   ffmpeg -i "{input_file}" -af "loudnorm=I=-16:TP=-1.5:LRA=11" -ar 44100 "sounds/{character}/{filename}"
   ```
   - Keep the original filename but ensure .wav output for consistency

7. **Confirm success**:
   - Tell the user the file was added
   - Show the path: `sounds/{character}/{filename}`
   - Remind them to test with: `afplay sounds/{character}/{filename}`

## Dependencies

- `yt-dlp` - for YouTube downloads: `brew install yt-dlp`
- `ffmpeg` - for audio conversion/normalization: `brew install ffmpeg`

## Error Handling

- If file doesn't exist: "File not found: {path}"
- If unsupported format: "Unsupported format. Use .wav, .mp3, or .aiff"
- If ffmpeg not installed: "ffmpeg is required. Install with: brew install ffmpeg"
- If yt-dlp not installed: "yt-dlp is required for YouTube. Install with: brew install yt-dlp"
- If download fails: Show the error output for debugging
