# LED Matrix Animation - Faux Fireplace

This repo contains everything needed to build a fire animation with ambient
crackle audio, running on an [Adafruit MatrixPortal S3](https://www.adafruit.com/product/5778)
driving a [32x32 RGB LED Matrix Panel - 6mm pitch](https://www.adafruit.com/product/1484),
mounted inside a faux fireplace.

The project has three parts:
1. **Video → GIF** processing scripts (fire animation)
2. **Audio processing** scripts (looping ambient crackle sound)
3. **`code.py`** — the CircuitPython script that runs on the board, playing
   the GIF and audio together, driven by a dedicated 4A power supply

## Folder structure
```
led_project/
├── code.py                  ← runs on the MatrixPortal S3 (CircuitPython)
├── scripts/                 ← the ffmpeg scripts for video, run in order
├── source-video/            ← put your original input.mp4 here
├── working-video/           ← intermediate video files land here automatically
├── output-gif/              ← final animation.gif lands here
└── sound/
    ├── process_wav.sh       ← trims/converts a source audio file for playback
    └── *.wav / *.mp3        ← put your source ambient fire sound file(s) here
```

---

## Workflow: creating the GIF

1. Place your source video at `source-video/input.mp4`
2. From the `led_project/` root folder, run each script in order:

```bash
chmod +x scripts/*.sh
./scripts/01_crop_to_square.sh
./scripts/02_resize_32x32.sh
./scripts/03_color_grade.sh
./scripts/04_convert_to_gif.sh
```

3. Your final GIF will be at `output-gif/animation.gif`, ready to copy onto
   the MatrixPortal S3 (see below).

### Notes
- Step 3 defaults to 12 fps. At 15 seconds long, that's 180 frames total — a good
  balance of smoothness vs. file size for a 32x32 panel. If you want slightly
  smoother motion, open `scripts/03_convert_to_gif.sh` and change `FPS=12` to
  `FPS=15`, but check the resulting file size isn't ballooning too much.
- The GIF is set to loop infinitely (`-loop 0`).
- `working-video/` files are intermediate and safe to delete once you're happy
  with the final GIF in `output-gif/`.

---

## Workflow: creating the ambient audio

The fire crackle sound loops continuously in the background alongside the
animation, over I2S audio out from the MatrixPortal S3.

1. Place your source `.wav` or `.mp3` file in the `sound/` folder, alongside
   `process_wav.sh`.
2. Run the script from inside `sound/`:

```bash
cd sound
chmod +x process_wav.sh
./process_wav.sh
```

3. This produces `<original_name>_processed.wav` in the same folder — leave
   your original source file untouched, and copy the `_processed.wav` file
   onto the board (see below).

### What the script does
- Trims the first 2 seconds off the source (avoids clicks/pops or fade-ins
  common at the start of a recording).
- Keeps the next 20 seconds after that as the loop segment.
- Converts to **16-bit mono PCM @ 22050 Hz** — the exact format
  `audiocore.WaveFile` expects on the MatrixPortal S3. If you use a different
  sample rate or channel count, you must also update `SAMPLE_RATE` and
  `channel_count` in `code.py` to match, or playback will be pitched/sped up
  incorrectly.
- Trims a few trailing samples so the total sample count divides evenly into
  the audio buffer size (2048), which prevents an audible click/gap at the
  loop point.

### Notes
- Only the **first** `.wav`/`.mp3` source file found in `sound/` gets
  processed per run if you have multiple — check the script output to
  confirm which file was picked up.
- `code.py` automatically finds and plays whatever single `_processed.wav`
  (or any `.wav`) file exists in the board's `/sound/` folder — the filename
  itself doesn't need to be hardcoded anywhere.

---

## Workflow: preparing the MatrixPortal S3 and loading everything

This project runs on **CircuitPython** (not the Arduino-based Animated GIF
Player firmware) — `code.py` in this repo is a full custom script that
handles both the GIF animation and looping audio together.

Official references:
- MatrixPortal S3 overview & CircuitPython install: https://learn.adafruit.com/adafruit-matrixportal-s3
- CircuitPython download page for this board: https://circuitpython.org/board/adafruit_matrixportal_s3/

### Step 1 — Install/confirm CircuitPython is on the board

1. Plug the board into your computer with a known-good data/sync USB-C cable
   (charge-only cables won't work).
2. It should mount as a drive called `CIRCUITPY`. If not, follow the
   CircuitPython install guide linked above to flash it.

### Step 2 — Copy files onto the board

Copy the following onto the `CIRCUITPY` drive, preserving this structure:

```
CIRCUITPY/
├── code.py
├── gifs/
│   └── animation.gif          ← from output-gif/
└── sound/
    └── <name>_processed.wav   ← from sound/
```

- `code.py` **must** be at the root of the drive, spelled exactly `code.py`.
- The `gifs` and `sound` folder names must match exactly (lowercase) since
  `code.py` looks for them by these names.

### Step 3 — Watch it run

As soon as the file copy finishes, CircuitPython auto-reloads and runs
`code.py`. To confirm it's working correctly or debug problems, connect via
serial (e.g. the [Mu editor](https://codewith.mu/)) and watch for a
traceback — a clean run shows no output and the panel lights up with the
animation and audio.

---

## `code.py` overview

At a high level, `code.py`:
1. Initializes the 32x32 RGB matrix via `rgbmatrix`/`framebufferio`.
2. Opens `/gifs/animation.gif` and loops it frame-by-frame using `gifio`.
3. Dims each frame in software via `bitmaptools.alphablend()` against a
   black bitmap, controlled by the `BRIGHTNESS` constant (0.0–1.0), since
   the matrix hardware itself has no brightness control.
4. Sets up I2S audio output and loops whatever `.wav` file it finds in
   `/sound/` continuously in the background via `audiomixer`, at a volume
   set by the `FIRE_VOLUME` constant (0.0–1.0).

### Tuning to taste
- **`BRIGHTNESS`** (near the top of the animation setup) — lower for a
  darker, more ember-like glow; raise for a brighter flame. 0.4–0.6 gives a
  noticeably dimmer, warmer look than full brightness.
- **`FIRE_VOLUME`** (near the audio setup) — adjust ambient crackle loudness
  independent of brightness.

---

## Power wiring

The matrix panel and the MatrixPortal S3 are powered **separately**, from a
single 5V/4A wall supply split into two legs, rather than routing the
panel's power through the MatrixPortal's screw terminals. This avoids
current-limiting/brownout issues under load and keeps the two devices
electrically independent while still sharing one wall outlet.

```
5V/4A wall supply
        │
        ▼
  2.1mm DC Y-splitter (1 female-in, 2 male-out, 6A rated)
    │                              │
    ▼                              ▼
Female DC terminal block    2.1mm barrel-to-USB-C
adapter → bare wires →      adapter → USB-C port on
matrix panel's power        MatrixPortal S3
input
```

**Do not** connect the matrix panel's power to the MatrixPortal's screw
terminals — those terminals are wired directly to the USB-C rail, not a
separate input, and back-feeding them can cause brownouts or damage if a
USB cable is plugged in at the same time.

**Reminder:** only ever have one power source feeding the MatrixPortal's
USB-C port at a time. Unplug the wall supply's USB-C leg before connecting
a computer via USB to reprogram the board.

---

## Troubleshooting notes

- **`AttributeError: 'OnDiskGif' object has no attribute 'pixel_shader'`** —
  newer CircuitPython versions require manually building a
  `displayio.ColorConverter` rather than using a `.pixel_shader` property
  directly off the gif object. Already handled in `code.py`.
- **Hard fault / safe mode on boot** — usually means `display.refresh()` was
  called with an invalid argument (e.g. `target_frames_per_second=0`), or a
  `TileGrid` was built before the first gif frame was loaded via
  `next_frame()`. Both are already handled correctly in `code.py`; if you
  modify the script, keep the frame-load-before-TileGrid ordering intact.
- **`TypeError: unexpected keyword argument 'factor1'`** or
  **`ValueError: Bitmap size and bits per value must match`** — depending on
  CircuitPython version, `bitmaptools.alphablend()` may need the brightness
  factor passed positionally rather than as `factor1=`, and both bitmaps
  passed in must share the same bits-per-pixel format. Already handled in
  `code.py`.
- **Only reds/oranges show, no white/blue** — if this happens with the wall
  supply connected, check that the matrix panel's power leads are actually
  wired to the splitter/terminal block and not left disconnected — red LEDs
  have a lower forward voltage than blue/green, so a panel receiving only
  parasitic power through its data lines will often show dim reds only.