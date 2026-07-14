#!/bin/bash
# Step 1: Crop letterboxed video to a square.
# Height is kept as-is; excess width is trimmed equally from left and right.

set -e

INPUT="fire_input.mp4"
OUTPUT="fire_01_square.mp4"

echo "=== Step 1: Crop to square ==="
echo "Script running from: $(pwd)"
echo "Looking for input file: $INPUT"

# Check ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
  echo "ERROR: ffmpeg is not installed or not on your PATH."
  echo "Install it first (e.g. 'brew install ffmpeg' on macOS, 'apt install ffmpeg' on Linux)."
  exit 1
fi
echo "ffmpeg found: $(command -v ffmpeg)"

# Check input file exists
if [ ! -f "$INPUT" ]; then
  echo "ERROR: Input file '$INPUT' not found in $(pwd)."
  echo "Files in this folder:"
  ls -la
  exit 1
fi
echo "Input file found: $INPUT ($(du -h "$INPUT" | cut -f1))"

echo "Running ffmpeg..."
echo "Command: ffmpeg -i \"$INPUT\" -vf \"crop=ih:ih\" -c:a copy \"$OUTPUT\""

ffmpeg -i "$INPUT" \
  -vf "crop=ih:ih" \
  -c:a copy \
  "$OUTPUT"

echo "ffmpeg exit code: $?"

# Check output file was actually created
if [ -f "$OUTPUT" ]; then
  echo "SUCCESS: Cropped square video saved to $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
else
  echo "ERROR: ffmpeg finished but $OUTPUT was not created."
  exit 1
fi