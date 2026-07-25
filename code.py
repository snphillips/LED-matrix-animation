# =============================================================
# Fire animation player for MatrixPortal S3 + 32x32 RGB LED matrix
# Plays /gifs/animation.gif on loop, dimmed to a chosen brightness
# =============================================================

import time
import board
import displayio
import framebufferio
import rgbmatrix
import gifio
import bitmaptools
import audiocore
import audiobusio
import audiomixer
import os

# -------------------------------------------------------------
# Release any previously-configured displays (needed so the code
# can be re-run/reloaded without conflicting with a prior display)
# -------------------------------------------------------------
displayio.release_displays()

# -------------------------------------------------------------
# Configure the physical LED matrix connection.
# These board.MTX_* pin names are built in on the MatrixPortal S3
# and correspond to the HUB75 connector wired to the panel.
# width/height=32 matches the 32x32 6mm matrix.
# bit_depth=4 controls color depth (more = smoother gradients,
# more RAM/CPU used).
# -------------------------------------------------------------
matrix = rgbmatrix.RGBMatrix(
    width=32, height=32, bit_depth=4,
    rgb_pins=[board.MTX_R1, board.MTX_G1, board.MTX_B1,
              board.MTX_R2, board.MTX_G2, board.MTX_B2],
    addr_pins=[board.MTX_ADDRA, board.MTX_ADDRB, board.MTX_ADDRC, board.MTX_ADDRD],
    clock_pin=board.MTX_CLK, latch_pin=board.MTX_LAT,
    output_enable_pin=board.MTX_OE,
)

# -------------------------------------------------------------
# Wrap the matrix in a displayio-compatible Display object.
# auto_refresh=False means WE control exactly when the panel
# redraws, by calling display.refresh() ourselves.
# -------------------------------------------------------------
display = framebufferio.FramebufferDisplay(matrix, auto_refresh=False)

# -------------------------------------------------------------
# Open the gif file from the CIRCUITPY filesystem.
# next_frame() must be called once up front to actually decode
# and load the first frame into odg.bitmap before we use it.
# -------------------------------------------------------------
odg = gifio.OnDiskGif("/gifs/animation.gif")
next_delay = odg.next_frame()

# -------------------------------------------------------------
# Brightness control: 1.0 = full brightness, 0.0 = fully black.
# Adjust this value to taste for your fireplace install.
# -------------------------------------------------------------
BRIGHTNESS = 0.8

# -------------------------------------------------------------
# Build a solid black bitmap the same size as the gif frames.
# We'll blend each gif frame against this black bitmap to
# reduce its overall brightness (since the matrix itself has
# no brightness setting).
# -------------------------------------------------------------
black = displayio.Bitmap(odg.bitmap.width, odg.bitmap.height, 65536)

# -------------------------------------------------------------
# This is the bitmap that will actually be shown on screen.
# Each frame, we'll write the dimmed/blended result into it.
# 65536 = using the full 16-bit RGB565 color range.
# -------------------------------------------------------------
dimmed = displayio.Bitmap(odg.bitmap.width, odg.bitmap.height, 65536)

# Color format used by the gif frame data on this hardware
colorspace = displayio.Colorspace.RGB565_SWAPPED

# -------------------------------------------------------------
# Set up the on-screen display group, pointing at our "dimmed"
# bitmap (not the raw gif bitmap) so dimming is visible.
# -------------------------------------------------------------
group = displayio.Group()
face = displayio.TileGrid(
    dimmed,
    pixel_shader=displayio.ColorConverter(input_colorspace=colorspace),
)
group.append(face)
display.root_group = group

# -------------------------------------------------------------
# Audio setup: loops whatever WAV file is in /sound/ continuously in the
# background over I2S, at a fixed ambient volume. No on/off logic
# starts as soon as the board powers on and never stops.
# -------------------------------------------------------------

# Ambient playback volume. 0.0 = silent, 1.0 = full volume.
# Tweak this to taste
# buried in the setup code below.
VOLUME = 0.5

audio = audiobusio.I2SOut(bit_clock=board.A2, word_select=board.A3, data=board.A1)

# NOTE: sample_rate and channel_count here must match your actual
# WAV file's properties. Check your file (e.g. via `afinfo` on Mac,
# or your audio editor's export settings) and adjust these two
# values to match -- mismatches will play back at the wrong speed
# or pitch.
mixer = audiomixer.Mixer(
    voice_count=1,
    sample_rate=22050,
    channel_count=1,
    bits_per_sample=16,
    samples_signed=True,
    buffer_size=2048,
)
audio.play(mixer)

# Find whatever sound file is in /sound/ (instead of hardcoding a filename)
sound_dir = "/sound"
sound_files = [
    f for f in os.listdir(sound_dir)
    if f.lower().endswith(".wav") and not f.startswith(".")
]

if not sound_files:
    raise RuntimeError("No .wav file found in /sound/")

fire_sound_path = sound_dir + "/" + sound_files[0]
fire_sound = audiocore.WaveFile(fire_sound_path)
mixer.voice[0].level = VOLUME
mixer.voice[0].play(fire_sound, loop=True)


# -------------------------------------------------------------
# Blend the current raw gif frame (odg.bitmap) with black,
# at the chosen BRIGHTNESS strength, writing the result into
# "dimmed" (the bitmap actually shown on the panel).
# -------------------------------------------------------------
def blend_frame():
    bitmaptools.alphablend(dimmed, odg.bitmap, black, colorspace, BRIGHTNESS)


# -------------------------------------------------------------
# Draw the first frame before starting the loop
# -------------------------------------------------------------
blend_frame()
display.refresh()

# -------------------------------------------------------------
# Main loop: wait the gif's per-frame delay, decode the next
# frame, dim it, and push it to the panel. Repeats forever,
# looping the gif indefinitely.
# -------------------------------------------------------------
while True:
    time.sleep(next_delay)
    next_delay = odg.next_frame()
    blend_frame()
    display.refresh(minimum_frames_per_second=0)