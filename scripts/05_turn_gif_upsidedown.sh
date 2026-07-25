# Takes working-video/animation.gif, flips it upside down with ffmpeg, and
# saves the result into output-gif/ (the original input is left untouched).
#
# Expected layout (paths relative to this script's location):
#   scripts/
#     05_turn_gif_upsidedown.sh          <- this script
#   working-video/
#     animation.gif    <- input
#   output-gif/
#     animation_flipped.gif  <- output (written by this script)
#
# Usage:
#   ./05_turn_gif_upsidedown.sh
#
# Requirements:
#   ffmpeg must be installed and on your PATH.

set -euo pipefail

# Resolve the directory this script lives in (scripts/), then step up to
# the project root so we can reach the sibling folders.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."

GIF="$ROOT_DIR/working-video/04_gif.gif"
OUTPUT_DIR="$ROOT_DIR/output-gif"

if [ ! -f "$GIF" ]; then
    echo "Error: $GIF not found." >&2
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: output directory $OUTPUT_DIR not found." >&2
    exit 1
fi

output="$OUTPUT_DIR/animation_flipped.gif"

echo "Flipping: $(basename "$GIF") -> $(basename "$output")"
ffmpeg -y -i "$GIF" -vf "vflip" -loop 0 "$output"

echo "Done. Flipped gif saved to $output"