#!/bin/bash
# Step 2: Resize the square video down to 32x32 for the LED matrix.

set -e

INPUT="working-video/fire_01_square.mp4"
OUTPUT="working-video/fire_02_32x32.mp4"

echo "=== Step 2: Resize to 32x32 ==="
echo "Script running from: $(pwd)"
echo "Looking for input file: $INPUT"

if ! command -v ffmpeg &> /dev/null; then
  echo "ERROR: ffmpeg is not installed or not on your PATH."
  exit 1
fi
echo "ffmpeg found: $(command -v ffmpeg)"

if [ ! -f "$INPUT" ]; then
  echo "ERROR: Input file '$INPUT' not found in $(pwd)."
  echo "Files in this folder:"
  ls -la
  exit 1
fi
echo "Input file found: $INPUT ($(du -h "$INPUT" | cut -f1))"

echo "Running ffmpeg..."
echo "Command: ffmpeg -i \"$INPUT\" -vf \"scale=32:32:flags=area\" -c:a copy \"$OUTPUT\""

ffmpeg -i "$INPUT" \
  -vf "scale=32:32:flags=area" \
  -c:a copy \
  "$OUTPUT"

if [ -f "$OUTPUT" ]; then
  echo "SUCCESS: Resized video saved to $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
else
  echo "ERROR: ffmpeg finished but $OUTPUT was not created."
  exit 1
fi