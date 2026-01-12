#!/usr/bin/env python3
"""
clip-sounds-vad.py - Split audio compilations using Voice Activity Detection

Uses Silero VAD to detect speech segments, which works better than silence
detection when there's background music or noise.

Usage:
    ./clip-sounds-vad.py <character> <input-file>

Example:
    ./clip-sounds-vad.py marine sounds/marine/marine_quotes.wav

Requirements:
    pip install torch soundfile numpy
"""

import sys
import argparse
from pathlib import Path

import numpy as np
import soundfile as sf
import torch

# Silero VAD is loaded via torch.hub
SAMPLING_RATE = 16000  # Silero VAD requires 16kHz


def load_audio(file_path: str) -> tuple[np.ndarray, int]:
    """Load audio file and return numpy array and sample rate."""
    data, sample_rate = sf.read(file_path)

    # Convert to mono if stereo
    if len(data.shape) > 1:
        data = data.mean(axis=1)

    return data, sample_rate


def resample(audio: np.ndarray, orig_sr: int, target_sr: int) -> np.ndarray:
    """Simple resampling using linear interpolation."""
    if orig_sr == target_sr:
        return audio

    # Calculate new length
    duration = len(audio) / orig_sr
    new_length = int(duration * target_sr)

    # Linear interpolation
    old_indices = np.linspace(0, len(audio) - 1, new_length)
    new_audio = np.interp(old_indices, np.arange(len(audio)), audio)

    return new_audio


def get_speech_timestamps(audio: torch.Tensor, model, get_speech_ts) -> list:
    """Get speech timestamps using Silero VAD."""
    speech_timestamps = get_speech_ts(
        audio,
        model,
        sampling_rate=SAMPLING_RATE,
        threshold=0.5,  # Speech probability threshold
        min_speech_duration_ms=250,  # Minimum speech segment
        min_silence_duration_ms=300,  # Minimum gap between segments
        speech_pad_ms=30,  # Padding around speech
    )

    return speech_timestamps


def save_clip(
    audio: np.ndarray,
    sample_rate: int,
    output_path: str,
    start_sec: float,
    end_sec: float,
):
    """Extract and save a clip from the audio array."""
    start_sample = int(start_sec * sample_rate)
    end_sample = int(end_sec * sample_rate)

    clip = audio[start_sample:end_sample]
    sf.write(output_path, clip, sample_rate)


def main():
    parser = argparse.ArgumentParser(
        description="Split audio using Voice Activity Detection"
    )
    parser.add_argument("character", help="Character name (e.g., marine, zealot)")
    parser.add_argument("input_file", help="Audio file to split")
    parser.add_argument(
        "--min-duration",
        type=float,
        default=0.5,
        help="Minimum clip duration in seconds (default: 0.5)",
    )
    parser.add_argument(
        "--max-duration",
        type=float,
        default=10.0,
        help="Maximum clip duration in seconds (default: 10.0)",
    )
    parser.add_argument(
        "--keep-original",
        action="store_true",
        help="Don't delete the original file after splitting",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.5,
        help="VAD threshold 0-1 (default: 0.5, higher = stricter)",
    )
    args = parser.parse_args()

    input_path = Path(args.input_file)
    if not input_path.exists():
        print(f"Error: File not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    # Output directory
    script_dir = Path(__file__).parent
    output_dir = script_dir / "sounds" / args.character
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading Silero VAD model...")
    model, utils = torch.hub.load(
        repo_or_dir="snakers4/silero-vad",
        model="silero_vad",
        force_reload=False,
        onnx=False,
        trust_repo=True,
    )
    get_speech_ts = utils[0]

    print(f"Loading audio: {input_path}")
    audio_orig, orig_sr = load_audio(str(input_path))
    duration_sec = len(audio_orig) / orig_sr
    print(f"Duration: {duration_sec:.1f}s, Sample rate: {orig_sr}Hz")

    # Resample to 16kHz for VAD
    print("Resampling to 16kHz for VAD...")
    audio_16k = resample(audio_orig, orig_sr, SAMPLING_RATE)
    audio_tensor = torch.from_numpy(audio_16k).float()

    print("Detecting speech segments...")
    timestamps = get_speech_timestamps(audio_tensor, model, get_speech_ts)
    print(f"Found {len(timestamps)} speech segments")

    # Filter and save clips
    saved_count = 0
    skipped_short = 0
    skipped_long = 0

    for i, ts in enumerate(timestamps):
        # Convert sample indices to seconds
        start_sec = ts["start"] / SAMPLING_RATE
        end_sec = ts["end"] / SAMPLING_RATE
        duration = end_sec - start_sec

        if duration < args.min_duration:
            skipped_short += 1
            continue

        if duration > args.max_duration:
            print(
                f"  Warning: Segment {i+1} is {duration:.1f}s (max {args.max_duration}s)"
            )
            skipped_long += 1
            continue

        saved_count += 1
        clip_num = f"{saved_count:03d}"
        output_path = output_dir / f"clip_{clip_num}.wav"

        save_clip(audio_orig, orig_sr, str(output_path), start_sec, end_sec)
        print(f"  [{saved_count}] clip_{clip_num}.wav ({duration:.1f}s)")

    print(f"\nSaved {saved_count} clips to {output_dir}/")
    if skipped_short:
        print(f"Skipped {skipped_short} clips shorter than {args.min_duration}s")
    if skipped_long:
        print(f"Skipped {skipped_long} clips longer than {args.max_duration}s")

    # Remove original file
    if not args.keep_original:
        input_path.unlink()
        print(f"Removed original: {input_path.name}")


if __name__ == "__main__":
    main()
