# Score module notes (UpdateHighScoreTable $6614, Display4Names $7529,
# AddPointsToScore $5F68 -> score.c/score.h)

Orphan routines that had no home module. Read with the listing open.
AddPointsToScore landed here afterwards (section 3a) as the answer to
this file's own open question 1.

## 1. Why they landed here

- **UpdateHighScoreTable ($6614)** sits physically in the object/rock
  address range (right after `SplitRockIntoFragments`), but its entire
  body is high-score-table maintenance: it compares the just-finished
  game's live score against the running table, shifts entries down,
  inserts the new score, and flags initials entry. It shares its RAM
  layout 1:1 with earom.c's `TransferHighScoresBuffer`/
  `CopyFromBufferBack` (same $00DD/$0119-based cells - see section 3), so
  it belongs with scoring, not with the rock-splitting code around it.
  No existing module claimed it (checked earom.h, display.h, msgs.h,
  lowones.h, mainline.h, sound.h, coins.h, objects.h) -> new score.c.
- **Display4Names ($7529)** is the labelled A2NAME module (initials/
  game-select display) mentioned in DESIGN.md's module table under
  score.c's row ("scoring, high score table, initials (A2NAME)"), so it
  belongs here directly - not a judgment call.
- They are independent of each other (different address regions, call
  different sub-systems) but share this one file per DESIGN.md's module
  map, which lists both under `score.c`.

## 2. UpdateHighScoreTable ($6614): register protocol and behaviour

No arguments; call site: `mainline.c` `chkst1()` ($439A), immediately
after `update_info_at_end()`. Reads `ZP_34` (game-select switch, 0-3) to
pick a path:

| game | live-score slot X | TEMP1 | SPFLG | note |
|---|---|---|---|---|
| 0 | 3 then 0 | 1 then 0 | $FF | checks LEFT player's score, then RIGHT's (both always run - see below) |
| 1 | 0 | 0 | $FF | RIGHT/solo score only |
| 2 | 6 | 0 | $00 | combined score; "special" second initials array active |
| 3 | 6 | 0 | $FF | combined score; not special |

`jmp_upda20(x)` (static, `UpdateUpdateHighScore` in the listing) does the
actual scan/insert. Register protocol as derived from its 3 call shapes
above: **in** `x` = which live-score slot to compare/insert (3/0/6),
`TEMP1` (0x10) and `SPFLG` (0x3EA) already staged by the caller as shown;
**out**: none (all effects are RAM stores + a possible `bigbang()` call).

**Control-flow note on the JSR/JMP mix**: the ROM calls `jmp_upda20` for
game 0's left check via `JSR` (pushes a return address into the middle of
`UpdateHighScoreTable_20`), then falls into the right check via `JMP`
(no push). If the left check finds a hit, its `JMP Bigbang` unwinds
through the *left check's* pushed return address, landing back in
`UpdateHighScoreTable_20` - i.e. **the right check always runs
regardless of whether the left one hit**, and `Bigbang` can fire once or
twice for game 0. A straightforward pair of C calls
(`jmp_upda20(3); jmp_upda20(0);`) reproduces this exactly, because a
normal call/return in C is indistinguishable here from the ROM's
JMP-into-a-JSR-frame trick - nothing observable happens between the
`JMP Bigbang` and the eventual `RTS` in either version.

### 2a. The zero-page reuse this routine depends on

`UpdateUpdateHighScore`'s live-score compare and the "shift down" copy
read several bytes through names that have nothing to do with their
usual meaning - a real 6502 idiom (the disassembler substitutes whatever
symbol the address table has, regardless of the code's actual intent):

- **`$3A,X` / `INTRPT+X` ($3B,X) / `SYNC+X`($3C,X)`** - NOT interrupt/sync
  flags here. They are a 3-byte live score staged by the caller before
  `UpdateHighScoreTable` runs (X = 3/0/6 selects which of 3 staged
  scores). Nothing in the routines translated so far writes these bytes;
  the staging site is presumably in `chkst1()`/`Chkst1` (mainline.c,
  already translated - worth an orchestrator check that it does write
  $3A-$42 before calling `update_high_score_table()`) or a
  not-yet-identified predecessor. **Flagged as an open question below.**
- **`LANG`/`DIFF`/`SAUMIN`** ($DA/$DB/$DC) - read only as address
  arithmetic ("$DD/$DE/$DF minus 3") for the shift-down copy
  (`SCORE[y] = SCORE[y-3]`); their own named values are never actually
  read (y is always >= 3 within a slice in every reachable case).
  `score.c` uses raw `g.ram[0xDA+idx]` etc., not the macros, so the code
  doesn't imply a meaning that isn't there.
- The "special" second initials array (`$0137,X` written from `$0134,X`)
  is a genuinely separate 60-slot-indexed array that, because SPFLG is
  only ever $00 for game type 2 (X always 30-44 in that case), only ever
  touches bytes $155-$165 - which is exactly earom.c's "2 plr station,
  alt set" top-initials cell ($0155). Confirmed consistent with
  `NOTES_earom.md` section 4's live-cell map.
- `$03EC` (player-2 "forget it" cell) = `FLSFLG+1` ($3EB is `FLSFLG`,
  read/written via `,X` elsewhere in this same routine with X=0/1) -
  used here as a fixed address instead of indexed, so `score.c` writes
  `g.ram[A_FLSFLG + 1]` for clarity.
- `$36`/`$37` ("starting with first initial", per-player) have no name
  yet; accessed as raw `g.ram[0x36]`/`g.ram[0x37]` per CONVENTIONS 1c.

### 2b. Compare simplification (documented, not a behaviour change)

The `CMP`/`SBC`/`SBC` 3-byte magnitude compare (`$00DD,Y` vs the live
score) only has its final carry tested (`BCC`) - no other code reads N/Z/V
from it. `score.c` computes both sides as 24-bit unsigned integers and
compares them directly; this is bit-for-bit equivalent to the chained
compare/subtract-with-borrow (standard LSB-first multi-byte magnitude
comparison) and is not a case of "byte semantics" being dropped, since no
intermediate flag state is ever observed.

### 2c. Loop-exit collapse (documented, not a behaviour change)

The initials/score shift-down loop has two ROM exit tests: `CPX POTGO`
at the top (`_40`) and `BNE` (idx != 0) at the bottom (`_44`). Proven in
NOTES_score.md's derivation (not repeated here) that `idx` and `POTGO`
are always both multiples of 3 within the same game-type slice, so `idx`
always lands exactly on `POTGO` before or exactly when it would hit 0 -
the two exits are never actually different landing points. `score.c`
therefore uses a single top-tested `while (idx != y)` loop.

## 3. Display4Names ($7529): register protocol and behaviour

No arguments (confirmed against every call site in mainline.c: it does
`LDY #$03` on entry, so mainline.c already documents the caller's
carefully-computed Y as dead - see `mainline.c`'s comment at the call
site and `NOTES_mainline.md` open question 1). Draws up to 4 (2 for a
caberet cabinet) game-select boxes/pictures/messages, then falls into the
anonymous credit-display tail at $765D (kept inline in
`display_4_names()` - CONVENTIONS rule 1: not entered from anywhere else,
so not a separate function).

Reaches (and this file also implements, since neither existed anywhere
else):
- **HexBcdConversionInput ($8C62)**: binary -> BCD "double dabble". Its
  *other* call site is self-test ($8BA6, `AllStopPlease`'s bookkeeping-
  average display region, not yet translated). Exposed as a non-static
  `hex_bcd_conversion_input()` in `score.h` so the future `selftest.c`
  can extern it instead of duplicating it.

Does NOT reach anything else untranslated: `Mesgpos`, `PassColor`,
`VectorMessage5`, `AuxRoutineAddOffset` are msgs.c (already on disk);
`Add2WordsToVector`/`SetVectorGeneratorStatus`/`UpdownVectorUpsideDown`/
`DisplayDigitWithZero` are vgutil.c; `CABERE` reads go through
`sd_hw_in1(7)` per the existing `sd_hw_in1(7) & 0x40` idiom already used
in `mainline.c`/`display.c` for the same bit.

## 3a. AddPointsToScore ($5F68): register protocol and behaviour

Translated into `score.c` (it was the last TEMPORARY STUB that named
`score.c` as its home - `objects.c`'s extern already tagged it
`/* $5F68 (score module) */`). This is the routine that *stages* the live
3-byte score `UpdateHighScoreTable` reads at game end, so it closes
section 6's open question 1.

**Register protocol** (derived from all five ROM call sites plus the
existing `objects.c` extern):

| call site | routine | A | meaning |
|---|---|---|---|
| $450A | DestructionDuringCollision_30 | $10 | killer mine, 100 points |
| $466B | DestroyXShip_63 | $50 / $25 | full ship / crippled ship |
| $53DF | KillXSaucer | $30 | saucer |
| $6572 | SplitRockIntoFragments_3 | $20 | dwarf/mine class |
| $65AA | SplitRockIntoFragments_10 | table | `SplitRockIntoFragments_110,X` per new rock size |

**in** `a` = the BCD point value in tens ($10 = 100 points). The value
actually banked is `a + $CF - 1` in BCD - the points stepped up by the
current difficulty level, computed once and parked in TEMP5 ("BONUS
DISPLAY=DIFCTY LEVEL -1"). Also read, not passed: `OWNER` ($038E, the
scoring player, bit 7 = nobody -> immediate RTS) and `$35` (game active;
minus = in a game, so the whole routine is a no-op during attract).
**out** nothing. X is clobbered (it exits as OWNER on the per-player
bonus path and as the score slot 0/3 on the combined path); both ROM call
sites that still need X reload it from XCOMP/WHITE right afterwards, which
is what `objects.c`'s "X/Y here are AddPointsToScore's leftovers" comments
already record. Y is preserved - AddPointsToScore never touches it.

**Stores** (all oracle-visible, CONVENTIONS 1b): TEMP5, `PL0SCFLAG,OWNER`,
the live score `$3A,X`/`$3B,X`/`$3C,X` (X = 0 or 3), YTOP, `OPTN1,OWNER`,
`$47,OWNER`, CMBSCFLAG, the combined score `$40`/`$41`/`$42`, and `$47`/
`$48`. On the extra-life path it also reaches Badhab's TEMP5/TEMP6 parks
via the tail call (below).

### 3a.1 The zero-page reuse, again - and one new find

Same trap as section 2a: `$3A,X` / `INTRPT+X` / `SYNC+X` are the 3-byte
live score for slot X, not interrupt/sync flags. Slot 0 is the right/solo
player, slot 3 the left player, slot 6 the combined-game score.

**New**: the ROM writes slot 6 *absolutely*, not indexed, and the
disassembler labels those three bytes `EAWRIT` ($40), `UPDFLG` ($41) and
`$42`. Grepping the whole listing shows `EAWRIT` and `UPDFLG` appear
**nowhere else in the ROM** - they are pure symbol-table artifacts with no
EAROM meaning whatsoever, exactly like INTRPT/SYNC. `score.c` therefore
writes `g.ram[0x40]`/`g.ram[0x41]`/`g.ram[0x42]` rather than the macros,
per this file's own naming policy. (Worth knowing for anyone reading an
oracle diff: a $40-$42 delta during play is a *score* change, not EAROM
activity.)

By contrast `DIFF` ($DB) and `OPTN1` ($D9) **are** read as themselves here
- DIFF is the bonus-life score step (0 = bonus lives disabled) and
`OPTN1,X` is the player's next bonus threshold - so they keep their
macros. `$CF` (difficulty/wave level), `$47`/`$48` (lives per player) and
`$35` have no confirmed Atari names and stay raw hex, matching
`objects.c`/`mainline.c`.

### 3a.2 Decimal mode

Everything between the `SED` at $5F72 and the `CLD` at _80/_90 is BCD.
That includes the "cannot increment while in decimal" idiom the ROM uses
to propagate the carry (`LDA #$00 / ADC INTRPT,X` instead of `INC`), and
the `CLC / ADC DIFF` bonus-threshold steps. `CMP`, `INC` and `DEC` are
unaffected by the D flag and stay plain binary - notably the `CMP #$0A`
life limit and the `INC $47,X`.

This routine needed a decimal **SBC** (`SEC / SBC #$01`), which `sd_bcd.h`
did not have; `bcd_sbc()` was added there alongside `bcd_adc()`. It uses
Bruce Clark's canonical NMOS algorithm, and note the flag asymmetry:
decimal ADC's N comes off the pre-adjust high nibble (why `bcd_res.n`
exists at all), but decimal **SBC sets N/V/Z/C exactly as the binary
subtraction would**, so `bcd_sbc()` derives `.c`/`.n` from the binary
result. Nothing in AddPointsToScore reads either flag off the SBC - the
`SEC`/`CLC` around it discard the carry - but the helper is now correct
for whoever needs it next.

### 3a.3 Control flow

Two entry paths into the combined-score tail, reproduced with labelled
gotos in the same shape as the ROM:

- carry out of score byte 0 **and** `LASTSW` minus -> `_65` directly;
- no carry -> `_60`, which re-tests `LASTSW` and either falls into `_65`
  or exits at `_90`.

So the combined score is updated on **every** scoring event in a combined
game, while the per-player thousands bytes and the per-player bonus check
only run when the low byte carried. The per-player bonus path can only be
reached when `LASTSW` is *not* minus, i.e. the two bonus checks are
mutually exclusive - the combined game awards its bonus off `$41`
(combined thousands) against player 0's `OPTN1`, and gives *both* players
a life (`INC $47` and `INC $48`).

`AddPointsToScore_80` ends in `JMP ExtraLife2` - a tail call, so the sound
routine's RTS is this routine's; `score.c` calls `extra_life2()` and
returns.


## 4. Const data

`tools/gen_score_data.py`, byte-checked against the 64K image
`../disasm/build/spacduel_64k.bin`, built by `disasm/gen_from_roms.py`.

Two regions, 72 bytes total, both OK:

| region | addr | bytes | contents |
|---|---|---|---|
| 1 | $6156-$615E | 9 | FifthValueUpdateCheck (5) + Hscend (4) |
| 2 | $761E-$765C | 63 | Display4Names_100.._185 (10x4), Picadh (3), Mesg2 (4), Creddis (16) |

Region 2 is one combined array (`score_rom_761E`) rather than one array
per named sub-table because the ROM code deliberately overlaps them
(indexes past the end of one table land in the next): `Picadh,Y` at
Y=3 reads into `Mesg2[0]` (both happen to be $A8 - confirmed in the
extracted bytes); `$764E,Y`/`$7652,Y`/`$7656,X`/`$7659,X` are all reads
into the 16-byte `Creddis` blob at fixed +1/+5/+9/+12 offsets for
unrelated lookups. Indexing in `score.c` mirrors the ROM's own literal
address arithmetic (`score_rom_761E[(0x7649 + y) - 0x761E]`, etc.),
same style as `display.c`'s `dsp_rom_764E[(0x7652 + y) - 0x764E]`.

`display.c` independently extracted an overlapping slice of the same ROM
bytes as `dsp_rom_6152[0x0D]` (covers $6152-$615E, i.e. Scores_110 +
both tables region 1 needs) and `dsp_rom_764E[0x08]` (covers $764E-$7655,
a strict subset of what Display4Names needs - it doesn't reach the
offset-12 reads at $7659). `score.c` extracts its own copies rather than
sharing `display.c`'s tables, per CONVENTIONS 1c (each module owns its
listed files); this duplicates a small number of ROM bytes across two
generated files, which is expected and harmless (both are verified
against the same ROM image).

## 5. Externs (for the orchestrator's header consolidation)

`score.c` depends on:
- `bigbang()` - mainline.c (`Bigbang $76CC`, already implemented there;
  declared here as its own extern per CONVENTIONS 1c rather than
  including mainline.h).
- `mesgpos()`, `pass_color()`, `vector_message5()`,
  `aux_routine_add_offset()` - msgs.c (msgs.h already declares these with
  matching signatures; score.c redeclares them locally, matching how
  display.c does the same for its msgs.c calls).
- `set_vg_status()`, `vg_add2()`, `vg_vctr_dark()`, `display_digit_with_zero()`
  - vgutil.c (via vgutil.h).
- `sd_hw_in1(7)` - the CABERE cabinet-type switch (sd_hw.h).
- `extra_life2()` - sound.c (`ExtraLife2 $72E1`, the tail call ending
  `AddPointsToScore_80`; declared locally like the msgs.c calls above).

`score.c` also **added `bcd_sbc()` to the shared `sd_bcd.h`** - decimal
ADC was already there, decimal SBC was not, and AddPointsToScore needs one
(`SEC / SBC #$01` at $5F77). Purely additive; see section 3a.2 for why its
flag handling differs from `bcd_adc()`.

`score.h` exposes `update_high_score_table()`, `display_4_names()` (both
already wired as externs in `mainline.c`), `hex_bcd_conversion_input()`
(new consumer: the future self-test module) and `add_points_to_score()`
(consumer: `objects.c`, whose matching extern predates this file - the
orchestrator can now drop that local extern in favour of `score.h`).

## 6. Open questions

1. **RESOLVED AND TRANSLATED: the live 3-byte score at
   $3A/$3B(INTRPT)/$3C(SYNC)[+3/+6] is maintained by `AddPointsToScore`
   ($5F68)**, which now lives in this module - see section 3a. It runs
   throughout live play (called from `objects.c` whenever points are
   scored) and leaves the running total sitting in $3A-$42 for
   `UpdateHighScoreTable` to read at game end; `chkst1()` does *not* stage
   those bytes, confirming AddPointsToScore *is* the staging. Its
   TEMPORARY STUB (index 0) has been removed from
   `c_src/stubs_missing.c` (a staging file that no longer exists in the
   tree), which is down to eight stubs. Residual uncertainty, carried forward as
   question 1a below.
1a. **The caller's Y at `AddPointsToScore_80`'s `JMP ExtraLife2`.** The
   tail call reaches `Badhab` ($72FA), which parks the live 6502 X *and* Y
   in TEMP5/TEMP6 - both oracle-visible stores. X is exact (this routine
   computes it: OWNER on the per-player path, the score slot 0/3 on the
   combined path), but Y is whatever the caller left, and the
   `add_points_to_score(uint8_t a)` signature - fixed by `objects.c`'s
   existing extern and by A being the only real argument - cannot carry
   it. `score.c` passes 0 and flags it in the code, which is the same
   choice already made at every other cross-module sound trigger; this is
   the identical issue tracked as `NOTES_objects.md` open question 3 and
   `NOTES_soundcoins.md` open question 1, and it gets fixed for all of
   them at once if the orchestrator either threads Y through these
   signatures or masks $1C/$1D in the diff. Only reachable on a bonus-life
   frame, and never during attract.
2. **AllStopPlease ($8A1D, self-test/game-end summary screen)** calls
   `Averag` ($89B9, decimal division by repeated subtraction) and reuses
   `HexBcdConversionInput` a second time ($8BA6) - out of scope here
   (not reached by any of the three assigned routines: `UpdateInfoAtEnd`
   does not call `Averag`), but flagged for whichever module eventually
   owns self-test, so `hex_bcd_conversion_input()` gets reused instead
   of retranslated.
3. Display4Names' box-pic table (`Picadh`) is genuinely only 3 bytes
   long in the ROM; the 4th logical read (Y=3, only reachable when
   `($44&0x1C)>>2==3`) silently reads the first byte of the next table
   (`Mesg2[0]`). Both are $A8, so behaviour is unaffected, but this is a
   real ROM fact (not a translation bug) worth flagging since a naive
   per-table array in C would have needed an explicit bounds decision -
   the combined `score_rom_761E` array sidesteps the question entirely
   by reproducing the ROM's own contiguous layout.
