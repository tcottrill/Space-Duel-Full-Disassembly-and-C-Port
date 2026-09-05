# display module notes (score headings, high-score table, initials entry,
object pictures, ship pictures, connecting rod, sparks)

Files: `display.c`, `display.h`, `display_data.c`/`.h` (generated - run
`py c_src/tools/gen_display_data.py` to regenerate from the 64K image,
`../disasm/build/spacduel_64k.bin`, built by `disasm/gen_from_roms.py`).

This file records a completion/verification pass over a module that was
already written almost to completion; "What was fixed this pass" below
lists what was actually wrong (very little) against what had been flagged
as still-to-do.

## How each screen element reaches the display list

- **Score headings + score/lives areas.** `initialize_score_headings()`
  ($4FF4) fills the whole $2300-$2350 block (PL0SET/PL1SET/CMBSET/CMSBSE)
  with RTSL bytes, then per area (0=player0, 1=player1, 2=combined, +an
  extra cocktail-only pass at 3) builds a fixed heading (JSRL $3EC2, flip
  flag into UPDOWN, STAT color from `Scrclr`, position VCTR, on cocktail a
  second "combined" message) followed by a JMPL into that area's *live*
  block ($2380/$23C0/$2780/$2736 - PL0ARE/PL1ARE/CMBARE/CMSBAR) where the
  actual score digits + lives glyphs will be redrawn every frame. Falls
  into `inselo()` ($50D5) which RTSL-fills the rock/saucer slot area
  $2290-$22FF and seeds the saucer color words. `display_parameters()`
  ($5CF2) is the per-frame updater: for whichever of PL0SCFLAG/PL1SCFLAG/
  CMBSCFLAG has bit 7 set, it repoints BLUE/EAC2 straight at that area's
  live block and calls `temp3_which_player0()` (Temp3WhichPlayer0, $5C24,
  static) to redraw the 3-BCD-pair score + phantom zero and, unless the
  area's flag bit 6 says lives live elsewhere, the row of remaining-ship
  glyphs. The combined area is built twice (normal + upside-down copy at
  CMSBAR) for the cocktail cabinet's flipped half.
- **High-score table + initials entry.** `scores()` ($6004) draws up to 2
  five-entry tables (SEC return = "still showing"); each row goes through
  `inita3()`/`entry_index_character0()`, the same glyph-JSRL machinery used
  by initials entry. `get_players_initials()` ($4DCD) drives the live
  initials-entry screen for both players via `getin6()`
  (draw 3 initials + rotary-stick letter stepping + button debounce);
  `display_an_initial()` draws either a glyph or (for a still-blank slot
  mid-entry) an underline cursor.
- **Object pictures.** `pictur()` ($5D6D) is the per-object dispatcher,
  called once per displayed object with `x` = object index (`XCOMP`) and
  the object's screen position staged in RED/CHAN2V, TWOPI/CHAN3V by
  `MotionUpdateRoutine` (objects.c, not yet written). It always emits the
  JSRL $30B6 + centered-position VCTR first, then classifies: exploding
  ships go to `ship_exploding_pictures()` (flash + drifting debris pieces
  seeded by `expset()`); exploding non-ships get a generic
  explosion-picture JSRL (special/"big" explosions use a different table
  and get their own color); rocks ($00-$10) get a SCAL + COLOR + picture
  JSRL, or during the attract "letters" gimmick a glyph instead; shots
  ($24+) fade via a life-counter-driven STAT and either the SPARKB JSRL
  (ship shots, white) or a fixed JSRL (saucer shots); ships ($21-$22) hand
  off to `display_ship_picture()`; saucers ($1F-$20) pick one of two
  pictures (intact SAUCRC, or color+JSRL+SPARKB when hit); killer mines
  ($19-$1E) pulse via INTEN; plain mines ($11-$18) pick grown-up (comet)
  vs small picture off the **$037E,X** per-object flag (see "wrong comment"
  below - this is NOT COMTYP).
- **Ships.** See the pipeline section below.
- **The connecting rod (rigid-pair games).** `drawrod()` ($62C6), called
  as a direct fallthrough from `display_ship_picture()` (no RTS between
  them in the ROM - the C mirrors that by simply calling `drawrod()` right
  after `shpdisplays()`), draws the yellow rod between the two ships once
  per frame (RODSTATUS gates "already drew it this frame"). While
  SPARKTIME is still counting down (someone just died) the rod visually
  shrinks (each axis scaled by `2*SPARKTIME/128` via
  `output_temp2_temp21`) with a crackle sound (`random_fuzz`, an
  as-yet-unwritten objects.c routine); at SPARKTIME==0 it stops the fuse
  sound, explodes the other ship, and hands off to `get_comet_to_go()`.
- **Fuse/rod sparks.** `spark2()` ($638F), every other frame (`ZP_44 & 1`,
  and only outside self-test), rebuilds the 4-spoke SPARKB slot ($22D0)
  directly in vector RAM by repointing BLUE/EAC2 there: each spoke's angle
  is re-randomized (POKEY RANDOM) when its 16-count phase wraps, and its
  length is `phase * sin/cos` via the trig pack, emitted as an
  out-and-back VCTR pair.
- **Shields.** Drawn as part of `display_ship_picture()` ($6259): a 2-word
  STAT (white if `$2E+x` bit 7 says the shield is up, using SHLDENG,X's
  high nibble; otherwise whatever intensity was already staged) followed
  by the JSRL to the SHIELD picture ($3EA0) - the shield ring is regular
  AVG data, unlike the ship itself.

## The ship-picture pipeline: code vs. the disassembly's documented model

`../disasm/NOTES.md` ("Ship picture draw model - SHPDISPLAYS is the
authority") documents model 3 as correct: fixed per-ship-type record counts
from SHPD2TABLE (23 records for SHPA*, 21 for SHPB*), every record emitted lit
(SHPLUM z=1 = "use the COLOR intensity register"), +4 thrust-flame records
drawn white only while thrusting, then a codicil that ANDs #$1F over the z
bits of the *first* record (centre-to-hull offset) and the *last* (return
leg) to force them dark, plus a flame-bridge dark/white toggle at the
thrust-start index.

**The code as translated agrees with this model in every particular** -
this pass re-verified it byte-for-byte against the listing rather than
taking the prior finding on faith:

- `shpdisplays()` loads the fixed counts from `dsp_rom_63F0`
  (CountWholeShipVectors $63D7/$63D8 = `{0x16,0x14}` = 22/20, so Fall's
  `WHITE=cnt` loop runs `cnt+1` times = 23/21 records - matches "SHPA
  records ... SHPB records" exactly) and only swaps in
  CountShipWithThrust ($63D9/$63DA = `{0x1A,0x18}` = 26/24, i.e. +4) when
  every one of the ROM's thrust gates holds (not attract, thrust switch
  down, not suspended-animation, flash phase, drone exception for ship 2).
- `fall()` collapses the four ROM branches Fall_10 / BothReflects88Cycle /
  Shpdi5_10 / NoReflects76Cycle into one loop keyed on two booleans
  (`neg_x`/`neg_y` from `$12` bits 7/6) - verified line-by-line against
  all four ROM bodies ($6444-$6529): the negate-or-not choice, the msb
  selection ($00/$1F for Y, $20/$3F for X - the $20 IS the SHPLUM z=1 bit)
  and the read order (Y byte first, then `INC POKRAN`, then X byte, then
  `INC POKRAN`) match in every combination. `AlsoUsedFromBelow` ($6553)
  is a bare RTS also reached externally from `SplitRockIntoFragments`
  (objects.c territory) via `BCS` - a ROM byte-space reuse trick, not a
  routine with a body; folding it as a plain `return y;` inside
  `routine_also_does_blanking()` reproduces it exactly and needs no
  separate C entry point (CONVENTIONS rule 1: no *code* is being skipped).
- `then_partially_damaged()` reproduces the codicil precisely, including
  the ROM quirk noted in its own comment: `POKRAN = y` (STY POKRAN) only
  happens on the `y >= 0x1E` path, which is the only path any real ship
  count reaches (23/21/27/25 records always overflow 0x1E long before the
  loop ends) - **and this quirk turns out to matter beyond graphics**: see
  the `explosion()` fix in "What was fixed", which depends on exactly this
  RAM store.
- `routine_also_does_blanking()` matches RoutineAlsoDoesBlanking's
  three-way branch (damage-spot black / thrust-start white / no-op)
  exactly, including the ROM's own fallthrough between the damage check
  and the thrust check.

No disagreement found between the code and the documented model. That
section of `../disasm/NOTES.md` can be read as settled and now
doubly-checked.

## Register protocols (public functions - see display.h for prototypes)

- `get_players_initials()`: no register in; returns C (1 = both players'
  initials entry finished, mainline restarts Start2). Mainline calls it
  with C already clear (ROM never branches into it with C set); `Getin2`
  ($4DD8), the shared RTS, is purely internal (only referenced by BNE/BMI
  inside this same call chain - confirmed no external JSR/JMP to it in the
  listing) and is not exposed separately.
- `inset2()` / `initialize_score_headings()` / `score_color_based_above()`:
  no args, no return; called from Pwron (mainline.c, boot path) and from
  each other in the ROM's fallthrough chain (Inset2 -> ScoreColorBasedAbove
  -> Inisou -> InitializeScoreHeadings -> Inselo), reproduced as explicit
  calls since C has no fallthrough between functions.
- `entparams()` / `display_parameters()`: no args, no return; called once
  per frame from the mainline's per-frame display-build sequence.
- `pictur(x)`: x = object index ($00-$2F) = XCOMP, which the caller must
  already have set (several internal reads use `XCOMP` directly rather
  than the parameter, exactly mirroring the ROM's `LDX XCOMP` reloads
  after calls that clobber X); RED/CHAN2V and TWOPI/CHAN3V must already
  hold the object's screen position. No return value.
- `cc_carry_set_displaying()`: no args; always returns 0 (C clear) - CLC/
  RTS, literally a stub in the ROM.
- `scores()`: no args; returns C (1 = a table is still being shown, 0 =
  done). Reads/writes SHHIGH, LASTG, ZP_45, TEMP2, XCOMP, FLSFLG etc.
- `amount_add_routine_limits(a)`: a = amount to add to the 16-bit
  LNGTIMER/$03BA game timer; saturates at $04xx by forcing LNGTIMER=$FF.
  No return.
- `display_ship_picture(x)` / `shpdisplays(x, y)`: x = object index
  ($21/$22), already staged in XCOMP by the caller; for `shpdisplays`, y =
  index into the $2800 picture-pointer table (angle-derived picture
  number*2 + ShipAddressOffsets). No return; both write directly into the
  list at the caller's current BLUE/EAC2 position. `display_ship_picture`
  falls into `drawrod()` exactly as the ROM does (no RTS between them).
- `drawrod()`: no args - reads XCOMP (must already be the rigid-pair
  ship's index) and RODSTATUS/SPARKTIME/LASTSW. No return.
- `spark2()`: no args, no return; internally repoints BLUE/EAC2 at SPARKB
  ($22D0) and leaves them there (matches the ROM - callers after Spark2
  must not assume the list pointer survived).

## Extern list (cross-module calls; plain externs per CONVENTIONS rule 1c -
this module does not `#include` other modules' headers, matching the
established pattern in `mainline.c`, which does the same even for modules
that are fully written and on disk)

```c
/* message layer (AS2MSG) - matches msgs.h exactly */
extern void mesgpos(uint8_t a, uint8_t x);
extern void vector_generator_message_processor(uint8_t y);
extern void brightness(uint8_t x, uint8_t y);
extern void pass_color(uint8_t a, uint8_t y);
extern void vector_message5(uint8_t y);
extern void aux_routine_add_offset(uint8_t x);

/* trig / multiply (lowones.h) - matches exactly */
extern uint8_t pi_angle0(uint8_t a);
extern uint8_t cos_sin_pi2(uint8_t a);
extern uint8_t output_temp2_temp21(uint8_t a);

/* sound.h - matches exactly (explosion's signature was wrong; fixed) */
extern void always_remains_same_both(void);
extern void explosion(uint8_t x_in, uint8_t y_in);
extern void inisou(void);

/* earom.h - matches exactly */
extern void transfer_high_scores_buffer(void);
extern void write_high_scores_initials(void);

/* objects.c / mainline.c - NOT yet stable per the orchestrator's
 * instructions; kept as plain externs even though mainline.c happens to
 * already exist on disk (it declares stop_fuse_sound/get_comet_to_go as
 * externs too - genuinely objects.c's, not implemented anywhere yet) */
extern void random_fuzz(void);          /* RandomFuzz $6B45 */
extern void stop_fuse_sound(void);      /* StopFuseSound $6B57 */
extern void get_comet_to_go(void);      /* GetCometToGo $468C */
extern void bigbang(void);              /* Bigbang $76CC - IS implemented
                                          * in mainline.c/mainline.h now,
                                          * void(void), matches already */
```

## What was fixed this pass

1. **UPDOWN/STAT ordering in `initialize_score_headings`** - a concern
   flagged earlier. Checked against the listing ($5037-$505A): the ROM
   does `STA UPDOWN` (L5047) *before* `JSR SetVectorGeneratorStatus`
   (L5050, the STAT-word emit). The code already had this order right
   (`UPDOWN = a;` then `set_vg_status(...)` at display.c's
   `initialize_score_headings`, heading label) - **no change was needed**;
   either it was already fixed, or the flagged concern didn't survive
   contact with the actual bytes. Verified, not assumed.
2. **Wrong comment in `pictur`** - genuine bug, fixed. The mines branch
   (Pictur_90, $5F29) reads `LDA $037E,X` to decide "grown up" (comet) vs.
   small picture; the old comment labelled this "(COMTYP area)". COMTYP is
   a *different* RAM array at $038F, indexed 0-7 by comet slot (see
   `GetCometToGo` $468C, `Frame0FrameOff` $69C5) - unrelated to $037E,X,
   which is a per-*object*-index comet flag set by `SbttlStcomet` ($53CC:
   `LDA #$80 / STA $037E,X`) and cleared by `Inco30` ($6C36) when an
   object is (re)seeded as a dwarf mine. Comment corrected; the code's
   behavior was already right (only the comment lied about which cell).
3. **`explosion()` signature/call-site mismatch** - found during this
   pass's cross-module extern audit, not one of the two originally-flagged
   items. `sound.h` (now on disk) declares
   `void explosion(uint8_t x_in, uint8_t y_in)` (the trigger stubs park
   the caller's live X/Y in TEMP5/TEMP6, an oracle-visible RAM effect -
   see NOTES_soundcoins.md), but display.c had `extern void
   explosion(void)` and called it bare. Traced the real values: at the
   `JSR Explosion` call inside `Drawrod` ($62F4), X is still XCOMP (loaded
   at $62D7 and never reloaded; `RandomFuzz`/`StopFuseSound` don't touch
   X), and **Y is exactly the value in `POKRAN`** - because
   `Shpdisplays`'s tail (`ThenPartiallyDamagedOtherwise`, $64AE) does
   `STY POKRAN` right before `LDY POKRAN; JMP AddY1ToVector`, and
   `AddY1ToVector`/`vg_advance_list` never touches Y (checked vgutil.c:
   `vg_advance()` only does arithmetic on `g.ram[0x01]`), so POKRAN keeps
   holding that Y all the way through `Drawrod`'s `vg_add2`/`RandomFuzz`/
   `StopFuseSound` calls (none of which write POKRAN) until the explosion
   call. Fixed to `explosion(x, POKRAN)` with a comment explaining the
   derivation, and the extern updated to match sound.h.

## Completeness check

Every mandated routine is present, either as a named function or as
legitimate ROM-internal control flow (verified against the listing for
external references before folding anything, per CONVENTIONS rule 1):
`get_players_initials`/`Getin2`, `inset2`, `initialize_score_headings`,
`score_color_based_above`, `entparams`, `display_parameters`, `pictur`,
`cc_carry_set_displaying`, `scores`, `amount_add_routine_limits`,
`display_ship_picture`, `drawrod`, `spark2`, `shpdisplays`, `fall`,
`BothReflects88Cycle`/`Shpdi5`/`NoReflects76Cycle` (all folded into
`fall()`), `then_partially_damaged` (ThenPartiallyDamagedOtherwise),
`routine_also_does_blanking` (RoutineAlsoDoesBlanking + AlsoUsedFromBelow).
display.c's 14 non-static functions match display.h's 14 prototypes
exactly, one-for-one. The file is not truncated (1178 lines, ends cleanly
after `spark2()`'s closing brace). display_data.c's tables were spot-
checked byte-for-byte against the listing (e.g. `dsp_rom_50A8` against
$50A8-$50D4, including the ScoreColorBasedAbove opcode bytes read as data
at $50C4,Y) and all match.

## Compile status

`cl /nologo /W4 /std:c11 /c display.c display_data.c` - clean, zero
warnings. (`.obj` files deleted after the check.)

## Open questions

1. The Y-register derivation for `explosion(x, POKRAN)` (see above) is
   correct for *this* call site only, traced by hand through the ROM plus
   vgutil.c/sound.c's actual bodies. If any future module also calls a
   sound.h trigger stub after a Shpdisplays/Fall picture build without an
   intervening POKRAN write, the same reasoning applies - but nothing
   guarantees it if the call graph changes; worth an oracle-diff check on
   TEMP6 specifically around ship deaths once app_loop/the harness can run
   this module end to end.
2. `random_fuzz`, `stop_fuse_sound`, `get_comet_to_go` are still only
   plain externs (objects.c not yet written); once it exists, verify their
   real signatures the same way `explosion`'s was caught wrong here -
   `random_fuzz()` in particular tail-calls into `sound.h`'s
   `fuse_plyr0/1(x_in, y_in)` internally (per the listing, $6B51/$6B54),
   so whatever X/Y is live when `random_fuzz()` is called in `drawrod()`
   (X = XCOMP, Y = POKRAN, same reasoning as `explosion`) will matter
   there too once objects.c defines it with real parameters.
3. No oracle/probe exists yet for this module (none was requested this
   pass - no harness or `tests/ref` scenario currently exercises display.c
   in isolation). CONVENTIONS rule 9 ("before claiming a module done: its
   probe must byte-diff clean") is therefore not yet satisfiable; this
   pass is a static/listing-level verification only.
