# =============================================================
# Fire animation player for MatrixPortal S3 + 32x32 RGB LED matrix
# Plays /gifs/fire_animation.gif on loop, dimmed to a chosen brightness
# =============================================================

import time
import board
import displayio
import framebufferio
import rgbmatrix
import gifio
import bitmaptools

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
odg = gifio.OnDiskGif("/gifs/fire_animation.gif")
next_delay = odg.next_frame()

# -------------------------------------------------------------
# Brightness control: 1.0 = full brightness, 0.0 = fully black.
# Adjust this value to taste for your fireplace install.
# -------------------------------------------------------------
BRIGHTNESS = 0.4

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