# Space Duel — disassembly

A complete, annotated disassembly of **Space Duel** (Atari, 1982),
covering the 6502 program ROM and the colour AVG vector ROM, plus the
tooling that generates both. Modelled on the
[Omega Race decompilation](https://github.com/tcottrill/Omega-Race-Full-Disassembly-and-C-Port)
and the
[Asteroids Deluxe disassembly](https://github.com/tcottrill/Asteroids-Deluxe-Full-Disassembly-and-C-Port).

The target is **rev 2** (MAME `spacduel`). See [Revisions](#revisions).

Everything here is generated. The listings are outputs, not sources —
edit the tools, then regenerate.

What sets this one apart: Atari's own source archive for the game
survives — published as
[historicalsource/space-duel](https://github.com/historicalsource/space-duel)
— under the internal project name **"ASTERIODS 2"** (module prefixes
`AS2`/`A2`; Owen Rubin and Richard Maurer), and its RT-11 link image is
the same program. `AST2RD.LDA` plus `A2SHIP.LDA` **byte-matches
the rev-2 ROM set** except for three things: the checksum byte at `$4000`
(`55` in rev 1, `42` in rev 2), the byte at `$454D` (`0E` → `19`, the
only real rev-2 code change), and 167 bytes of `$00` padding at
`$8F53-$8FF9` that the link image does not carry. So this is not blind
reverse engineering with names invented to taste — it is a
**transcription with a byte-exact oracle**. Every subroutine name,
variable name and instruction comment in the listings is Atari's own,
placed on the ROM by locking the assembler source's instruction stream
against the bytes.

The archive is not distributed here, and nothing needs it to read or
build the listings — the generated files are checked in. Tools that read
it expect a copy unzipped at `space-duel-main/` beside `disasm/` and
fail with a clear message when it is absent.

## The hardware, briefly

- **CPU:** 6502 at 1.512 MHz. One periodic **IRQ** every 6144 cycles
  (246.09 Hz); the main loop runs one frame per four interrupts, so the
  game frame rate is **61.5 Hz**. A 3 kHz clock bit on `In0` is the
  finer timebase.
- **Display:** Atari **Analog** Vector Generator, in colour. The CPU
  builds a display list in 2 KB of vector RAM at `$2000-$27FF`, which
  can call into 6 KB of vector ROM at `$2800-$3FFF`, and kicks the AVG
  by writing `VgGo` (`$0C80`); `VgReset` (`$0D80`) holds it in reset and
  `In0` bit 6 (`VgHalt`) reports when the list is finished.
- **Sound and options:** two POKEYs — `Pokey1` (`$1000`) for sound and
  the pot inputs, `Pokey2` (`$1400`) for sound and the option switches,
  which sit on that chip's pot lines.
- **Persistence:** an ER2055 EAROM — read at `$0A00`, control latch at
  `$0E80`, write window `$0F00-$0F3F` — for high scores, initials and
  bookkeeping.
- **Housekeeping:** watchdog at `$0D00`, IRQ acknowledge at `$0E00`,
  coin counters, start lamps and the cabinet flip latch at `$0C00`.
- **Inputs:** `In0` (`$0800`) carries the 3 kHz clock, AVG halt, the
  diagnostic step and self-test switches, slam and the coin switches;
  `In1` (`$0900-$0907`) is one switch per address.

## Memory map

From the memory-map block of `spaceduel_defines.asm`:

| range | contents |
|---|---|
| `0000-00FF` | page 0 — scratch and globals |
| `0100-01FF` | page 1 — the 6502 stack, and the EAROM/bookkeeping cells above it |
| `0200-03FF` | game RAM (1K of RAM in total) |
| `0800-0FFF` | I/O — inputs, EAROM, AVG control, watchdog, coin latch |
| `1000-13FF` | POKEY 1 — sound and pot inputs |
| `1400-17FF` | POKEY 2 — sound and option switches |
| `2000-27FF` | vector RAM (2K) — the display list the AVG reads |
| `2800-3FFF` | vector ROM (6K) — **two different data formats**, see below |
| `4000-8FFF` | program ROM (20K, five 4K ROMs) |
| `FFFA-FFFF` | vectors — the top program ROM is mirrored to `$FFFF` |

The I/O registers, from the same file:

| address | name | what |
|---|---|---|
| `0800` | `In0` | d7 3 kHz clock, d6 `VgHalt`, d5 diag step, d4 self-test (0 = on), d3 slam, d2-d0 coins |
| `0900-0907` | `In1` | controls, one switch per address |
| `0A00` | `EaromRead` | EAROM data read |
| `0C00` | `CoinCtrLamps` | coin counters, start lamps, cabinet flip |
| `0C80` | `VgGo` | write starts the AVG on the display list |
| `0D00` | `WdClear` | write kicks the watchdog |
| `0D80` | `VgReset` | write holds the AVG in reset |
| `0E00` | `IrqAck` | write acknowledges the IRQ |
| `0E80` | `EaromControl` | EAROM control latch |
| `0F00-0F3F` | `EaromWrite` | EAROM write |

### The ROM sockets

| part | socket | range | contents |
|---|---|---|---|
| 136006-106 | R7 | `2800-2FFF` | vector ROM — ship pictures |
| 136006-107 | N/P7 | `3000-3FFF` | vector ROM — AVG display lists |
| 136006-201 | R1 | `4000-4FFF` | program, rev 2 (`136006-101` in rev 1) |
| 136006-102 | N/P1 | `5000-5FFF` | program |
| 136006-103 | M1 | `6000-6FFF` | program |
| 136006-104 | K/L1 | `7000-7FFF` | program |
| 136006-105 | J1 | `8000-8FFF` | program; mirrored to `$FFFF`, supplies the vectors |

26,624 bytes in total.

### The one thing worth knowing before you read anything else

`$2800-$3FFF` is called the vector ROM, but its two halves are **two
different data formats and only one of them is AVG data**.

`$3000-$3FFF` is what the name suggests: AVG display lists, called from
vector RAM. `$2800-$2FFF` is not. It is a 34-entry pointer table
followed by 34 ship pictures stored as signed `(dy,dx)` two-byte
records, which the 6502 reads and expands into AVG vectors at run time.
Decoding that half as AVG words produces nonsense, and the two halves
are disassembled by different code paths in the tools for that reason.

## Listings (generated — do not hand-edit)

| file | contents |
|---|---|
| `spaceduel_program_rom.asm` | the program ROM `$4000-$8FFF` (20,480 bytes) as Ophis assembler source: `.include`s the defines, `.org $4000`, an `Lxxxx` address label on every line, Atari's own comments on the instructions they were written against. Every instruction is re-encoded and byte-compared against the ROM: **0 mismatches** |
| `spaceduel_vector_rom.asm` | the vector ROM `$2800-$3FFF` (6,144 bytes), split by data format: the 34-entry ship-picture pointer table and the 34 pictures as `.byte` (dy,dx) records, then the AVG display lists decoded opcode by opcode with every shape named. Read back and compared: **6,144 of 6,144 bytes, 0 mismatches** |
| `spaceduel_defines.asm` | the memory map as a standalone glossary: 280 aliases — the hardware registers with descriptive names, and every RAM cell under Atari's own identifier, recovered from the `.BLKB` declarations in `ASTRD2.MAC` and the equates in `AS2DEC.MAC`, each with a one-line description of what it holds (`var_docs.py`) |
| `vec_names.py` | 132 named vector objects with their vector and reference counts, 3 of which still carry a `SHAPE_xxxx` placeholder |
| `shapes_preview.html` | 186 shape canvases — every vector object drawn, the visual index for reviewing the vector ROM |

The program listing includes the defines; the vector listing is
self-contained.

Two encoding subtleties are preserved deliberately rather than smoothed
over. **18 program-ROM instructions** use the 3-byte absolute form for
an address that would fit in zero page; that is not interchangeable
(`zp,X` wraps inside page zero, `abs,X` does not) and an assembler picks
the short form, so those are emitted as raw `.byte` with the intended
mnemonic in the comment. In the vector ROM, 1,528 AVG entries round-trip
through the macro encodings exactly and **3 do not**; those three are
emitted as raw `.word`, again with the decoded meaning in the comment.

### The zero-page map was 9 bytes high

Worth knowing if you have an older copy of the listing. `rammap.py` walks
`ASTRD2.MAC` accumulating a location counter, and it used to count the
`.BYTE` and `.WORD` lines that sit *inside* `.MACRO` … `.ENDM` definition
bodies. A macro definition emits nothing where it is written, only where
it is called, and four such lines precede the page 0 declarations —
`ASTRD2.MAC` lines 187 and 190 in `VCTRSC`, 238 in `COLOR`, 260 in
`MULBLD`, 2+4+2+1 = 9 bytes. Every page 0 and page 1 variable therefore
landed 9 bytes too high: `VGBRIT` at `$09` instead of `$00`, `SCORE` at
`$43` instead of `$3A`, `OBJ` at `$A0` instead of `$97`. The page 2/3,
vector RAM and vector ROM sections open with their own `.=` origins and
were never affected, nor were the hardware equates.

The ROM itself is the check. `Add2WordsToVector` ($8EA5) stores through
`STA (VGLIST),Y` and carries with `INC` on the byte above, and the bytes
say `$01`/`$02`; `BIT $35 / BPL` guards thrust with Atari's own comment
`NO PICTURE OF THRUST DURING ATTRACT`, so `ATRACT` is `$35`. Both agree
with the hand-walked layout, at every one of the ~290 instruction sites
that reference a page 0 name from `ASTRD2.MAC`.

Two long-standing puzzles in the C port's notes dissolved with the fix:
the "3-byte live score staged under `INTRPT`/`SYNC`" is just `SCORE`, and
the `$DA/$DB/$DC` read as "`$DD/$DE/$DF` minus 3" is just `HSCORE-3`.
Names in the listing shifted accordingly; nothing about the decoded bytes
changed, and `verify.py` still reports 0 mismatches.

## Tools

| file | role |
|---|---|
| `gen_from_roms.py` | builds the 64K CPU address space from a ROM set and regenerates everything derived from it. ROMs are matched by part number and SHA-1, not by file name. `--listings` runs the whole chain; `--check` runs the independent assembler round trip |
| `paths.py` | where everything lives, resolved from the file itself so every tool runs from any directory |
| `image.py` | the authoritative memory image, plus the RT-11 `.LDA` link-image parser |
| `m6502.py` | complete legal-opcode 6502 tables, encoder and decoder |
| `trace.py` | recursive-descent tracer from RESET/IRQ/NMI — the cross-check on what is code |
| `macsrc.py` | line-level parser for Atari's MACRO-65 (DEC RT-11) sources |
| `rtexpr.py` | RT-11 expression evaluator: no operator precedence, strictly left to right, 6-character symbols |
| `mapper.py` | locks source lines onto ROM addresses, with the ROM as the oracle for every instruction |
| `locate.py` | finds the ROM address of each relocatable module's longest instruction run |
| `modules.py` | resolves the true link base of every relocatable module, then maps it |
| `layout.py` | pins a module's base by searching a window around the contiguity prediction |
| `solve_bases.py` | solves each module's link base definitively, rather than by fixed-point iteration that can settle on a preamble-sized error |
| `sweep_free.py` | anchor-free base sweep: pick the base that simply locks best, since an anchor taken from a repeated mnemonic run can itself be wrong |
| `build_map.py` | builds the consolidated source-line → ROM-address map for the whole game |
| `rammap.py` | recovers the RAM and zero-page variable layout by walking the source's `.BLKB` runs, skipping `.MACRO` bodies (see “The zero-page map was 9 bytes high” below) |
| `naming.py` | turns Atari's 6-character labels into descriptive names, from the `.SBTTL` prose where there is any |
| `encode.py` | encodes a 6502 instruction so every emitted line can be byte-checked |
| `emit.py` | emits the annotated program ROM in Ophis syntax; a line is written from the source mapping only when re-encoding reproduces the ROM bytes |
| `verify.py` | reads the emitted listing back, re-encodes each line at the address its label states, and compares against the ROM |
| `emit_ca65.py` | translates the Ophis listing to ca65 syntax for the third-party assembler check |
| `emit_defines.py` | emits `spaceduel_defines.asm` |
| `var_docs.py` | what each RAM variable is for — the prose the defines file carries as comments |
| `avg.py` | AVG decoder — 13-bit two's-complement deltas, `SCAL`, `STAT`, `JSRL`, verified against real interpreters |
| `vecmap.py` | maps Atari's own vector and picture labels onto vector-ROM addresses |
| `shippix.py` | ship pictures decoded and drawn exactly as `SHPDISPLAYS` draws them |
| `rom_names.py` | names vector shapes from the program ROM itself, with no source-walk drift |
| `vshapes.py` | resolves shapes to Atari's names, using the source walk for order only |
| `shapes.py` | resolves every shape to a name with its provenance recorded |
| `emit_vrom.py` | emits the byte-exact vector ROM listing, split by data format |
| `emit_shapes.py` | emits the vector-object listing, the name table and the shape preview |
| `flat.cfg` | the `ld65` configuration for the round-trip link |

## Regenerating

ROMs are not in the repository. Supply a MAME `spacduel` ROM set — a zip
or a directory of loose files — and run:

```bash
python gen_from_roms.py <path-to-your-rom-set> --listings
```

Add `--check` for the independent assembler round trip; it needs `ca65`
and `ld65` from [cc65](https://cc65.github.io/) on PATH, or
`--cc65 <bindir>`:

```bash
python gen_from_roms.py <path-to-your-rom-set> --listings --check
```

Every other tool takes `--roms DIR` or reads `$SD_ROMS`
(`gen_from_roms.py` takes the ROM location as its argument). The 64K image
is written to `build/`, which is not tracked. Steps that read Atari's
source archive are skipped with a message when it is absent, and the run
ends by listing any checked-in file it changed — regenerating reproduces
the tree byte for byte.

## Notes

| file | contents |
|---|---|
| [`NOTES.md`](NOTES.md) | the findings: MACRO-11/65 source facts, the module bases, coverage, the naming pass, the AVG sign convention and vector-object naming, the ship-picture draw model, the renderer defects, and the final verified state |
| [`../c_src/README.md`](../c_src/README.md) | the C port — the proof by translation. The listing was translated routine by routine and the result checked for byte-for-byte parity of RAM and vector RAM against a software oracle running the real ROM |

## Method

The listing is not a linear dump, and it is not a trace either. The ROM
is the oracle and Atari's source is the transcript: `mapper.py` walks a
source module's instruction stream and locks each line onto a ROM
address, checking at every step that the ROM decodes to the same
mnemonic. The ROM supplies the real instruction length, so the
zero-page-versus-absolute ambiguity that no source-only parse can settle
resolves itself.

`ASTRD2.MAC`'s absolute body is `.=4000`, so it maps directly, with no
base to solve: **5,065 of 5,065 instructions locked, 0 desyncs**. The
rest of the program is `.CSECT` modules that the linker placed, so each
one's base had to be found before its lines could be locked.

Those bases were initially derived by assuming the linker placed modules
contiguously. That assumption was wrong for three of them, and the
mapper hid it — `AS2TST`'s `POWERON` must land on the RESET vector
`$803F`, and the mapper's relock silently absorbed a 19-byte error and
reported a base of `$803F` when the true base is `$802C`, which the
initials table at `$802C-$803E` confirms byte for byte. Every base was
re-solved with an anchor-free sweep (`sweep_free.py`, `solve_bases.py`):
pick the base that locks best, with no anchor constraint, since an
anchor taken from a repeated mnemonic run can itself be wrong.

| module | base | lock |
|---|---|---|
| AST2RT | `$6EE5` | 141/141, 0 desyncs |
| AS2SAC | `$703C` | 54/54, 0 desyncs |
| AS2POK | `$7197` | 146/146, 0 desyncs |
| COIN65 | `$7425` | 118/206, 27 desyncs |
| A2NAME | `$7529` | 198/198, 1 desync |
| AS2MSG | `$7730` | 99/99, 0 desyncs |
| AS2TST | `$802C` | 614/614, 0 desyncs |
| A2IRQ | `$8639` | 132/132, 0 desyncs |
| A2EARO | `$8749` | 593/593, 0 desyncs |
| VGUTR2 | `$8E42` | 142/142, 0 desyncs |
| A2GOOF | `$8F43` | 10/10, 0 desyncs |

`A2IRQ`'s base is the IRQ vector itself, which is an independent
confirmation of the whole method. `COIN65`'s 27 desyncs are conditional
assembly: the module is gated on the options `AS2COI.MAC` sets
(`EMCTRS=3`, `COIN01=1`, `SLAM=0`, `BONADD=1`), so parts of it are
present in the source and absent from the ROM by design.

### Naming

Labels went from 1,272 to 1,412 defined, **1,249 of them with real
names**, and anonymous branch targets fell from 833 to 160. The sources,
in priority order:

1. `.SBTTL NAME-DESCRIPTION` prose — 75 routines, giving names like
   `DestructionDuringCollision`
2. the label's own inline comment, or the comment block directly above it
3. strict morpheme expansion of Atari's terse identifier: `DIFTBL` and
   `DIFTBH` become `DifficultyTableLo` and `DifficultyTableHi`
4. otherwise Atari's identifier, CamelCased and left alone

Expansion is deliberately strict — it fires only when the identifier
decomposes *completely* into known morphemes, because a half-guessed
name is worse than a faithful terse one. That is why `Updif3`, `Atari`,
`Creddis` and `Cubltr` keep Atari's own spelling.

Local labels (`10$`, `65$`) are scoped to the routine that contains
them: `AddPointsToScore_10`. That required keying labels by address
rather than by name — the same `10$` occurs in nearly every routine and
previously collided, which is exactly why those 833 branch targets had
been dropped.

### Coverage is closed

Source attribution stands at **85.1% — 17,437 of 20,480 program-ROM
bytes**. Of the instructions, 7,312 carry Atari's own comment, 310 were
recovered by tracing alone, and the remainder of the ROM is data.

The 3,043 unattributed bytes are not a backlog of undisassembled
routines: they are padding, tables and one stretch of code the archive
does not cover. Roughly 1,260 of them are zero padding, and the five
ranges below account for 3,011 of the 3,043:

| range | bytes | zero | what |
|---|---|---|---|
| `$7885-$802B` | 1,959 | 43% | `A2FILL` padding (807 bytes by design) plus AS2TST tables |
| `$6D5C-$6EE4` | 393 | 8% | the `MULTB` / `EXPIC` / `ROCKDAT` tables |
| `$8D33-$8E41` | 271 | 14% | unattributed code between A2EARO and VGUTR2, plus a trailing table |
| `$70C0-$7196` | 215 | 86% | inter-module padding |
| `$8F53-$8FFF` | 173 | 97% | tail padding and the CPU vectors |

Every one of the 26,624 bytes is emitted and byte-compared, whether it
is attributed to a source line or not.

## Claims here were checked rather than assumed

- **The listing assembles back to the ROM under a third-party
  assembler.** `gen_from_roms.py --check` translates the Ophis listing
  to ca65 syntax, assembles and links it against `flat.cfg`, and
  compares: **20,480 bytes, 0 mismatches**. That check earned its keep
  immediately — ca65 rejected the first attempt because seven symbols
  (`POKEY`, `POKEY2`, `EACTL`, `EAIN`, `INTACK`, `OUT1`, `STOPAD`) were
  referenced by the listing and never defined in the defines file. The
  project's own verifier had resolved them from a rebuilt symbol table
  rather than from the file, and so had never noticed. An independent
  tool catching what an in-house one cannot is the whole point of having
  one.
- **A module base that looked right was wrong by 19 bytes.** `AS2TST`
  reported `$803F` — the RESET vector, and therefore plausible — because
  the mapper's relock absorbed the error. The true base `$802C` is
  confirmed by the initials table at `$802C-$803E` matching the ROM byte
  for byte. That single case is what forced dropping the contiguity
  assumption for every module.
- **The AVG uses 13-bit two's complement, not the DVG's sign-magnitude.**
  Atari's own `VCTR` macro settles it: it emits `.WORD DY&^H1FFF`, and
  −510 stores as `$1E02`, which is two's complement and decodes under
  sign-magnitude as −3586. The real interpreters — AAE's `aae_avg.cpp`
  and MAME's `avgdvg.cpp` — use a two's-complement conversion
  throughout. The earlier sign-magnitude decoder produced a garbage
  magnitude for every negative delta, and **the byte-level 0-mismatch
  check never caught it**, because decode and re-encode shared the same
  wrong convention and were mutually inverse. Byte fidelity does not
  prove semantic fidelity; that is why the shape preview exists.
- **The `JSRL` tables at `$324A` (38 entries) and `$3458` (37) are the
  character set.** They follow `ASCVG.MAC`'s encoding exactly — 0 blank,
  1..10 the digits, 11..36 the letters — with the second table the
  180°-rotated set for the cocktail cabinet's second player. `$324A`
  carries one entry more because it ends with `HALF`, the ½ glyph, which
  the flipped table has no counterpart for. The hypothesis had once
  been withdrawn because the renders "were not letters"; the renderer
  was the broken instrument, and with the sign convention corrected the
  glyphs read as glyphs.
- **`$3F2A-$3FFF` is padding, not a shape.** `AS2ROM` pads with zeros up
  to `.=3FFF` and then the checksum byte `CKUM1` (`$25`, which the ROM
  confirms). `$0000` decodes as a valid `VCTR`, so a linear sweep
  invented a 53-vector object out of 213 bytes of nothing.
- **The ship-picture draw model comes from the runtime code, not from
  the picture data.** Two plausible models were falsified before
  `SHPDISPLAYS` (`ASTRD2.MAC` lines 6109-6190) settled it: fixed record
  counts per ship type from `SHPD2TABLE` (23 for `SHPA*`, 21 for
  `SHPB*`), all emitted lit, plus 4 thrust-flame records from
  `SHPD3TABLE` drawn only while thrusting, then the `SHPDI8` codicil
  masking the intensity of the first and last records. The `EE` and `BB`
  columns in the source are vestigial — the active `TWBYPIC` macro emits
  `.BYTE YY,XX` and discards brightness — so reading them as terminator
  and pen-up flags underdraws every ship.

## Revisions

The target is **rev 2** (MAME `spacduel`), and Atari's source archive
documents that same build to within two bytes. The archive's link image
(`AST2RD.LDA` plus `A2SHIP.LDA`) byte-matches the rev-2 ROM set apart
from the checksum byte at `$4000`, which reads `55` in rev 1 and `42` in
rev 2; the byte at `$454D`, `0E` in rev 1 and `19` in rev 2, which is
the only real code change between the revisions; and 167 bytes of `$00`
padding at `$8F53-$8FF9` that the link image does not carry. A single
changed instruction byte is close enough that the archive's names and
comments apply to rev 2 directly, with that byte identified where it
sits.

The revision lives in a single socket: `136006-201` at R1 is rev 2,
`136006-101` is rev 1. The other four program ROMs and both vector ROMs
are identical between them.

`ASTRD2.MAC` (7,584 lines) is the clean rev-1 source and is what the
tools read. `AST2RD.MAC` is disk-damaged from line 3116 onward — a
490-byte fragment repeats — and is not usable.
