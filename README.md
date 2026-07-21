# LED Matrix Animation - Faux Fireplace

This repo contains scripts to process a video into a gif, for upload to the Adafruit MatrixPortal S3 (https://www.adafruit.com/product/5778), which attaches to the 32x32 RGB LED Matrix Panel - 6mm pitch (https://www.adafruit.com/product/1484).

## Folder structure
```
fire_led_project/
├── scripts/    ← the ffmpeg scripts, run in order
├── source-video/     ← put your original fire_input.mp4 here
├── working-video/    ← intermediate files land here automatically
└── output-gif/     ← final fire_animation.gif lands here
```

## Workflow: creating the GIF

1. Place your source video at `source-video/fire_input.mp4`
2. From the `fire_led_project/` root folder, run each script in order:

```bash
chmod +x scripts/*.sh
./scripts/01_crop_to_square.sh
./scripts/02_resize_32x32.sh
./scripts/03_convert_to_gif.sh
```

3. Your final GIF will be at `output-gif/fire_animation.gif`, ready to load onto
   the MatrixPortal S3 (see below).

### Notes
- Step 3 defaults to 12 fps. At 15 seconds long, that's 180 frames total — a good
  balance of smoothness vs. file size for a 32x32 panel. If you want slightly
  smoother motion, open `scripts/03_convert_to_gif.sh` and change `FPS=12` to
  `FPS=15`, but check the resulting file size isn't ballooning too much.
- The GIF is set to loop infinitely (`-loop 0`).
- `working/` files are intermediate and safe to delete once you're happy with
  the final GIF in `output-gif/`.

---

## Workflow: preparing the MatrixPortal S3 and loading the GIF

The Animated GIF Player is Arduino-based firmware, not a CircuitPython script.
CircuitPython is only used temporarily to set up the board's file storage —
once the GIF player firmware is flashed, it replaces CircuitPython entirely.

Official guides (check these for the most current steps/downloads, since
firmware and tooling change over time):
- MatrixPortal S3 overview & CircuitPython install: https://learn.adafruit.com/adafruit-matrixportal-s3
- CircuitPython download page for this board: https://circuitpython.org/board/adafruit_matrixportal_s3/
- Animated GIF Player guide (quickstart): https://learn.adafruit.com/animated-gif-player-for-matrix-portal/quickstart
- Factory reset / bootloader repair (if the board gets stuck): https://learn.adafruit.com/adafruit-matrixportal-s3/factory-reset

### Step 1 — Install CircuitPython (temporary, just to prep the drive)

1. Download the current `.uf2` file for the MatrixPortal S3 from the
   CircuitPython download page linked above.
2. Plug the board into your computer with a **known-good data/sync USB-C
   cable** (charge-only cables won't work).
3. Press the reset button once, wait for the NeoPixel to turn **purple**,
   then press reset again quickly. The NeoPixel should turn **green** and a
   drive called `MATRXS3BOOT` will appear.
   - If the NeoPixel turns red, or no `MATRXS3BOOT` drive appears, try a
     different cable/USB port, or see the Factory Reset guide linked above —
     some boards ship without the bootloader pre-installed.
4. Copy the CircuitPython `.uf2` file onto the `MATRXS3BOOT` drive. On macOS,
   Finder can fail on these "fake" virtual drives with errors like *"not
   enough free space"* or *"device disappeared"* — these are usually false
   alarms. If Finder gives you trouble, copy via Terminal instead:
   ```bash
   cp -X path/to/circuitpython.uf2 /Volumes/MATRXS3BOOT/
   ```
5. The board will reboot on its own once the copy finishes (it's normal for
   the drive to vanish mid-copy and for macOS to show an eject/error dialog —
   ignore it). A new drive called `CIRCUITPY` should appear.

### Step 2 — Create the gifs folder and load your GIF

1. On the `CIRCUITPY` drive, create a folder named exactly `gifs`.
2. Copy `output-gif/fire_animation.gif` into that `gifs` folder.
3. Do this step **before** flashing the GIF player firmware (Step 3) —
   copying GIFs while the GIF player is already running can occasionally
   corrupt or clear the drive.

### Step 3 — Flash the Animated GIF Player firmware

1. From the Animated GIF Player quickstart guide linked above, download the
   **precompiled `.uf2` file for the MatrixPortal S3**.
2. Re-enter bootloader mode the same way as Step 1 (double-press reset,
   NeoPixel purple → green, `MATRXS3BOOT` reappears).
3. Copy the GIF player `.uf2` file onto `MATRXS3BOOT` (again, prefer
   `cp -X` in Terminal on macOS if Finder gives errors).
4. The board reboots into the GIF player firmware. Note: this firmware also
   presents a drive named `CIRCUITPY` (same name as plain CircuitPython), so
   the drive name alone doesn't confirm which one is running.

### Verifying which firmware is active

If you're unsure whether the GIF player actually flashed (vs. plain
CircuitPython still running), check over serial rather than relying on the
drive name:

```bash
ls /dev/tty.usbmodem*          # find the board's serial port
screen /dev/tty.usbmodem1101 115200   # connect (adjust port name)
```

- A CircuitPython `>>>` prompt or REPL banner → still running plain
  CircuitPython; the GIF player didn't flash yet.
- No Python prompt / different output → the GIF player firmware is active.

(Exit `screen` with `Ctrl+A` then `K`, then confirm with `Y`.)

### Troubleshooting notes

- **"Device disappeared" errors while copying a `.uf2` file are normal** —
  the board reboots the instant the copy finishes, which yanks the virtual
  drive out from under macOS. As long as `CIRCUITPY` (or the expected next
  drive) reappears afterward, the flash succeeded.
- **"Not enough free space" errors are usually a macOS Finder bug**, not an
  actual space issue, on these virtual bootloader drives. Use `cp -X` in
  Terminal instead of dragging in Finder.
- If the board ever gets stuck or unresponsive, it can't be permanently
  bricked — the ESP32-S3 has a built-in ROM bootloader that can't be erased,
  so a factory reset (see link above) can always recover it.
