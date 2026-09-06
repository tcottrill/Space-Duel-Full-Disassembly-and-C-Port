# Mainline notes (Poweron/boot + Start2 frame loop)

Covers `mainline.c`/`mainline.h`/`mainline_data.c`: Poweron $803F (game path),
StartThingsRunning $80AB, SetUpInitialsHigh $80D4, Pwron $68CA,
LswVectorAddress $6C96, the Start2 loop $4012-$4159 (re-entries
InitializePlayer1Start $400C / StartUpNewAsteroids $400F), CheckForStartEnd
$415A + Chkst1 $4357, Nxtstep $43A3, Gtoptn $76DB, Bigbang $76CC,
UsesTemp1Temp11 $68FD and its frame-modulo chain (Frame0FrameOff $6952 /
Frca30 $69E4 / Frame07f $6A1F / Frame0f $6A2E / Frame07 $6A46 / DoneAbove
$6A89), Onslaught $6AD1, QuickEndEndOnslaught $6B1C, CometCalculations
$6C65 + its anonymous entry L6C79 (`sub_6c79`), and Docoex $6CA8.

This records a completion/verification pass over a module that had already
been written once. Finding: **the file was already functionally complete** -
every mandated routine existed and every block checked line-by-line against
`spaceduel_program_rom.asm` matched. The only real defects found were a
stale `x` unused-variable warning in
`check_for_start_end()` (fixed - `x` was declared but never read anywhere in
that function) and extern group-header comments that had drifted out of date
against where routines actually ended up living (`inset2`/`spark2`/
`amount_add_routine_limits` are in `display.c`, not `objects.c` as originally
labeled - relabeled, no signature changes).

## Frame-loop model

`sd_mainline_frame()` is **one pass of the Start2 loop** ($4012 through the
next arrival back at Start2, StartUpNewAsteroids, or InitializePlayer1Start).
This is the only shape that satisfies the fixed signature contract
(`tests/probe_attract.c` calls exactly `sd_boot()` once and
`sd_mainline_frame()` once per displayed frame) while still reproducing the
ROM's control flow byte-for-byte.

The subtlety is the ROM's three re-entry points:

- `InitializePlayer1Start` ($400C, `JSR Initialization` then falls into
  StartUpNewAsteroids) - reached only via `L40B2: JMP InitializePlayer1Start`
  at the tail of `check_for_start_end()`'s "start pushed" path.
- `StartUpNewAsteroids` ($400F, `JSR NewastStartNewAsteroids` then falls into
  Start2) - reached from `L4154: JMP StartUpNewAsteroids` (Start2_76, "force
  next wave") and from `L68FA: JMP StartUpNewAsteroids` (the tail of `Pwron`,
  i.e. the boot path).
- `Start2` itself - the loop's own top, reached by plain fallthrough at the
  bottom of a pass (Start2_80) or by the early exits after
  `GetPlayersInitials`/`scores()`.

Both `InitializePlayer1Start` and `StartUpNewAsteroids` are trivial labels
(one JSR, then fall through) that ARE entered from multiple places, so
CONVENTIONS rule 1 would normally want them as their own named C functions.
They are deliberately **not** separate functions here: giving each an
independent entry would either (a) require sd_mainline_frame() to itself be
re-entrant mid-body, which the fixed void-void probe signature cannot
express, or (b) require a second public entry point, which the signature
contract forbids. Instead every call site inlines the same two calls
(`initialization(); newast_start_new_asteroids();` or just
`newast_start_new_asteroids();`) in tail position, immediately followed by
`return`- so the next call to `sd_mainline_frame()` begins exactly at Start2,
identical to the ROM falling through into L4012. The executed instruction
sequence is therefore identical to the ROM's; only the C call-graph shape
differs from a literal one-function-per-label translation. This is called
out at both the top of `mainline.c` and in `mainline.h`.

`Docoex` ($6CA8) is a bare `RTS` - the shared exit of four branches inside
`CometCalculations`/`L6C79` (BCS/BCS in `comet_calculations()`, BMI/BEQ in
`sub_6c79()`). It has zero side effects, so it is reproduced as a plain
`return;` at each of its four branch sites rather than as its own
zero-content function; this preserves the exact control-flow outcome (no
store happens) without an empty wrapper.

`sd_boot()` runs the Poweron game path (full RAM/vram/POKEY clear, output
latch + POKEY init, VG buffer seed, default initials) through
`StartThingsRunning` and `Pwron`, ending where `Start2` would begin - i.e.
after `sd_boot()` returns, the harness calls `sd_mainline_frame()` to run the
first pass. The self-test branch (`HALT` bit 4 clear at $8086/$4015) is an
early `return` in both `sd_boot()` and `sd_mainline_frame()`, documented as
unreachable while the harness holds IN0 d4 high (self-test off) - a real stub
belongs to `selftest.c`, a later phase.

## Boot sequence and wait counts

1. `sd_boot()` (Poweron $803F): SEI/stack-reset/CLD dropped as CPU artifacts.
   `sd_hw_vgreset()` (STOPAD), then a 256-iteration loop zeroing all of
   `ram[0..0xFF]`/`ram[0x100..0x1FF]`/`ram[0x200..0x2FF]`/`ram[0x300..0x3FF]`
   and all 8 vram pages plus both POKEY register files (each `STA` mirrored
   at X and X+0x100/0x200/... - the ROM's single `LDA #0/TAX` loop with 12
   stores per iteration is reproduced as 12 separate array writes per `i`).
   `STA WTCHDG` dropped each iteration. Then OUT1=$C0, POKEY SKCTL=$07 both
   chips, self-test branch check, VG buffer header seed (the dead $E4/$401
   JMPL - see DESIGN.md's resolved open question), UPDOWN = CABERE,
   `set_up_initials_high()`, `start_things_running()`.
2. `start_things_running()` (StartThingsRunning $80AB, static - only called
   from `sd_boot()`): CLI dropped (interrupts conceptually live from here;
   the harness services them at the seam wait calls). `LDX #$60` (96
   decimal) then a `DEX/BPL` loop around `sd_wait_frame_gate()` runs the
   body for X = 96, 95, ..., 0 inclusive - **97 passes** ($61 hex, since the
   body executes once more before the post-decrement BPL fails at X=$FF).
   Each pass consumes one $33 gate tick (~16.25 ms at the nominal 4
   IRQs/tick), matching NOTES_oracle.md section 4's "burns $61 ticks of $33
   ... (~1.58 s)" framing and the observed first-VGGO landing at IRQ 392.
   `for (x = 0x60;; x--) { sd_wait_frame_gate(); if (x == 0) break; }` in
   the C reproduces exactly these 97 passes. Then
   `read_everything()` kicks the async EAROM read, and a `while
   (g.ram[0x188] != 0) sd_hw_idle();` busy-poll (each `sd_hw_idle()` call =
   one IRQ tick) waits for the IRQ-driven `output_earom_erased_written()`
   state machine (runs every 16th IRQ, per NOTES_oracle.md) to finish
   filling the buffer. Then `copy_from_buffer_back()` conditionally (data-ok
   flag $187 bit 0 clear) and `copy_ontime_from_buffer()` unconditionally,
   then `pwron()`.
3. `pwron()` (Pwron $68CA - also the self-test-exit warm-start entry, JMPed
   to from $8C2F, so it must stay a globally-callable function, not
   `static`): stack/CLD dropped, `lsw_vector_address()`, `inset2()`, 3-byte
   score-flag reset ($3E1-$3E3 = $BF), `inisou()`, LASTG=1, $38/$39=$FF,
   SPFLG=$FF, STRTLOK=$80, CLI dropped, `display_parameters()`, then
   `newast_start_new_asteroids()` (StartUpNewAsteroids's body) and returns -
   the harness's next `sd_mainline_frame()` call is the first live Start2
   pass.

## sd_mainline_frame() register/carry protocols used internally

- `check_for_start_end()` returns the 6502 C flag as `int` (1 = start
  pushed, new game - the pass tail-calls `initialization()` +
  `newast_start_new_asteroids()` and returns without reaching the rest of
  Start2).
- `get_players_initials()` returns C as `int` (1 = entry finished this
  frame, mainline restarts at Start2 - i.e. `return;` immediately).
- `scores()` returns C as `int` (1 = doing the high-score table this frame,
  skip to Start2_60/`entparams()`).
- `nxtstep()` returns the new 6502 A (the new `$34` game index, halved only
  on the caberet LSR exit path - `$34` itself is always the real, unhalved
  game number; callers that need the game number read `ZP_34`, callers that
  need "the LSR'd value" use the return).
- `chkst1()` returns C as `int`, always 0 (kept `int`-returning for call-site
  symmetry with `check_for_start_end()`, which tail-calls it via `JMP`).

## Extern list required from other modules

Every signature below was checked against the real header on disk as of this
pass (msgs.h, sound.h, lowones.h, earom.h, display.h); three routines have no
implementing module yet (see Open questions).

From **display.c** (display.h confirms all of these):
```c
void inset2(void);                                  /* Inset2 $4FEE */
void spark2(void);                                   /* Spark2 $638F */
void amount_add_routine_limits(uint8_t a);            /* $67B6 */
int  get_players_initials(void);                      /* $4DCD, C flag */
int  scores(void);                                     /* $6004, C flag */
void score_color_based_above(void);                    /* $50C0 */
void entparams(void);                                  /* $5C80 */
void display_parameters(void);                         /* $5CF2 */
```

From **msgs.c** (msgs.h confirms all of these):
```c
void mesgpos(uint8_t a_dx, uint8_t x_dy);                        /* $7760 */
void vector_generator_message_processor(uint8_t y_msg);          /* $7770 */
void brightness(uint8_t x_color, uint8_t y_msg);                 /* $7772 */
void pass_color(uint8_t a_color, uint8_t y_msg);                 /* $7773 */
void aux_routine_add_offset(uint8_t x_row);                      /* $7730 */
```

From **sound.c** (sound.h confirms all of these):
```c
void inisou(void);                                      /* $73A8 */
void force_field_up(void);                              /* $73D4 */
void l2_saucers(void);                                  /* $7091 */
void gates(uint8_t x_in, uint8_t y_in);                 /* $72ED */
```

From **lowones.c** (lowones.h confirms):
```c
void do_low_ones_every(void);                           /* $6EE5 */
```

From **earom.c** (earom.h confirms these three; two more it should own -
`update_info_at_end`/`update_high_score_table` - do not exist yet, see Open
questions):
```c
void read_everything(void);                             /* $8777 */
void copy_from_buffer_back(void);                        /* $88B6 */
void copy_ontime_from_buffer(void);                       /* $89A3 */
```

From **objects.c** (not on disk at the time of this pass - written
concurrently; plain externs kept per CONVENTIONS rule 1c, signatures from
call-site register usage in the listing, not yet cross-checked against a
header):
```c
void initialization(void);                              /* $4F66 */
void newast_start_new_asteroids(void);                   /* $59C0 */
void fire_ships_torpedos(uint8_t x);                     /* $4C70, x=ship */
void move_ship(uint8_t x);                               /* $54A1, x=ship */
void killer_mines(void);                                 /* $4937 */
void motion_update_routine(void);                        /* $5174 */
void process_shields(void);                              /* $5BB9 */
void collision_detector(void);                           /* $43B7 */
void initiate_killer_mine(void);                         /* $672D */
void since_cannot_get_must(void);                        /* $6AA5 */
void stop_fuse_sound(void);                              /* $6B57 */
void get_comet_to_go(void);                              /* $468C */
void bells_wistles(void);                                /* $768D */
void inco10(uint8_t x, uint8_t y);                       /* $6B6D */
void acc_holds_angle_object(uint8_t x, uint8_t y);       /* $4956 */
uint8_t get_wrap_around_angle(uint8_t x, uint8_t y);     /* $48ED, returns A */
void klmi7(uint8_t a_angle);                             /* $4959 */
```

## Open questions

1. **Three routines have no implementing module anywhere on disk yet:**
   - `update_info_at_end()` (UpdateInfoAtEnd $893E) - lives in the EAROM
     address range ($87xx-$8Bxx, module A2EARO), calls
     `AddGameTimeSubroutime` and tail-JMPs into `RequestBookkeepingUpdate`
     ($8761, already in earom.h) at $8994. This is earom.c's routine to add,
     not mainline.c's - mainline.c only calls it from `chkst1()`.
   - `update_high_score_table()` (UpdateHighScoreTable $6614) - sits near
     `Scores` ($6004, already in display.c/display.h), so almost certainly
     belongs in display.c.
   - `display_4_names()` (Display4Names $7529) - sits between the score/
     display region and msgs.c's $7730 start; unclear which of display.c or
     msgs.c should own it. Its only oddity, already documented at the call
     site: it does `LDY #$03` on entry, which makes the caller's carefully
     computed Y (one/two-player message selection) provably dead at every
     call site in `check_for_start_end()` - the C port keeps computing it
     anyway (for `goto c47` fidelity/documentation) and casts it `(void)`.
   These three are declared as plain externs with correct signatures/
   addresses (verified against the listing) so mainline.c compiles now and
   links once a module supplies them.
2. **DoneAbove's `DEX/BPL` collision-latch loop and Bigbang's `DEX/BPL`
   object-clear loop both run X from a positive start down through 0
   inclusive** (2 and 48 iterations respectively) - reproduced as
   `for (x = N;; x--) { ...; if (x == 0) break; }`, matching the ROM's
   post-decrement `BPL` semantics (the body always runs once for x==0 before
   the loop test fails). No ambiguity found here, noted only because it is
   the idiom repeated ~15 times through this file and is easy to get off by
   one.
3. **`gates(0xFF, 0x01)` in `check_for_start_end()`'s
   CheckForStartEnd_7 path**: the comment asserts the live 6502 X/Y at that
   point are $FF/$01 (X from Bigbang's DEX/BPL exit at $FF, Y from "every
   path into CheckForStartEnd leaves the last VG-word appender's Y = 1").
   This was inherited from the earlier analysis and re-verified
   against the listing's register flow into `JSR Gates` at L4190 (nothing
   between `JSR Bigbang` and here touches X, and Y last comes from the
   Start2 buffer-select code `LDY EAC2`-adjacent VG appenders, which end at
   Y=1 per the `vg_add2` calling convention) - not independently re-derived
   from every possible caller of `check_for_start_end()`, since the mainline
   is its only caller and the mainline's own register history was traced.
   Flagged in case a future oracle diff on TEMPA/TEMPB disagrees.
4. **No probe/oracle diff was run in this pass** - the compile check is
   clean, but byte-for-byte parity against
   `tests/ref/` (CONVENTIONS rule 9) has not been re-verified here, since
   `objects.c` (a hard link-time dependency of `sd_mainline_frame()`) does
   not exist yet. That verification is blocked until objects.c lands.
