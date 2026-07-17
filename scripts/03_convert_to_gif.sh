#!/bin/bash
# Step 3: Convert the 32x32 video to a high-quality, seamlessly-looping animated GIF.
#
# This is a two-pass process:
#   Pass 1: generate a custom 256-color palette optimized for this specific video
#           (avoids the color banding you'd get from ffmpeg's generic default palette,
#           which matters a lot for smooth fire gradients)
#   Pass 2: encode the GIF using that palette
#
# Run this from the project root folder (fire_led_project/).

set -e

# Move to the project root (parent of this scripts/ folder), regardless of
# where this script was called from, so the relative paths below always work.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

INPUT="working-video/fire_02_32x32.mp4"
PALETTE="working-video/palette.png"
OUTPUT="output-gif/fire_animation.gif"

# Frames per second for the final GIF. 12 is a good balance of smoothness vs. file size
# for a 32x32 matrix -- see notes below if you want to try 15.
FPS=12

echo "=== Step 3: Convert to GIF ==="
echo "Project root: $(pwd)"
echo "Looking for input file: $INPUT"

if ! command -v ffmpeg &> /dev/null; then
  echo "ERROR: ffmpeg is not installed or not on your PATH."
  exit 1
fi
echo "ffmpeg found: $(command -v ffmpeg)"

if [ ! -f "$INPUT" ]; then
  echo "ERROR: Input file '$INPUT' not found."
  echo "Run 02_resize_32x32.sh first."
  exit 1
fi
echo "Input file found: $INPUT ($(du -h "$INPUT" | cut -f1))"

echo "--- Pass 1: generating custom palette ---"
echo "Command: ffmpeg -y -i \"$INPUT\" -vf \"fps=$FPS,palettegen\" \"$PALETTE\""
ffmpeg -y -i "$INPUT" \
  -vf "fps=$FPS,palettegen" \
  "$PALETTE"

if [ ! -f "$PALETTE" ]; then
  echo "ERROR: Palette generation failed, $PALETTE was not created."
  exit 1
fi
echo "Palette generated: $PALETTE"

echo "--- Pass 2: encoding GIF with custom palette ---"
echo "Command: ffmpeg -y -i \"$INPUT\" -i \"$PALETTE\" -filter_complex \"fps=$FPS[x];[x][1:v]paletteuse\" -loop 0 \"$OUTPUT\""
ffmpeg -y -i "$INPUT" -i "$PALETTE" \
  -filter_complex "fps=$FPS[x];[x][1:v]paletteuse" \
  -loop 0 \
  "$OUTPUT"

if [ -f "$OUTPUT" ]; then
  echo "SUCCESS: GIF saved to $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
else
  echo "ERROR: ffmpeg finished but $OUTPUT was not created."
  exit 1
fi
