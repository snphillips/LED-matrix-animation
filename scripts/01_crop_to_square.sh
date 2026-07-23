#!/bin/bash
# Step 1: Crop letterboxed/pillarboxed video to a square.
#
# Works for both orientations:
#   - Horizontal video (width > height): height is kept as-is,
#     excess width is trimmed equally from left and right.
#   - Vertical video (height > width): width is kept as-is,
#     excess height is trimmed equally from top and bottom.
#
# This is done with a single crop expression that uses whichever
# dimension is smaller (min(iw,ih)) as the square side length, and
# ffmpeg's crop filter centers the crop by default.

set -e

SOURCE_DIR="source-video"
OUTPUT="working-video/01_square.mp4"

echo "=== Step 1: Crop to square ==="
echo "Script running from: $(pwd)"
echo "Looking for an .mp4 in: $SOURCE_DIR"

# Check ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
  echo "ERROR: ffmpeg is not installed or not on your PATH."
  echo "Install it first (e.g. 'brew install ffmpeg' on macOS, 'apt install ffmpeg' on Linux)."
  exit 1
fi
echo "ffmpeg found: $(command -v ffmpeg)"

# Find the input mp4 in SOURCE_DIR. Since we're only processing one file at a
# time, pick whatever single .mp4 is in there rather than requiring an exact
# filename.
mp4_files=("$SOURCE_DIR"/*.mp4)

if [ ! -e "${mp4_files[0]}" ]; then
  echo "ERROR: No .mp4 files found in $SOURCE_DIR."
  echo "Files in this folder:"
  ls -la "$SOURCE_DIR" 2>/dev/null || echo "  (directory does not exist)"
  exit 1
fi

if [ "${#mp4_files[@]}" -gt 1 ]; then
  echo "WARNING: Multiple .mp4 files found in $SOURCE_DIR, using the first one:"
  printf '  %s\n' "${mp4_files[@]}"
fi

INPUT="${mp4_files[0]}"
echo "Input file found: $INPUT ($(du -h "$INPUT" | cut -f1))"

# Report source orientation/dimensions for visibility (best-effort; doesn't fail the script)
if command -v ffprobe &> /dev/null; then
  DIMS=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
    -of csv=s=x:p=0 "$INPUT" 2>/dev/null || true)
  if [ -n "$DIMS" ]; then
    SRC_W=$(echo "$DIMS" | cut -d'x' -f1)
    SRC_H=$(echo "$DIMS" | cut -d'x' -f2)
    if [ "$SRC_W" -gt "$SRC_H" ] 2>/dev/null; then
      echo "Detected orientation: horizontal (${SRC_W}x${SRC_H}) — will trim width to ${SRC_H}x${SRC_H}"
    elif [ "$SRC_H" -gt "$SRC_W" ] 2>/dev/null; then
      echo "Detected orientation: vertical (${SRC_W}x${SRC_H}) — will trim height to ${SRC_W}x${SRC_W}"
    else
      echo "Detected orientation: already square (${SRC_W}x${SRC_H})"
    fi
  fi
fi

echo "Running ffmpeg..."
echo "Command: ffmpeg -i \"$INPUT\" -vf \"crop=min(iw\\,ih):min(iw\\,ih)\" -c:a copy \"$OUTPUT\""

# crop=min(iw,ih):min(iw,ih) uses whichever dimension is smaller as the
# square side. ffmpeg centers the crop automatically, so this correctly
# trims the sides on horizontal video and trims top/bottom on vertical
# video without needing separate logic for each case.
ffmpeg -i "$INPUT" \
  -vf "crop=min(iw\,ih):min(iw\,ih)" \
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