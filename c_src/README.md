# Space Duel — C port

A faithful C11 translation of the game logic in
[`../disasm/spaceduel_program_rom.asm`](../disasm/spaceduel_program_rom.asm).

**Every routine is translated, and it plays in a window with sound and
persistent high scores.** The mainline and its frame loop, the object
engine and the enemies, scoring and the high-score table, the message
writer, the star field and the math pack, the POKEY script engine, the
coin logic, the 246 Hz interrupt, the EAROM, the display-list builders
and the cabinet self-test are all in, one C function per named routine,
with the ROM address on each. It is not an emulator: there is no 6502
core at runtime.

The display pipeline is the real one. The translated VG utilities
(`VGUTR2`, `$8E42`) write actual AVG words into a modelled 2 KB vector
RAM through the real zero-page list pointer, and `avg.c` — a C
transcription of the AVG state machine — walks that list, and the
vector ROM it calls into, and emits line segments. What reaches the
screen is what the beam drew. Two real POKEYs (`c012294.c`) stand behind
RANDOM, the option switches on their pot lines and all of the game's
audio; both chips are rendered every interrupt and streamed to the
window's audio device. Behind `$0A00`/`$0E80`/`$0F00` sits a real
ER2055 model (`er2055.c`), persisted as `sd_c.nv` beside the exe, so
high scores survive between runs. The cabinet self-test is the ROM's
own, on F2.

The listing being translated, the board's hardware and memory map, and
how the names and comments were recovered are all in
[`../disasm/README.md`](../disasm/README.md).

## Building and running

The game, in a window (Win32 + OpenGL beam renderer, XAudio2 sound):

```bat
build_win.bat
sd_win.exe
```

Needs Visual Studio 2022 (the scripts call its developer command
prompt); nothing else. The same script also builds
`tests\sd_selftest.exe`, the headless run of the same application loop,
and `tests\color_wheel.exe`, a standalone beam-renderer diagnostic.

Keys: Left/Right rotate, Ctrl fire, Up or Alt thrust, Space (or Shift,
or Down) shield, 5, 6 and 8 coin — the right, centre and left coin
mechs, on IN0 d0, d1 and d2 — 1 START,
2 or 7 SELECT GAME — the cabinet has one start button and a select
button, and the ROM steps through its four games with the latter. F2 is
the self-test switch as a toggle, like the real one: press to enter,
press again to leave, and holding it at launch gives the power-on
diagnostics. F1 is DIAG STEP, 9 holds the cabinet's own self-test
switch line, ALT+ENTER is fullscreen and Esc quits.

**Player 2's controls are not mapped.** The host reads one set of
controls, so IN1's player-2 addresses (`$0901`, `$0903`, and the
player-2 thrust bit of `$0905`) always read 0. Game 3 is the one in
which the ROM gives both ships to a single player through `$0900`, and
that game plays fully one-handed.

`sd_win.ini` sits beside the exe. The host writes it on the first run
with every key at its default, so there is nothing to set up; the keys
are:

| section | keys |
|---|---|
| `[main]` | `fps_lock` — 0 (the default) is the board's own 61.5 Hz; 60 underclocks the whole machine 2.48% so every frame lands on a 60 Hz panel (see the root README). `vsync` — 0 or 1. `dropped_frame_irqs` — a mainline pass that spends this many IRQ periods shows the cabinet's dropped frame: nothing drawn from the end of its draw to the next VGGO (black, or the fading afterglow if the phosphor is on); 7 (the default) is the ROM's own overrun pass, about seven times per attract sequence; 0 = never (NOTES_playable.md §2). `dropped_frame_hold_ms` — keeps that blank up longer, delaying the next frame; 0 (the default) is the tube's own timing |
| `[vector]` | the beam renderer: `linewidth` (beam width in pixels at the default 1024-wide window, scaling with the picture from there) and `line_smoothing` (the anti-alias feather, in physical pixels on any screen); `corner_strength` (the join disc's radius as a fraction of the half-width); `gain` (a constant added to each colour channel after the beam intensity — a brightness floor); `fire_point_size`; `phosphor_ms` (the afterglow's decay time constant; 0, the default, = off) |
| `[joystick]` | `deadzone` |
| `[sound]` | `pokey_volume` — the two POKEYs' streamed output, 0 to 100 percent, 0 = off. `samples` — 0 or 1, whether wavs in `samples\` play over the synthesised output |
| `[dips]` | both option-switch banks by name: `lives` (3/4/5/6), `difficulty` (easy/normal/medium/hard — the ROM's own four words), `language` (english/german/french/spanish), `bonus_life` (8000/10000/15000/none), `coinage` (2_coins_1_play/1_coin_1_play/1_coin_2_plays/free_play), `right_coin` and `center_coin` (the mech multipliers), `bonus_coins`. Defaults are the factory settings. An unknown word falls back to the default and the accepted spelling is written back |

A missing `sd_c.nv` just leaves the high-score table blank, same as a
fresh chip on the real board.

**No samples are shipped.** The two POKEYs synthesise every sound, and
any wav dropped into `samples\` plays on top of it;
[`samples/README.md`](samples/README.md) lists the names the code loads
and [`SOUNDS.md`](SOUNDS.md) is the full catalogue of what each one is.

## Verification

The probes are headless: the same translated modules, driven over a
hardware seam that replays the oracle's recorded switch and interrupt
schedule, byte-diffed against the oracle's dumps after every frame.

```bat
build_all.bat
tests\probe_attract.exe 600
tests\probe_selftest.exe 440 tests\ref_selftest
tests\probe_selftest.exe 180 tests\ref_selftest_exit
tests\probe_selftest.exe 260 tests\ref_selftest_boot
tests\probe_pokey.exe
tests\probe_er2055.exe
```

- `probe_attract 600` — 34 frames compared, **33 byte-identical**, 35
  mismatched bytes, all of them on frame 576.
- `probe_selftest` — **122 of 122**, **57 of 57** and **77 of 77**
  frames byte-identical over the three self-test scenarios: the
  bookkeeping screens and the options walk, the exit back to attract,
  and the cold boot with the switch already on.
- `probe_pokey` — every check passes, including the four polynomial
  counters at their maximal-length periods of 15, 31, 511 and 131071.
- `probe_er2055` — **0 failures**: five checks of the chip itself, then
  a round trip through the translated `A2EARO` state machine over it.

Frame 576's 35 bytes are one torpedo's Y velocity and position and the
33 bytes of ship and torpedo geometry that follow from them. `Fire3`
reads the launch angle twice, once per axis, and on that pass an
interrupt rewrote `SANGLE` between the two reads, so the ROM launched
that torpedo with two different angles while a probe that can only
synchronise at routine boundaries launched it with one. Closing that
needs a cycle-cost model in the port, which is a deliberate non-goal;
the difference is reported, never masked.

The window build's own seam is checked headless too, with a simulated
clock and scripted input:

```bat
tests\sd_selftest.exe 300
```

It runs the attract loop, the F2 toggle into the bookkeeping screen,
SELECT and START through the options, the software reset into the
power-on diagnostics, one press of DIAG STEP to advance a screen, the
return to attract, and an EAROM write that survives a reboot —
`SELFTEST: PASSED`.

The reference dumps the probes diff against are checked in under
`tests/`, as the evidence. They were made by running the real ROM image
under the oracle:

```bash
python tools/oracle.py attract --frames 600 --outdir tests/ref
```

and the same for the `play`, `selftest`, `selftest_exit` and
`selftest_boot` scenarios. Each run writes one `.ram` and one `.vram`
file per captured frame, `ref_index.json` — the captured-frame index,
carrying the interrupt count at every VGGO — and
`coverage_<scenario>.md`, the table of routines that run executed. The
scripted scenarios add `scenario.txt`, the input script, so a probe
replays exactly the switch changes the oracle applied rather than a
copy of them; `tests/ref`, the attract capture, has no input to script
and so has none. The directories a probe replays also carry
`vggo_sched.txt`, the per-pass VGGO schedule the probe synchronises on,
and the self-test ones an `irq_marks.txt` besides. The
oracle needs the ROM set (`--roms DIR`, `$SD_ROMS`, or a `roms`
directory at the repository root) or the 64K image that
`disasm/gen_from_roms.py` builds.

## What is here

| file | |
|---|---|
| `sd_state.h`, `sd_state.c` | the machine state: `sd_state g`, holding the real `ram[0x400]` and `vram[0x800]` |
| `sd_state_defs.h` | **generated** — every named RAM cell as a macro alias |
| `sd_hw.h` | the hardware seam translated code calls: IN0/IN1, the POKEY registers, the EAROM, VGGO/VGRST, the interrupt waits |
| `mainline.c` | `Poweron` (`$803F`) and the `Start2` frame loop |
| `vgutil.c` | `VGUTR2` (`$8E42`): the AVG word appenders, the digit and character writer, the long-vector builder |
| `avg.c` | the AVG state machine — walks vector RAM and vector ROM into line segments |
| `objects.c`, `display.c`, `score.c`, `sound.c`, `coins.c`, `earom.c`, `msgs.c`, `lowones.c`, `irq.c`, `selftest.c` | the game, one file per ROM module; `CONVENTIONS.md` has the map |
| `*_data.c/.h` | **generated** — each module's ROM tables, extracted from the 64K image by `tools/gen_*_data.py`, never hand-transcribed |
| `sd_progrom.c/.h`, `sd_vecrom.c/.h` | **generated** — the program ROM (`$4000-$8FFF`) and the vector ROM (`$2800-$3FFF`) as C data, so the port reads a table at its own ROM address |
| `sd_bcd.h` | the `SED` helpers |
| `c012294.c/.h` | the POKEY sound and RNG chip — hardware the ROM talks to, not a ROM routine; a cycle-stepped model shared byte-identical with the AAE and Atari 800 trees (`tests/build_c012294_ab.bat` is its A/B gate) |
| `er2055.c/.h` | the ER2055 EAROM behind `$0A00`/`$0E80`/`$0F00`, translated from MAME's `er2055.cpp`; byte-identical to the Asteroids Deluxe port's |
| `samples.c/.h` | optional wav playback over the synthesised sound |
| `app_loop.c` | the application loop: the `sd_hw_*` seam over the platform contract, machine time, both POKEYs, the EAROM's persistence, and one interrupt's worth of rendered audio per interrupt |
| `platform/sd_platform.h` | the platform contract |
| `platform/windows/` | the Windows backend: the OpenGL beam renderer, the XAudio2 mixer, raw input, joystick, ini and logging. The vendored framework files compile at `/W3`; the port's own code is `/W4 /std:c11` |
| `platform/headless/` | the quiet backend the probes and the headless self-test run on |
| `build_win.bat` | the window build, plus `tests\sd_selftest.exe` and `tests\color_wheel.exe` |
| `build_all.bat` | the probe builds |
| `tests/probe_*.c` | the differential probes and the two chip probes |
| `tests/avg_dump.c` | links only the AVG walker; dumps a display list |
| `tests/color_wheel.c` | a beam-renderer diagnostic, with no ROM and no display list |
| `tests/ref*`, `tests/sched/` | the oracle's reference dumps and the interrupt-mark schedule |
| `tools/` | `oracle.py`, `gen_state.py`, `gen_vecrom.py`, `gen_progrom.py`, the per-module `gen_*_data.py`, `avg_check.py`, and the two vector-timing-correction profilers `prof_pass.py` / `prof_fit.py` — observers over the oracle that measure what a mainline pass costs the 6502 |
| `CONVENTIONS.md` | **read this before adding code** |
| `DESIGN.md` | the architecture and the verification gates |
| `FINDINGS.md` | what the port proved, and what it turned up that the disassembly alone could not |
| `SOUNDS.md` | every distinct sound, the trigger code it answers to, and where the game fires it |
| `NOTES_avg.md` | the AVG pipeline: the flat memory map and the `JMPL` address fold |
| `NOTES_display.md` | score headings, the high-score table, initials entry, object and ship pictures, the connecting rod and the sparks |
| `NOTES_earom.md` | `A2EARO` (`$8747-$89B0`) and the boot-time EAROM sequence |
| `NOTES_integration.md` | the link and build wave, what the probe actually prints, and the evidence behind every remaining difference |
| `NOTES_lowones.md` | `AST2RT`: the math pack and the star service |
| `NOTES_mainline.md` | the boot sequence and the `Start2` frame loop |
| `NOTES_msgs.md` | `AS2MSG`, the message and text writer |
| `NOTES_objects.md` | the object table, the physics and the enemies |
| `NOTES_oracle.md` | the oracle's contract: what the port must reproduce bit for bit, and the rules the reference bytes were captured under |
| `NOTES_platform.md` | the platform layer as first made |
| `NOTES_playable.md` | the window build: the hardware seam, the pacing model (vector timing correction: the 6502's own time per pass, charged on top of the AVG draw time), and the numbers it delivers |
| `NOTES_score.md` | scoring, the high-score table and the name display |
| `NOTES_selftest.md` | `AS2TST`: the power-on diagnostics, the bookkeeping screens and the signature-analysis mode |
| `NOTES_soundcoins.md` | `AS2SAC`/`AS2POK`, the POKEY script engine, and `COIN65` |

## The memory model is generated, not typed

`tools/gen_state.py` builds `sd_state_defs.h` from the alias block of
[`../disasm/spaceduel_defines.asm`](../disasm/spaceduel_defines.asm) —
the same file the disassembly assembles against, whose names are
Atari's own. Every alias in `$0000-$03FF` becomes both an address
constant and an lvalue on the state array:

```c
#define A_SDELAY 0x026D
#define SDELAY   (g.ram[A_SDELAY])
```

so a renamed or relocated cell reaches the port by regenerating, not by
retyping. Vector-RAM and hardware aliases get their address constants
the same way. Regenerate with:

```bash
python tools/gen_state.py
```

That path was exercised in earnest once: the disassembly's page 0 and
page 1 names turned out to be 9 bytes too high (the last of the checked
claims under *Method* in [`../disasm/README.md`](../disasm/README.md)), so
every alias below `$0200` moved. The port was already reading the right
cells under the wrong names, so the migration was mechanical — rewrite
each identifier to whatever the corrected table calls **the same
address**, falling back to a plain `g.ram[0x..]` where nothing does.
Because an alias expands to a literal address, that rewrite has an exact
check: preprocess every translation unit before and after and compare the
token streams. All 28 came out identical, and both differential probes
held their baselines.

The state itself is deliberately raw — `g.ram[0x400]` and
`g.vram[0x800]`, the machine's own arrays, rather than a struct of
named fields (`DESIGN.md` argues the choice). That is what makes the
whole 1 KB of RAM and 2 KB of vector RAM diffable against the oracle
after every frame, and it lets the 6502's idioms translate literally:
indexed runs that span several symbols, `(zp),Y` pointer walks, and the
display list's own pointer all work unchanged against a flat array.

## Why the display list is modelled

The port builds real AVG words in `g.vram` instead of calling a draw
API, for the two reasons `CONVENTIONS.md` rule 4 gives. The shapes are
copied *and modified* on the way in — the ship pictures are not AVG
data at all but signed `(dy,dx)` records that the translated
`Shpdisplays` expands into vectors at run time, thrust flame and
intensity mask included — so an abstraction over shapes would have to
re-derive what the ROM already computes. And the generated vector RAM
is directly comparable with the oracle's dump of the real machine's,
which is the strongest test available here: the display list is where
almost every behavioural error eventually shows itself.
