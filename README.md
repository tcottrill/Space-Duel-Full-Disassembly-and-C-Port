# Space Duel — disassembly and C port

An **AI-assisted disassembly of Space Duel** (Atari, 1982) and a
complete, playable **1:1 C port** of it — no emulation, no 6502 core at
runtime; the original program itself, translated one routine at a time.
The reverse engineering and the port were done together with an AI
assistant (Anthropic's Claude), with one rule enforced throughout:
**no invented data**. Every constant, table and branch traces to a ROM
address, every name is Atari's own identifier or a strict, documented
expansion of it, and every behavioural question was settled by running
the ROM, not by guessing.

What sets this one apart from a disassembly worked out from scratch:
Atari's source archive for this game survives, published as
[historicalsource/space-duel](https://github.com/historicalsource/space-duel)
under the internal project name **"ASTERIODS 2"**. Its RT-11 link image
byte-matches the rev-2 ROM set to within two bytes and a stretch of tail
padding, so this is not blind reverse engineering with names invented to
taste — it is a transcription with a byte-exact oracle. **Every
instruction comment in the listings is Atari's own, and every name is
either Atari's own identifier or a strict, documented expansion of
it**, placed on the ROM by locking the assembler source's instruction
stream against the bytes. A name comes from Atari's `.SBTTL` prose for
the routine (75 of them, giving names like
`DestructionDuringCollision`), or from the label's own inline comment,
or from a strict morpheme expansion of Atari's terse identifier
(`DIFTBL` → `DifficultyTableLo`), or it is Atari's identifier
CamelCased and left alone; expansion fires only when the identifier
decomposes completely, which is why `Updif3` and `Cubltr` keep Atari's
own spelling. 1,249 of the 1,412 labels carry a real name, and just 3
of the 132 vector objects still hold a `SHAPE_xxxx` placeholder. Source
attribution reaches **85.1% of the program ROM — 17,437 of its 20,480
bytes** — and 7,312 instructions carry the comment their author wrote
against them. Nothing was named to taste.

## What's in the repository

| where | what |
|-------|------|
| [`disasm/`](disasm/README.md) | the disassembly: the program ROM and the colour AVG vector ROM as plain assembler source that re-encodes to the ROM byte for byte, a defines file carrying the memory map and 280 named RAM cells and hardware registers, each with a line saying what it holds, a shape preview that draws every vector object, and the tools that generate all of it from a ROM set |
| [`c_src/`](c_src/README.md) | the C port: the whole 6502 program as C11, real AVG words built in a modelled 2 KB vector RAM, two real POKEYs and a real ER2055 EAROM behind the hardware seam, a Windows host (OpenGL beam renderer, XAudio2 sound, keyboard/joystick, persistent high scores, the cabinet self-test) and a headless host for the differential probes. Builds with VS2022, no external SDK |

Each of the two directories has its own README with the detail.

Not included, but referred to: **Atari's own source archive** for this
game — the MACRO-65 sources and the RT-11 link image, published at
[historicalsource/space-duel](https://github.com/historicalsource/space-duel).
Every name and comment in the listings was recovered from it, and the
recovered listings are checked in, so nothing here needs it to build or
regenerate. The tools that read it directly expect a copy unzipped at
`space-duel-main/` beside `disasm/`, and are skipped with a clear
message when it is absent.

## No ROMs included — bring your own

Atari's ROM images are not distributed here. The C port **builds and
runs without them** (the ROM-derived data it needs is checked in as
generated C files), but the disassembly tools and regenerating those
files read real ROM images.

Given a MAME `spacduel` ROM set, one script rebuilds everything
ROM-derived — the 64K working image, every listing, the C memory model
and the C ROM data:

```bash
cd disasm
python gen_from_roms.py <path-to-your-rom-directory-or-spacduel.zip> --listings
```

ROMs are matched by part number and SHA-1, not by file name, so a MAME
zip or a loose directory both work. Regenerating reproduces the
checked-in files byte for byte — with one caveat: the program and
vector-ROM listings, the defines and the shape names also need Atari's
source archive unzipped at `space-duel-main/` (not distributed here;
see the section above). Without it, `--listings` still rebuilds the 64K
image and the C generated files, and skips the listing steps with a
message. Add `--check` for the independent assembler round trip: the
listing is translated to ca65 syntax, assembled, linked and compared
against the ROM.

## Quick start

```bat
cd c_src
build_win.bat
sd_win.exe
```

Keys: Left/Right rotate, Ctrl fire, Up or Alt thrust, Space (or Shift,
or Down) shield, 5 coin, 1 START, 2 or 7 SELECT GAME, F2 the cabinet
self-test switch, ALT+ENTER fullscreen, Esc quit. Everything tunable —
frame pacing, vsync, the beam renderer's width, smoothing and phosphor,
the joystick deadzone, the POKEY volume and the sample switch — lives
in `sd_win.ini`, which the host writes beside the exe on the first run
with every key at its default. See
[`c_src/README.md`](c_src/README.md) for the rest, including the
headless host and the probes.

## The frame rate is 61.5 Hz, and what that means on a 60 Hz monitor

The board has no vertical blank. Its only clock is a periodic interrupt
every 6144 cycles of the 1.512 MHz CPU clock — 246.09 Hz — and the main
loop runs one frame per fourth interrupt, so the game frame rate is
**61.5 Hz**. That is what the port runs at by default (`[main]
fps_lock=0`). On a 60 Hz monitor that rate beats against the display:
one and a half frames a second have nowhere to go, so the picture
hitches on a regular cycle, and vsync can only trade the hitch for
tearing.

The fix the port offers is the one a slower crystal would give the real
board: `[main] fps_lock=60` stretches the interrupt period so **the
whole machine runs 2.48% slow** — game logic, rock speeds, POKEY pitch
and all — and every frame then lands on its own refresh. Pair it with
`vsync=1` for a picture that sits still. Nothing else changes; the
audio stream stays real-time because only the block size follows the
period. If you want the board's exact speed, keep 0 and accept the
beat, or use a display that can refresh at 61.5 Hz.

## The oracle is a program, not a board

`c_src/tools/oracle.py` runs the **real ROM image** on a complete
documented-opcode 6502 simulator whose interrupt is driven off a cycle
count, and snapshots the whole of RAM and vector RAM at every `VgGo` —
the moment the CPU hands its finished display list to the vector
generator. The C port is then run over the same recorded schedule of
switch changes and interrupts, and diffed against those dumps byte for
byte: **33 of 34 captured attract frames** identical over 600 frames,
and **256 of 256** across the three self-test scenarios. The
[Omega Race port](https://github.com/tcottrill/Omega-Race-Full-Disassembly-and-C-Port)
needed real hardware to do this; here the oracle is a script, and its
reference dumps are checked in as the evidence.

## The AVG is two's complement

The colour Analog Vector Generator on this board stores its 13-bit
deltas in **two's complement**, not the sign-magnitude convention its
black-and-white DVG cousin uses. Atari's own `VCTR` macro settles it —
it emits `.WORD DY&^H1FFF`, and −510 stores as `$1E02`, which is two's
complement and decodes under sign-magnitude as −3586 — and both real
interpreters, AAE's and MAME's, convert that way throughout. The
earlier sign-magnitude decoder produced a garbage magnitude for every
negative delta, and **the byte-level round-trip check never caught it**,
because decoding and re-encoding shared the same wrong convention and
were exactly mutually inverse. Byte fidelity is not semantic fidelity;
that is why the shape preview and the C port exist.

## Two POKEYs

Space Duel has two of them: `Pokey1` at `$1000` for sound and the pot
inputs, `Pokey2` at `$1400` for sound and the option switches, which
sit on that chip's pot lines — so the coin and difficulty settings are
read through the sound chip's pot scanner, and a sound driver that only
pretended to be a POKEY would not answer. The port runs both as real
chips, rendering each one every interrupt and streaming the mixed
result to XAudio2. `c_src/pokey.c` has no platform includes and is
shared unchanged with the
[Asteroids Deluxe port](https://github.com/tcottrill/Asteroids-Deluxe-Full-Disassembly-and-C-Port),
which is where it is developed and probed.

## Rev 2

The target is **rev 2** (MAME `spacduel`). The revision lives in a
single socket — `136006-201` at R1 is rev 2, `136006-101` is rev 1 —
and the archive's link image is the rev-1 build, differing from the
rev-2 ROMs at two bytes and a stretch of tail padding: the checksum at
`$4000`; `$454D`, which is the only real code change between the
revisions; and 167 `$00` bytes at `$8F53-$8FF9` that the link image
does not carry. A single
changed instruction byte is close enough that the archive's names and
comments apply to rev 2 directly, with that byte identified where it
sits. The listings, and the port translated from them, target rev 2.
See [`disasm/README.md#revisions`](disasm/README.md#revisions).

## Provenance and method

Trace the ROM from its hardware vectors with a control-flow-following
disassembler, so that what is code and what is data is derived rather
than assumed (the vector ROM's two halves are two different
data formats, and only one of them is AVG data). Recover the
names by locking the source archive's instruction sequences onto the
ROM, with the ROM as the oracle for every instruction: the ROM supplies
the real instruction length, so the zero-page-versus-absolute ambiguity
that no source-only parse can settle resolves itself. Translate one
routine at a time under the rules in
[`c_src/CONVENTIONS.md`](c_src/CONVENTIONS.md), against a memory model
generated from the same defines file the listings assemble against.
Verify each frame of the result against the oracle's dumps, and each
chip model against the chip's documented behaviour.

## License

The disassembly, the tools and the C port are released under the
**GNU General Public License, version 2 or later**, the same terms as
MAME (see [`LICENSE`](LICENSE)). Two files carry MAME's BSD-3-Clause
terms for the parts translated from MAME sources, and keep that
attribution in their headers: `c_src/pokey.c` (the POKEY's polynomial
counters, its RANDOM register and its SKCTL reset model, from
`pokey.cpp`) and `c_src/er2055.c` (from `er2055.cpp`). The rest of
`c_src/pokey.c` is translated from the AAE emulator's engine-free POKEY
core, and its pot scanner follows the Altirra Hardware Reference (Avery
Lee). The vendored framework files in
`c_src/platform/windows/` keep their own headers and their own terms.
The names and comments recovered from Atari's source archive remain
Atari's; the archive itself is not distributed here. Space Duel is a
trademark of its owner, and no ROM images are included.
