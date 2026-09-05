# Space Duel — disassembly notes

The findings behind the listings: what the sources actually say, what had
to be worked out from the ROM, and which conclusions were reached only
after an earlier one had been falsified. See [`README.md`](README.md)
for what the files are and how to regenerate them.

## Source facts

Atari's archive is DEC MACRO-11/65 for RT-11, and several of its
conventions have to be honoured exactly or the source cannot be locked
onto the ROM at all.

- **Symbols are significant to 6 characters.** `NMCOMETS` == `NMCOMET`,
  `NMCOMINES` == `NMCOMIMES`, `NMSAUCERS` == `NMSAUCER`. These are not
  typos in the source; they are the same symbol.
- **Expressions have no operator precedence.** Evaluation is strictly
  left to right; `<...>` forces grouping.
- **Radix.** `.RADIX 16` is in force; a trailing `.` means the term is
  decimal; `^H` / `^D` / `^O` / `^B` override the radix per term.
- **DEC operand syntax.** `I,v` is immediate, `X,a` is `a,X`, `Y,a` is
  `a,Y`, `A,a` forces the absolute form and `Z,a` forces zero page.
  That last pair matters — see the 18 forced-absolute instructions in
  the README.
- **`LAL` / `LAH` / `LXL` / `LXH`** are `LDA`/`LDX` of the low or high
  byte of an address, built out of `.WORD` plus `.=.-1`, with
  `.ENABL M68` giving the big-endian order that makes picking the high
  byte work.
- **`HLL65F.MAC` structured macros.** `IFxx` emits a 2-byte conditional
  branch; `ELSE` emits a `JMP` (3 bytes) or a `Bcc` (2) depending on the
  condition; `THEN`, `ENDIF` and `ENDC` emit nothing.
- **`DNEGATE a,b`** expands to 7 instructions whose total length varies
  with whether its operands are zero page.
- **`.REPT 0 ... .ENDR`** is the block-comment idiom in these sources.
  Its body must be skipped rather than parsed; parsing it produced
  phantom "macros" named `THE` and `COIN`.
- **Conditional assembly.** `.IF` / `.IFF` / `.IFT` / `.IFTF` / `.IIF` /
  `.ENDC`, with the conditions `EQ`, `NE`, `GT`, `GE`, `LT`, `LE`, `DF`,
  `NDF`, `B`, `NB`, `IDN`, `DIF`.
- **`.CSECT` / `.PSECT`** restart the section's location counter at the
  module's link base.

`AST2RD.MAC` is disk-damaged from line 3116 onward — a 490-byte fragment
repeats. `ASTRD2.MAC` (7,584 lines) is the clean rev-1 source, and it is
what the tools read.

## Module bases

`ASTRD2.MAC`'s absolute body starts at `.=4000`, so it maps directly
onto the ROM with no base to solve: **5,065 of 5,065 instructions
locked, 0 desyncs**, covering `$4000-$6D5B`. Everything above that is
relocatable `.CSECT` modules the linker placed.

The first pass derived those bases by assuming the linker placed the
modules contiguously. That was wrong for three of them, and the mapper
concealed it. `AS2TST` was the tell: its `POWERON` label must land on
the RESET vector `$803F`, and the mapper's own relock silently absorbed
a 19-byte error, reporting a plausible-looking base of `$803F` when the
true base is `$802C` — confirmed by byte-matching the initials table at
`$802C-$803E`.

Every base was then re-solved by an anchor-free sweep: pick the base
that simply locks best (fewest desyncs, then most instructions), with no
anchor constraint at all, because an anchor derived from a repeated
mnemonic run can itself be wrong.

| module | base | lock | previously |
|---|---|---|---|
| AST2RT | `$6EE5` | 141/141, 0 desyncs | unchanged |
| AS2SAC | `$703C` | 54/54, 0 desyncs | unchanged |
| AS2POK | `$7197` | 146/146, 0 desyncs | `$70C0`, 146 desyncs |
| COIN65 | `$7425` | 118/206, 27 desyncs | 72 desyncs |
| A2NAME | `$7529` | 198/198, 1 desync | 14 desyncs |
| AS2MSG | `$7730` | 99/99, 0 desyncs | unchanged |
| AS2TST | `$802C` | 614/614, 0 desyncs | `$7885`, 614 desyncs |
| A2IRQ | `$8639` | 132/132, 0 desyncs | unchanged |
| A2EARO | `$8749` | 593/593, 0 desyncs | `$8747`, 1 desync |
| VGUTR2 | `$8E42` | 142/142, 0 desyncs | 34 desyncs |
| A2GOOF | `$8F43` | 10/10, 0 desyncs | unchanged |

`A2IRQ`'s solved base is exactly the IRQ vector — an independent
confirmation of the method, since nothing in the sweep knew about the
vector table.

`COIN65`'s 27 remaining desyncs are conditional assembly, not error: the
module is gated on the options `AS2COI.MAC` sets — `EMCTRS=3`,
`COIN01=1`, `SLAM=0`, `BONADD=1` — so parts of it exist in the source
and not in this ROM by design.

## Mapper features

The mapper locks source lines onto ROM addresses with the ROM as the
oracle: for each instruction line, the ROM at the current program
counter must decode to the same mnemonic, and the ROM supplies the real
instruction length, so zero-page-versus-absolute ambiguity resolves
itself rather than having to be guessed. What had to be added for the
lock to close:

- `.CSECT` / `.PSECT` restarting the section at the module's link base.
- `.REPT 0 ... .ENDR` skipped as a block comment rather than parsed.
- Full MACRO-11 conditional assembly, with the option values
  `AS2COI.MAC` supplies for `COIN65`.
- The DEC `Z,addr` operand prefix (forced zero page), alongside `A,addr`
  (forced absolute).

## Coverage

Source attribution stands at **85.1% — 17,437 of 20,480 program-ROM
bytes** (it was 76.0% before the base re-solve). Instructions carrying
Atari's own comment rose from 7,052 to **7,312**; instructions recovered
by tracing alone fell from 570 to **310**.

The remaining 3,043 unattributed bytes, roughly 1,260 of them zero
padding. The five ranges below account for 3,011 of the 3,043:

| range | bytes | zero | what |
|---|---|---|---|
| `$7885-$802B` | 1,959 | 43% | `A2FILL` padding (807 bytes by design) plus AS2TST tables |
| `$6D5C-$6EE4` | 393 | 8% | the `MULTB` / `EXPIC` / `ROCKDAT` tables |
| `$8D33-$8E41` | 271 | 14% | unattributed code between A2EARO and VGUTR2, plus a trailing table |
| `$70C0-$7196` | 215 | 86% | inter-module padding |
| `$8F53-$8FFF` | 173 | 97% | tail padding and the CPU vectors |

Unattributed does not mean unemitted: every byte of the 26,624 is
written out and byte-compared, whether a source line accounts for it or
not.

## Naming pass

Labels went from 1,272 to 1,412 defined, **1,249 of them with real
names**, and anonymous branch targets fell from 833 to 160. Those are
the pass's own counts, over every label it defined including the
routine-scoped local ones; the emitted listing carries **1,274** named
labels standing on their own line, above the `Lxxxx` address label that
every instruction gets.

Naming sources, in priority order:

1. `.SBTTL NAME-DESCRIPTION` prose — 75 routines, which is where a name
   like `DestructionDuringCollision` comes from
2. the label's own inline comment, or the comment block directly above it
3. strict morpheme expansion of Atari's terse identifier: `DIFTBL` and
   `DIFTBH` become `DifficultyTableLo` and `DifficultyTableHi`
4. otherwise Atari's identifier, CamelCased and left alone

Expansion is deliberately strict — it fires only when the identifier
decomposes **completely** into known morphemes. Partial matches are
refused, because a half-guessed name (`UPDIF3` → "Updateif3") is worse
than a faithful terse one. That is why `Updif3`, `Atari`, `Creddis` and
`Cubltr` keep Atari's own spelling.

Local labels (`10$`, `65$`) are scoped to the routine that contains
them: `AddPointsToScore_10`. That required keying labels by address
rather than by name — the same `10$` occurs in nearly every routine and
previously collided, which is why those 833 branch targets had been
dropped in the first place.

The listing was re-verified after the pass: **20,480 bytes, 0
mismatches**.

## Vector objects

### The AVG uses two's complement, and that was the root defect

The decoder originally read `VCTR` / `SVEC` deltas as **sign-magnitude**
— the older DVG convention, as used by Asteroids. The AVG uses **13-bit
two's complement**. Two independent proofs:

- Atari's own `VCTR` macro emits `.WORD DY&^H1FFF`. −510 stores as
  `$1E02`, which is two's complement; under sign-magnitude the same word
  decodes as −3586.
- The real interpreters agree: AAE's `aae_avg.cpp` and MAME's
  `avgdvg.cpp` both use a two's-complement conversion throughout.

Every negative delta in `$3000-$3FFF` had been decoding to a garbage
magnitude. **The byte-level "0 mismatches" verification never caught
it**, because decode and re-encode used the same wrong convention and
were therefore mutually inverse: the bytes round-tripped perfectly while
the human-readable values were nonsense. Byte fidelity does not prove
semantic fidelity, which is the whole argument for rendering the shapes
and looking at them.

### Other AVG semantics

- The opcode is `word >> 13`. `SCAL` is `STAT` with bit 12 set.
- `SCAL` scale is `((~w) & 0xFF)/256 / 2^((w >> 8) & 7)` — the linear
  part is **complemented**, which the first renderer ignored entirely.
- `z == 1` in the source's 0-7 intensity encoding means "use the
  `STAT`/`COLOR` intensity register" rather than a literal brightness.

### The character glyphs

The `JSRL` tables at `$324A` (38 entries, normal) and `$3458` (37,
flipped — the 180°-rotated set for the cocktail cabinet's second player)
**are** the character set, exactly as `ASCVG.MAC` describes it: 0 blank,
1..10 the digits `0`..`9`, 11..36 the letters `A`..`Z`. The normal table
has one entry more because slot 37 is `HALF`, the ½ glyph; the flipped
table stops at `Z` and has no flipped ½.

This was a true hypothesis that had been wrongly withdrawn, because the
renders "were not letters" — but the renderer was the broken instrument.
With two's complement in place, `A B C D E O 2 3 7` and the rest all
draw correctly, and the names are restored as `CHR_*` (normal) and
`CHRF_*` (flipped), verified by render rather than by argument.

### Ship pictures at `$2800-$2FFF`

This half of the vector ROM is **not AVG data**: a 34-entry pointer
table at `$2800`, then 34 pictures made of signed `(dy,dx)` two-byte
records. Atari's `TWBYPIC` macro emits `.BYTE YY,XX` and **discards
brightness**. Every record was byte-checked against the ROM; all 34
pictures verify. How they are actually drawn is a separate question, and
the data alone does not answer it — see below.

## Ship picture draw model

`SHPDISPLAYS` in `ASTRD2.MAC` (lines 6109-6190), with `CLRTHR` and the
`SHPDI8` codicil, is the authority. Three models were tried, and the
first two were falsified against the runtime code:

1. **All 27 stride records, all lit.** The main hull lines come out
   right, plus garbage drawn from the padding the pointer stride
   includes. The 54-byte pointer stride is not a record count; `CRPAGE`
   pads.
2. **Stop at the source's `EE` flag, treat `BB = 0` as pen-up.** This
   *underdraws*. The `EE` and `BB` columns in the source text are
   **vestigial** — the active `TWBYPIC` macro is plain `.BYTE YY,XX` and
   discards both.
3. **Correct: fixed record counts per ship type.** `SHPD2TABLE` gives
   23 records for the `SHPA*` pictures and 21 for `SHPB*`, all emitted
   lit (`SHPLUM = $20`, so `z = 1`, meaning the `COLOR` intensity
   register). Four thrust-flame records from `SHPD3TABLE` are appended,
   drawn white and only while thrusting. Then the `SHPDI8` codicil ANDs
   `#$1F` over the `z` bits of the **first** record (the centre-to-hull
   offset) and the **last** (the return leg), plus the flame bridge when
   thrusting. Net lit: `SHPA` records 1..21, `SHPB` records 1..19.
   `SHPD4TABLE` marks where `COLOR` black is inserted for a damaged
   ship.

## Vector-object naming

Every AVG shape is named from the ROM. The sources, strongest first:

1. **The glyph tables** at `$324A` (normal) and `$3458` (flipped), read
   with the `ASCVG.MAC` encoding — render-verified as real characters.
2. **Program-ROM immediates** read at verified addresses: the
   `LALJSR` / `LXHJSR` and `NAME8` / `NAME9` pairs, plus the 32-word
   `RSOURC` `JMPL` table at `$6E8D`, whose `ROCPIC` comments give
   Atari's own names for the obstacles.
3. **`JSRL` word tables the 6502 copies into vector RAM**, located
   structurally: `SAUCRC` at `$3E46` (4 entries → `SAUC0`..`SAUC3`) and
   `PLTLIV` at `$3E90` (→ `RHTSHP` / `LFTSHP`).
4. **`AS2ROM` source order**, last and weakest. The source walk tracks
   well enough to order the shapes but drifts by a few bytes over 4K, so
   any name surviving only from it is suffixed `?` in `vec_names.py`,
   and the label in the listing carries an `UNVERIFIED` note instead.

Making the ROM-derived sources take precedence over source order was not
cosmetic: the old source-order walk had mislabelled `$3848` as `SAUCRC`,
where the ROM proves it is `PENT01`. Unnamed shapes went from 35 to 3:
`$30AE`, `$37C8` and `$3808`, which keep `SHAPE_xxxx` placeholders.

### The phantom shape at `$3F2A-$3FFF`

There is no object there. `AS2ROM` pads with `.REPT` / `.BYTE 0` up to
`.=3FFF` and then emits the checksum byte `CKUM1` (`$25`, which matches
the ROM). `$0000` decodes as a perfectly valid `VCTR`, so a linear sweep
invented a 53-vector object out of 213 bytes of padding.

## Renderer defects found only by looking

None of these could be caught by a byte check; each was found by drawing
the shapes and seeing that they were wrong.

- **Sign-magnitude AVG decode** (the DVG convention) turned every
  negative delta into garbage and made the letters illegible. Fixed to
  two's complement per `aae_avg.cpp`. The byte verification never caught
  it, because decode and re-encode shared the same wrong convention.
- **Python `True` / `False` emitted into JavaScript** killed the whole
  preview script.
- **`int()` truncation of scaled coordinates**: `SHOT`, whose deltas are
  ±2 at `SCAL 1` (= ±0.996), collapsed to zero-length segments and
  rendered blank.
- **Default render scale 1.0 instead of the ambient `SCAL 1,$00`**
  (≈0.498), which drew the `1/2` glyph's slash at twice its true size.
- **Bounding boxes computed over dark moves as well as lit vectors**,
  squashing shapes into a corner.
- **`JSRL` not followed**, so composed shapes rendered as disconnected
  fragments.

Five shapes render blank and that is **correct** — every vector in them
has `z = 0`: `LIVEPAR` and `LIVUDPAR` (lives spacing), `CHR_SPACE` and
`CHRF_SPACE` (advance one character cell), and `WNDSE` (a clip window).
Both the listing and the preview label these, rather than leaving them
looking broken.

One question the data does not settle: `HALF` (`$32DA`, the `1/2` glyph)
contains two lit strokes — the bright slash (`zz=6`) and a connector
between the `1` and the `2` (`zz=1`, the same ambient-intensity code
every other glyph stroke uses). It is encoded lit and it renders lit;
whether Atari intended it to be visible is not decidable from the data.

## Verified state

| file | covers | verification |
|---|---|---|
| `spaceduel_defines.asm` | 281 hardware and RAM aliases | — |
| `spaceduel_program_rom.asm` | `$4000-$8FFF`, 20,480 bytes | own encoder **0 mismatches**; `ca65` + `ld65` **0 mismatches** |
| `spaceduel_vector_rom.asm` | `$2800-$3FFF`, 6,144 bytes | 1,528 AVG entries re-encoded exactly, 3 emitted as raw `.word` with the decoded meaning; read-back **6,144/6,144 bytes, 0 mismatches** |
| `vec_names.py` | 132 vector objects with vector and reference counts, 3 of them still `SHAPE_xxxx` placeholders | — |
| `shapes_preview.html` | 186 shape canvases | visually confirmed |

That is the complete 26,624-byte ROM set, every byte accounted for and
reproduced. Program ROM: 7,312 instructions carrying Atari's own
comments, 310 recovered by tracing, 1,274 named labels, source attribution
85.1%.

The **independent** check is the ca65 round trip:
`gen_from_roms.py --check` translates the Ophis listing to ca65 syntax,
assembles and links it against `flat.cfg`, and compares the 20,480-byte
result with the ROM. It is worth having precisely because it is not the
project's own encoder — it caught seven symbols (`POKEY`, `POKEY2`,
`EACTL`, `EAIN`, `INTACK`, `OUT1`, `STOPAD`) that the listing referenced
and the defines file never defined, which the in-house verifier had been
resolving from a rebuilt symbol table and so had never noticed.

The strongest check of all is not in this directory: the C port in
[`../c_src`](../c_src/README.md) translates the listing routine by
routine and reaches byte-for-byte parity of RAM and vector RAM against a
software oracle running the real ROM. A listing that assembles back to
the ROM proves the bytes; a translation that reproduces the machine's
state proves the meaning.
