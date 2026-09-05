# Space Duel C port — platform layer notes

A record of the platform port as first made; `main_stub.c` named below has
since been replaced by `app_loop.c` and the tests' `color_wheel.c` (see
`NOTES_playable.md`).

Ported from the finished
[Omega Race port](https://github.com/tcottrill/Omega-Race-Full-Disassembly-and-C-Port).
This file records what was copied and what was adapted.

## Copied verbatim (vendored framework, `platform\windows\`)

These are byte-identical copies of Omega Race's vendored framework files
(they carry their own copyright headers; not ours to rewrite, compiled at
/W3 like the template):

`sys_gl.c/h`, `glew.c/h`, `wglew.h`, `log.c/h`, `vector_draw.c/h`,
`shader_util.h`, `colordefs.h`, `mat4.c/h`, `rawinput.c/h`, `mixer.c/h`,
`fileio.c/h`, `miniz.c/h`, `ini.c/h`, `joystick.c/h`, `framework.h`.

Note: `vector_draw.c` needed **no changes** for color — it was already a
color renderer (AAE heritage): `beam_add_line` takes an `rgb_t`, and
`beam_set_color_mode(1)` selects the additive blend + GL_MAX join path
built for color vector games. Omega Race ran it in mode 0 (B/W); Space
Duel runs it in mode 1.

## Adapted / new

- **`platform\sd_platform.h`** — the contract, from `omega_platform.h`:
  - same shapes: `plat_init/shutdown`, `plat_now_ms/sleep_ms`,
    `plat_nvram_read/write`, `plat_leds_out`, `plat_status_text`,
    `plat_sample_start/stop`.
  - video: `plat_video_line(x0,y0,x1,y1,int color,int lum)` — color 0..7,
    lum 0..15 (Omega's mono `z` replaced). Coordinates are the AVG screen
    window x 0..520, y 0..395, y up (from AAE `drv_spacduel`
    `AAE_DRIVER_SCREEN(1024,768, 0,520, 0,395)` in
    `aae/drivers/bwidow.cpp`).
  - input: `plat_inputs` for Space Duel — fire, thrust, shield,
    rotate_left/right, start1/2, game_select, coin1/2/3, test, diag_step,
    diag (F2 affordance), quit. No spinner.
  - DIPs: `plat_dsw_pokey1()/plat_dsw_pokey2()` (banks read through the
    POKEYs' ALLPOT lines).
  - audio: Omega's sample seam kept, plus (2026-09-03) `plat_audio_open/
    push/close`, the streamed-PCM seam the core pushes its rendered
    POKEY output through - the
    [Asteroids Deluxe port](https://github.com/tcottrill/Asteroids-Deluxe-Full-Disassembly-and-C-Port)'s
    contract. (The interim `plat_pokey_reg` raw-register hook is gone:
    the chips live in the core now, `pokey.c`.)
  - app hooks: `sd_app_init / sd_app_step / sd_app_exit` (Omega's
    `omega_app_*`), called by the Windows backend's WinMain. Implemented
    by `main_stub.c` for now, by `app_loop.c` later.
- **`platform\windows\plat_win.c`** — Omega's backend with: window class
  `SpaceDuelWin`, title "Space Duel C"; files `sd_win.ini` / `sd_win.log`
  / `sd_c.nv`; `beam_set_color_mode(1)`; beam projection
  `mat4_ortho(0..520, 0..395)`; the phosphor history now stores
  (color,lum) per segment and decays only the intensity (hue constant);
  spinner/mouse code removed; Space Duel key map (below); `plat_audio_*`
  over `mixer.c`'s stream voice (2026-09-03; before that `plat_pokey_reg`
  was a documented no-op); sample zip name `samples\spacduel.zip`
  (placeholder — no sample set exists); PH_SEGS raised 2048→4096.
  Everything else (DPI, fullscreen, WndProc, pacing sleep, QPC clock,
  NVRAM file I/O) is unchanged from Omega Race.
- **`platform\headless\plat_headless.c/h`** — same idea as Omega's, but
  implements the full `plat_*` contract (Omega's headless instead owned
  the game state and the `omega_hw_*` seam; Space Duel probes get the
  `sd_hw_*` seam from the harness itself, per `sd_hw.h`). Provides:
  injectable `hl_inputs` + DIP bytes, captured segment buffer
  (`hl_segs[]/hl_nsegs`, reset by `plat_video_begin`, `hl_frames` counts
  presents) plus optional hooks for lines/present/samples/POKEY writes,
  an in-memory NVRAM image, and a simulated clock (`hl_now_ms`;
  `plat_sleep_ms` advances it).
- **`main_stub.c`** (c_src root) — TEMPORARY. Implements the `sd_app_*`
  hooks over the platform contract only: ~60 fps schedule drawing a
  rotating color wheel (8 sectors × 16 luminance spokes), an RGBW border,
  an 8×4 color/luminance swatch grid, and one dot per color (zero-length
  segments). Left/Right arrows change the spin. Delete it when
  `app_loop.c` lands (it links in the same slot).
- **`build_win.bat`** — Omega's, minus the game modules: vendored files
  at /W3, `main_stub.c` + `plat_win.c` at /W4 /std:c11 (no `/wd4102`
  needed here), output `sd_win.exe`.

## Color mapping and its provenance

The AVG STAT word's low 3 bits are direct RGB enables. Provenance:
AAE's AVG transcription, `aae/vidhrdwr/aae_avg.cpp`
(Space Duel uses the plain `avg_start()` engine — checked in
`aae/drivers/bwidow.cpp`, `init_spacduel`):

- STAT (default engine path): `statz = (firstwd >> 4) & 0xf;`
  `color = firstwd & 0x7;`
- `draw_avg()`: `z = ((z & 0xf) << 4) | 0xf;`
  `avg_add_point(cx, cy, VECTOR_COLOR111(color), z);`
- `VECTOR_COLOR111` (`colordefs.h`, also vendored here):
  **bit2 = RED, bit1 = GREEN, bit0 = BLUE**, each 0x00 or 0xff.

So: 0 black, 1 blue, 2 green, 3 cyan, 4 red, 5 magenta, 6 yellow,
7 white — the `avg_rgb[8]` table in `plat_win.c`. Luminance maps to
beam intensity as `(lum << 4) | 0x0f` (0..255), matching AAE (and the
same shape Omega Race used for its DVG z). MAME's `avg_device` for the
bwidow/gravitar/spacduel board family agrees with this ordering.

DIP defaults returned by `plat_dsw_pokey1/2` (0x01 / 0x00) are the
MAME/AAE `input_ports_spacduel` factory settings (3 lives, normal,
English, bonus 10000; 1 coin 1 credit). Which byte answers which POKEY
read is core policy (`sd_hw.h`) — revisit when `app_loop.c` wires it.

## Key bindings (Windows backend)

| control | keys |
|---|---|
| rotate left / right | Left / Right arrows (or joystick left/right) |
| thrust | Up or Alt (joy button 2) |
| fire | Left Ctrl (joy button 1) |
| shield | Space, Down or Left Shift (joy button 3) |
| coin 1 / 2 / 3 | 5 / 6 / 8 (8 = utility line, our addition; joy button 8 coins) |
| start 1 / 2 | 1 / 2 (joy button 9 = start 1) |
| game select | 7 |
| self-test switch | 9 (F2 also asserts it, as in Omega Race) |
| diagnostic step | F1 (matches the MAME/AAE binding) |
| diagnostics (host affordance) | F2 |
| fullscreen | ALT+ENTER |
| quit | Esc |

## How to build

```bat
cd c_src
build_win.bat        — sd_win.exe (needs VS2022 Community, vcvars64 path
                       hardcoded as in the Omega Race template)
```

Verified 2026-08-26: builds with zero warnings (/W4 on our files, /W3 on
vendored), runs (GL 4.6 context, beam renderer up, clean shutdown —
`sd_win.log`). `plat_headless.c` compile-checked at /W4 clean.
First run writes `sd_win.ini` ([main] vsync, [vector] linewidth /
gain / line_smoothing / corner_strength / fire_point_size / phosphor_ms)
beside the exe.

## Left to the game layer (state at the time of the platform port)

- **app_loop.c**: the real core loop — machine time (246.09 Hz IRQ),
  input → IN0/IN1 byte mapping, the `sd_hw_*` seam over this platform
  contract, NVRAM (EAROM) serialization, frame pacing. When it lands,
  delete `main_stub.c` and add the game modules to `build_win.bat`.
- **avg.c**: the AVG walker that will feed `plat_video_line`; the
  0..520 × 0..395 window and the `(color,lum)` convention here were
  chosen to match its AAE source semantics.
- ~~**Audio wiring**~~: DONE 2026-09-03 - `pokey.c` (two chips in
  `app_loop.c`) rendered per IRQ and streamed through `plat_audio_push`
  to `mixer.c`'s XAudio2 stream voice; the sample path stays as an
  optional layer (`[sound] samples`).
- **Pacing fidelity**: `main_stub.c` runs a flat 60 fps; the real loop
  should free-run against the AVG busy model like Omega Race did
  (AAE runs this board at 45 fps nominal).
- `build_all.bat` (probes + headless harnesses) once the first probe
  exists.

## Resolution-independent beam width

The beam renderer (`vector_draw.c`, vendored) takes its width and AA
feather in DESIGN units - 520 AVG units across the letterboxed viewport -
so the old fixed `linewidth=2.0` + `line_smoothing=1.5` grew to ~7 px of
line at a 600-px-tall window ("lines too thick at low resolution",
reported 2026-08-30). `plat_win.c` now owns the conversion: in this
backend `[vector] linewidth` (default 2.5) means PIXELS AT THE DEFAULT
1024-WIDE WINDOW and scales in proportion with the picture from there
(`update_beam_width()`: design units = value * 520 / 1024), while
`line_smoothing` (default 1.25) is the AA feather in PHYSICAL PIXELS on
any screen (design units = value * 520 / viewport pixel width, redone on
every `WM_SIZE`) - a feather that scaled with the picture made fullscreen
look fully anti-aliased whatever the setting (reported the same day). A
first version held the width constant in physical pixels at any window
size; play testing showed that made lines look fatter windowed than
fullscreen, so proportional was chosen (2026-09-03), in all four ports
sharing this backend. No vendored file was modified - `beam_init` still
reads the same two keys as design units and applies them, and
`plat_win.c` re-reads them as pixels right after and overrides through
`beam_set_linewidth()` / `beam_set_smoothing()`.

Correction 2026-09-03: the first version of this put the pixel width in a
separate `linewidth_px` key that silently overrode `linewidth` and
`line_smoothing` - so editing `linewidth` in the ini did nothing, as
reported. The two keys the renderer already exposes are the knobs now, in
pixels; `linewidth_px` is ignored (delete it from an old `sd_win.ini`).
