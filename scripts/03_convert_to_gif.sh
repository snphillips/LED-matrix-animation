#!/bin/bash
# Step 3: Convert the 32x32 video to a high-quality, seamlessly-looping animated GIF,
# with a warm color grade to push the palette toward amber/orange/red and away from
# the neutral white that fire highlights tend to produce.
#
# This is a two-pass process:
#   Pass 1: generate a custom 256-color palette optimized for this specific video
#           (avoids the color banding you'd get from ffmpeg's generic default palette,
#           which matters a lot for smooth fire gradients)
#   Pass 2: encode the GIF using that palette
#
# Both passes apply the SAME warmth filter chain before palette generation/use,
# so the palette and the final GIF colors match.
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

# Warm color grade applied before both palettegen and paletteuse.
#   colorbalance rs/gs/bs = shadows, rm/gm/bm = midtones, rh/gh/bh = highlights.
#   Pushing blue/green down and red up in the highlights is what turns
#   near-white fire cores into amber/orange instead of neutral white.
#   eq=saturation boosts color in washed-out bright areas so palettegen has
#   something besides white to work with; gamma<1 slightly darkens the very
#   brightest pixels so fewer palette slots get "spent" on white.
WARMTH="colorbalance=rs=0.15:gs=-0.05:bs=-0.25:rm=0.25:gm=-0.05:bm=-0.35:rh=0.35:gh=-0.05:bh=-0.45,eq=saturation=1.35:gamma=0.9"

echo "=== Step 3: Convert to GIF (warm amber/orange/red grade) ==="
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

# Make sure the output directory exists
mkdir -p "$(dirname "$OUTPUT")"

echo "--- Pass 1: generating custom warm-toned palette ---"
echo "Command: ffmpeg -y -i \"$INPUT\" -vf \"fps=$FPS,${WARMTH},palettegen=max_colors=256:stats_mode=diff:reserve_transparent=0\" \"$PALETTE\""
ffmpeg -y -i "$INPUT" \
  -vf "fps=${FPS},${WARMTH},palettegen=max_colors=256:stats_mode=diff:reserve_transparent=0" \
  "$PALETTE"

if [ ! -f "$PALETTE" ]; then
  echo "ERROR: Palette generation failed, $PALETTE was not created."
  exit 1
fi
echo "Palette generated: $PALETTE"

echo "--- Pass 2: encoding GIF with custom palette ---"
echo "Command: ffmpeg -y -i \"$INPUT\" -i \"$PALETTE\" -filter_complex \"fps=$FPS,${WARMTH}[x];[x][1:v]paletteuse\" -loop 0 \"$OUTPUT\""
ffmpeg -y -i "$INPUT" -i "$PALETTE" \
  -filter_complex "fps=${FPS},${WARMTH}[x];[x][1:v]paletteuse" \
  -loop 0 \
  "$OUTPUT"

if [ -f "$OUTPUT" ]; then
  echo "SUCCESS: GIF saved to $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
else
  echo "ERROR: ffmpeg finished but $OUTPUT was not created."
  exit 1
fi

echo ""
echo "Tuning tips if the color isn't right yet:"
echo "  - Still too white/pale?  Push bh (blue in highlights) more negative, e.g. bh=-0.6"
echo "  - Too red/muddy?        Lower eq=saturation, e.g. saturation=1.15"
echo "  - Want it punchier for the LED panel? LEDs wash out subtle gradients, so"
echo "    slightly higher saturation/contrast than looks 'right' on a monitor is fine."