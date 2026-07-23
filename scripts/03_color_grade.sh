#!/bin/bash
# Step 3a: Apply a warm color grade to the 32x32 video, pushing the palette
# toward amber/orange/red and away from the neutral white that fire highlights
# tend to produce.
#
# This does NOT touch framerate, palettes, or GIF encoding -- it just re-grades
# the video and writes out a new intermediate .mp4. Run 03b_make_gif.sh next
# to turn the graded video into the final looping GIF.
#
# Run this from the project root folder (led_project/).

set -e

# Move to the project root (parent of this scripts/ folder), regardless of
# where this script was called from, so the relative paths below always work.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

INPUT="working-video/02_32x32.mp4"
GRADED="working-video/03_graded.mp4"

# Warm color grade.
#   colorbalance rs/gs/bs = shadows, rm/gm/bm = midtones, rh/gh/bh = highlights.
#   Pushing blue/green down and red up in the highlights is what turns
#   near-white fire cores into amber/orange instead of neutral white.
#   Shadows (rs/gs/bs) intentionally do NOT push red -- warming the shadows
#   is what was tinting the dark background red, which LEDs then rendered
#   as a dim red haze in the "empty" areas around the flame. Only bs is
#   touched here, to gently pull blue out of the shadows without adding red.
#   eq=saturation boosts color in washed-out bright areas so there's
#   something besides white to work with downstream; gamma<1 slightly
#   darkens the very brightest pixels so fewer palette slots later get
#   "spent" on white.
WARMTH="colorbalance=rs=0:gs=0:bs=-0.15:rm=0.25:gm=-0.05:bm=-0.35:rh=0.35:gh=-0.05:bh=-0.05,eq=saturation=1.15:gamma=0.9"

# Hard channel caps: colorbalance alone shifts color balance but doesn't stop
# the brightest fire-core pixels from still landing on/near neutral white
# (255,255,255). This step caps the GREEN and BLUE channels to a ceiling
# well below full brightness, while leaving RED with its full 0-1 range.
#
# Why this preserves tonal variation instead of flattening it: `curves` here
# is a straight line from (0,0) to (1, ceiling) -- a linear rescale, not a
# clip. Every input level maps to a proportionally lower output level, so
# the whole gradient from dark ember to bright core keeps its shape; only
# the top of the range is compressed. Brightness/tonal variation still comes
# through on the (uncapped) red channel and on how close green/blue get to
# their own ceilings, so you keep gradation from deep red -> orange -> amber
# without ever reaching white.
#
# GREEN_CEILING and BLUE_CEILING are on the curves filter's 0-1 output scale.
#   - Lower BLUE_CEILING -> pushes everything more red/orange, less amber.
#   - Raise BLUE_CEILING (but keep well below GREEN_CEILING) -> more amber,
#     less pure red.
#   - Lower GREEN_CEILING -> everything trends redder overall.
#   - Raise GREEN_CEILING -> brighter areas can get more yellow/amber.
#   - Keep BLUE_CEILING noticeably lower than GREEN_CEILING, and GREEN_CEILING
#     comfortably below 1.0, or white will start creeping back in.
GREEN_CEILING=0.55
BLUE_CEILING=0.25
CHANNELCAP="curves=g='0/0 1/${GREEN_CEILING}':b='0/0 1/${BLUE_CEILING}'"

# Black crush: force near-black pixels to pure black (0,0,0) so residual
# noise/compression artifacts and anti-aliased flame edges don't survive
# as faintly-lit (and, after the grade above, faintly red) LEDs in what
# should be unlit background. BLACK_THRESHOLD is on a 0-1 scale of the
# curves filter's input range -- raise it if red haze is still visible,
# lower it if the flame's dim outer edges are getting clipped off too
# aggressively.
BLACK_THRESHOLD=0.06
BLACKCRUSH="curves=all='0/0 ${BLACK_THRESHOLD}/0 1/1'"

# Full filter chain applied to the video: warmth grade, channel caps
# (kills white), then black crush.
FILTERS="${WARMTH},${CHANNELCAP},${BLACKCRUSH}"

echo "=== Step 3: Color grade (warm amber/orange/red, no white) ==="
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
mkdir -p "$(dirname "$GRADED")"

echo "--- Applying warmth + channel-cap + black-crush filter chain ---"
echo "Command: ffmpeg -y -i \"$INPUT\" -vf \"$FILTERS\" -c:v libx264 -crf 12 -pix_fmt yuv420p \"$GRADED\""
ffmpeg -y -i "$INPUT" \
  -vf "${FILTERS}" \
  -c:v libx264 -crf 12 -pix_fmt yuv420p \
  "$GRADED"

if [ -f "$GRADED" ]; then
  echo "SUCCESS: Graded video saved to $GRADED ($(du -h "$GRADED" | cut -f1))"
else
  echo "ERROR: ffmpeg finished but $GRADED was not created."
  exit 1
fi

echo ""
echo "Next step: run 03_make_gif.sh to encode this into the final GIF."
echo ""
echo "Tuning tips if the color isn't right yet (edit the variables above and re-run):"
echo "  - Still seeing whitish/pale spots?  Lower GREEN_CEILING and/or"
echo "    BLUE_CEILING (e.g. GREEN_CEILING=0.45, BLUE_CEILING=0.18)."
echo "  - Everything too flat/uniformly red, losing the amber highlights?"
echo "    Raise GREEN_CEILING a bit (e.g. 0.65) so bright areas can go more amber."
echo "  - Too red/muddy overall?     Lower eq=saturation, e.g. saturation=1.15"
echo "  - Red haze in dark/empty areas (dim red LEDs where it should be unlit)?"
echo "    Raise BLACK_THRESHOLD, e.g. 0.10, to crush more of the low end to true black."
echo "  - Flame's dim outer edges/embers getting clipped off too much?"
echo "    Lower BLACK_THRESHOLD, e.g. 0.03, so less of the low end gets crushed."
echo "  - Want it punchier for the LED panel? LEDs wash out subtle gradients, so"
echo "    slightly higher saturation/contrast than looks 'right' on a monitor is fine."