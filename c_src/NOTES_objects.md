# objects module notes (objects / physics / enemies)

Files: `objects.c`, `objects.h`, `objects_data.c` (generated - run
`py c_src/tools/gen_objects_data.py` to regenerate from the 64K image,
`../disasm/build/spacduel_64k.bin`, built by `disasm/gen_from_roms.py`;
246 of the 247 extracted bytes are cross-checked against the listing's
`.byte` lines, the 1 exception being the code byte the base-1 idiom at
`$5967` reaches).

ROM covered: **$43B7-$4CB4**, **$4F1C-$4FED**, **$50D5-$50F9**,
**$5154-$5C7F**, **$672C-$67AA**. This is the game proper - collisions,
killer mines, saucer entry and fire control, ship torpedoes, the per-frame
motion integrator, ship thrust/friction, the two-ship tug-of-war bar, wave
start-up and the shields. Attract mode plays a real demo game, so every one
of these runs on the oracle path.

## The object slot map (what the code proves)

48 slots, index `n` = `$00-$2F`. Five parallel arrays, all indexed by `n`:

| array | base | notes |
|---|---|---|
| status / picture | `$97` | `0` = free; positive = alive, and the value **is** the picture code; negative = an explosion/animation countdown that Moti20 counts up toward 0 |
| `OBJXL` / `OBJXH` | `$320` / `$2B5` | 16-bit X, high byte is the $00-$1F screen column |
| `OBJYL` / `OBJYH` | `$352` / `$2E7` | 16-bit Y, high byte $00-$17 |
| `XINC` / `YINC` | `$200` / `$232` | signed velocity |

The status base `$97` is what makes the `spaceduel_defines.asm` names line
up: `$97 + $19..$1E = $B0-$B5`, `+ $1F/$20 = $B6/$B7` (the saucer-active
cells `sound.c` already knows), `+ $21/$22 = $B8/$B9`, `+ $23 = $BA`.

| slots | contents | evidence |
|---|---|---|
| `$00` | the velocity seed for new rocks ("lowest rock") | `STY XINC / STY YINC` at $5A64 then `Newp2` reads `XINC,Y` with Y=0 |
| `$01-$10` | rocks / asteroids | `LDX #$10 ... STA $97,X` wipe at $5A57; NROCKS spawn loop |
| `$11-$18` | comets and dwarfs | `CPX #$11 / CPX #$19` splits everywhere; `EntryNoRequirementsExit` ORs `$A8-$AF` |
| `$19-$1E` | killer mines (6) | `KillerMines` `ADC #$19`; `InitiateKillerMine` scans `$B0,X` X=5..0 |
| `$1F-$20` | saucers 0 and 1 | `$B6,X`; `ClearSaucer_100` maps `$1F/$20 -> 0/1` |
| `$21-$22` | player ships 0 and 1 | `$B8,X`; `CheckShieldConditionPossibly` `TYA / SBC #$21` |
| `$23` | the connecting rod / pair centre | `CPX #$23` = "no picture for the bar, it comes with the ships" |
| `$24-$27` | player-0 mines; **also** the saucer torpedoes | `StartingValues`/`StoppingValues` = {$25,$27}/{$23,$25} |
| `$28-$2B` | player-0 torpedoes | `StartingSearchEmptyMine`+2 = $2B down to $27 |
| `$2C-$2F` | player-1 torpedoes | +3 = $2F down to $2B |

`CollisionDetector` scans "aggressors" X = `$2F` down to `$21` (it stops
*at* `$20`, so the saucers are never aggressors) and victims Y from a
per-object start index in `CollisionDetector_125` ($44AE, co-operative) or
`_126` ($44BF, competitive, when `$34 == 0`) down to 0.

Per-object secondary arrays met here (base + object index):

| base | meaning | ROM name at +$11 / +$19 / +$21 |
|---|---|---|
| `$0266` | current speed | CSPEED `$277` / KSPEED `$27F` |
| `$0274` | angle-change rate | CANGCH `$285` / KANGCH `$28D` |
| `$0282` | heading, high | CANGLH `$293` / KANGLH `$29B` |
| `$0294` | heading, low | CANGLL `$2A5` / KANGLL `$2AD` |
| `$037E` | comet type bits | COMTYP `$38F` (bit 0 = die at edge, bit 7 = is a comet) |
| `$03B0` (GTIME) | target object | CTARGET `$3C1` / KTARGET `$3C9` |
| `$00B0` | killer-mine hit count / colour | KLMINC `$C9-$CE` |
| `$0252` / `$0250` | shield energy hi/lo | SHLDENG `$273` / LSHLDENG `$275` |
| `$0369` | last thing bounced off | COLLIS `$38A` |
| `$0367` | partial damage | PRTDAMAGE `$388` |
| `$039A` | who shot | WHOSHOT `$3BB` |
| `$024C` | re-entry delay | SDELAY `$26D` |
| `$03C6` | entry-shield timer | ENTER `$3E7` |
| `$03CE` | explosion decoration | EXPDEC `$3EF` |

## Register protocols (derived from every call site)

X is essentially always an object index or a player number, so it is an
explicit parameter; several routines **return the 6502 X they leave
behind** because the ROM's next routine indexes with it.

| routine | ROM | in | out |
|---|---|---|---|
| `collision_detector` | $43B7 | - | - (X starts $2F internally) |
| `up_the_difficulty` | $46BE | OWNER ($38E) | - ; the PHA/PHA/RTS dispatch on `$34` became a `switch` |
| `get_comet_to_go` | $468C | - | - |
| `kill_x_saucer` | $53DB | x = saucer object | - |
| `get_wrap_around_angle` | $48ED | x = chaser, y = target | A = angle |
| `find_difference_coordinates` | $491F | x, y | A = angle |
| `killer_mines` | $4937 | x = the mainline's live X | **exit X** |
| `acc_holds_angle_object` | $4956 | x, y | exit X (tail call from the comet module $6C8D) |
| `klmi7` | $4959 | A = angle; **TEMP3 = the object** | exit X (tail call from $6C93) |
| `competitive_want_wait_other` | $49E9 | x | exit X |
| `scent5` | $4AA1 | a = target, x = saucer 0/1 | exit X |
| `reset_timers` / `hasent` | $4B5C/$4B5E | (TEMP1) / x = player | x |
| `enemy_fire_control` | $4B74 | a = `$44 & 3` (2/3), carry set | exit X |
| `fire_ships_torpedos` | $4C70 | x = ship 0/1 | - |
| `temp280_fast0` | $4CB5 | x = shooter, y = first slot; FOURPI = last slot; TEMP2 bit 7 = fast | - |
| `fire3` | $4CC0 | x = shooter (0/1 saucer, 2/3 ship), y = torpedo slot | - |
| `shpplace` | $4F1C | x = ship 0/1 | - |
| `initialization` | $4F66 | - | - ; falls into `inset2()` |
| `inselo` | $50D5 | - | - |
| `motion_update_routine` | $5174 | x = the live X from KillerMines | - |
| `moti20` | $51A9 | - | - |
| `sbttl_stcomet` | $53C7 | x = the rock/dwarf | - (leaves N = the new NWCSPD) |
| `wait_for_directed_enemies` | $53FD | y = the object to look for | **int = the 6502 Z flag** (1 = nothing aimed at it) |
| `move_ship` | $54A1 | x = ship 0/1 | - |
| `shipfriction` | $55C6 | x = ship, `carry` = the 6502 C on entry | - |
| `out_range` | $560D | a | a clamped to `-$40..+$3F` |
| `dorigid` | $57CE | - | - |
| `check_for_rocks_nearby` / `ship_dead_so_will` | $5916/$5918 | x = ship, y = top object | **A on exit = Y+1**; zero = the area is clear |
| `newp2` | $5977 | x = new rock, y = the velocity donor (always 0) | - |
| `newast_start_new_asteroids` | $59C0 | - | - |
| `reset_enemy_timers` | $5AC6 | - | - |
| `copy_attributes_of_rock` | $5B2B | x = dest, y = source | - |
| `new_random_velocity_using` | $5B5E | x = dest, y = source | - |
| `min_velocity` | $5BA1 | a | a, magnitude raised to the band minimum only |
| `process_shields` | $5BB9 | - | - |
| `twin_game_both_shields` | $5BE9 | x = player | **the 6502 Y** = the raw IN1 byte (bit 7 = pushed) |
| `game23_shields` | $5BFD | x = player | - |
| `temp3_which_player0` | $5C24 | a = zp address of the 3 score bytes; TEMP3 = area 0/1/2 | - |
| `initiate_killer_mine` | $672D | - | - |

Carry is threaded explicitly wherever the ROM reads a carry its own
routine did not set: `shipfriction(x, carry)` (it only reaches bit 0 of
TEMPA through `ROL TEMPA`, but that store is oracle-visible),
`enemy_fire_control(a, carry)`, and `twin_game1_player`'s `_60` test.

## POKEY RANDOM reads (the LFSR read-count contract)

In ROM order, this module reads RANDOM at exactly these 16 sites - 11 from
POKEY1 (`$100A`) and 5 from POKEY2 (`$140A`).  Verified both ways: the
listing has exactly 16 `$100A`/`$140A` references inside this module's
address ranges, and `objects.c` contains exactly 11
`sd_hw_pokey_random(0)` and 5 `sd_hw_pokey_random(1)` calls.

| ROM | which | routine |
|---|---|---|
| $4A8A | 0 | CompetitiveWantWaitOther_60 (saucer/comet choice) |
| $4AD0 | 1 | Scent5_6 (saucer picture) |
| $4AE3 | 1 | Scent5 (super-saucer coin flip) - **only when x == 0 and saucer 1 is idle** |
| $4B09 | 0 | Scent5_7 (entry Y position) |
| $4B80 | 0 | EnemyFireControl (vertical velocity) - only every 16th frame |
| $4C32 | 0 | Efire3 (aim fuzz) |
| $4C3A | 1 | Efire3_90 (`BIT $140A` - a read, sign only) |
| $4C74 | 0 | FireShipsTorpedos (the attract "fire button") |
| $4F1C, $4F36 | 0, 0 | Shpplace (re-entry X and Y) |
| $586C | 1 | Dorig3_55 (the attract thrust switch) |
| $599A | 0 | GetNewVelocity (which edge) |
| $5B5E, $5B71 | 0, 0 | NewRandomVelocityUsing (both axes) |
| $675D, $6763 | 0, 1 | InitiateKillerMine (start point) |

The short-circuit at `$4AE3` is written as a `&&` chain in `scent5()` in
the ROM's own order, so the read happens exactly when the ROM's
`BNE Scent5_3` chain reaches it.

## Externs this module imports (exact signatures)

From existing headers:

```c
/* vgutil.h  */ void vg_add2(uint8_t lo, uint8_t hi);
                void vg_add_rtsl(void);
                void save_input_parameters(uint8_t a_zp, uint8_t y_count, int carry);
                int  display_digit(uint8_t a);
/* lowones.h */ uint8_t comp(uint8_t a);
                uint8_t entry_input_exit_absolute(uint8_t a);
                uint8_t cos_sin_pi2(uint8_t a);
                uint8_t pi_angle0(uint8_t a);
                uint8_t output_temp2_temp21(uint8_t a);
                uint8_t signed_by_signed_mult(uint8_t a);
                uint8_t l80_random_wave0(uint8_t x, uint8_t y);
/* sound.h   */ void explosion / thrust_sound / reenter / reenter2 /
                     sh0sn / sh1sn / saucer_fire / player0_fire /
                     player1_fire (uint8_t x_in, uint8_t y_in);
/* sd_hw.h   */ uint8_t sd_hw_in1(uint8_t idx);
                uint8_t sd_hw_pokey_random(int which);
/* sd_vecrom.h */ const uint8_t sd_vecrom[0x1800];   /* Temp3WhichPlayer0 */
/* display.h */ void pictur(uint8_t x);
```

Declared locally in `objects.c` (label + address in the comment), for the
orchestrator to fold into headers:

```c
extern uint8_t part_signed_number_exit(uint8_t x, uint8_t y); /* $67D0 arctan:
                                     x = denominator, y = numerator -> A */
extern void split_rock_into_fragments(void);   /* $6554, reads FOURPI     */
extern void initialize_comet(void);            /* $6B68, reads TEMP1      */
extern void expset(uint8_t x);                 /* $623E                   */
extern void add_points_to_score(uint8_t a);    /* $5F68                   */
extern void gtoptn(void);                      /* $76DB (mainline.c)      */
extern void inset2(void);                      /* $4FEE (display.c)       */
```

### Interface fix-ups the orchestrator must make

1. **`display.c` defines `expset()` `static`** - it has to lose the
   `static` or the link fails. (`Expset` $623E is called from
   `DestroyXShip` $460C/$465D as well as from display.c.)
2. **`mainline.c`'s externs for two of my routines are stale.** It
   declares `void killer_mines(void)` / `void motion_update_routine(void)`;
   the faithful signatures are `uint8_t killer_mines(uint8_t x)` and
   `void motion_update_routine(uint8_t x)`, and the mainline must thread
   the value: `motion_update_routine(killer_mines(x))`, where `x` is the
   6502 X `QuickEndEndOnslaught` ($6B1C) left. See open question 1.
   Its `void klmi7(...)` / `void acc_holds_angle_object(...)` externs are
   harmless (a return value the caller ignores).
3. **`display.c` has private `static` copies of `inselo()` ($50D5) and
   `temp3_which_player0()` ($5C24)**, both of which were assigned to this
   module and are implemented here (non-static). No link conflict, but one
   of the two pairs should be deleted; keep whichever the orchestrator
   prefers and make the other module call it.
4. `display.c` calls `explosion()` with no arguments while `sound.h`
   declares `explosion(x_in, y_in)`. This module follows `sound.h`.

## Unnamed RAM cells used (all `g.ram[...]` with inline comments)

`$14`, `$16`, `$17` scratch (ThrustTwoShips / WillAssumeRadiusBar /
NewastStartNewAsteroids' "random spinner direction"); `$2A-$2D` the ships'
16-bit velocity low bytes reached as `$2A,X`/`$2C,X` with X = `$21/$22`
(i.e. `$4B/$4C` = X low, `$4D/$4E` = YINCL = Y low); `$31` "no more
coins"; `$3A-$42` the three 3-byte BCD scores; `$47/$48` lives remaining;
`$49/$4A` (LASTSW) the fire-button edge-detect shadows; `$4B-$4E` as
above; `$4F/$50` the shield-on flags (bit 7); `$53` "rocks off screen /
screen full"; `$B0-$C6` the object status array; `$C9-$CE` killer-mine
colour + hit count; `$CF` the current difficulty level (0-9); `$D3/$D4`
saucer minimum velocities; `$D5-$D7` rock speed band (min +, min -,
max +; `$00D8` `$D8` = max -); `$0221/$0223`, `$0251/$0253/$0255`,
`$02CE-$02D8`, `$0300-$030A`, `$033F-$0343`, `$0371-$0375` object-array
cells; `$0266`, `$026C`, `$026E`, `$0274`, `$0282`, `$0294`, `$037E`,
`$0389`, `$0398`, `$039C`, `$03B5`, `$03BA`, `$03C0`, `$03C6`, `$03CE`,
`$03D3`, `$03D5`, `$03E8` neighbours of named cells.

Candidate names for the orchestrator: `$53` "ROCKSOFF", `$CF` "DIFLVL",
`$D5/$D6/$D7` "MINVELP/MINVELN/MAXVELP", `$4F/$50` "SHLDON", `$47/$48`
"LIVES", `$53` and `$17` as above.

## Const tables (objects_data.c, all extracted + listing-cross-checked)

| array | ROM | bytes | contents |
|---|---|---|---|
| `obj_coll_tab` | $448B | 69 | CollisionDetector_110/_112/_115/_125/_126 |
| `obj_owner_tab` | $4592 | 15 | ValueOwnershipNegativeNobody |
| `obj_comet_table` | $472C | 2 | CometTable |
| `obj_angleshoot` | $4B72 | 2 | AngleShoot |
| `obj_saucer_tab` | $4C5E | 18 | StartingValues/StoppingValues/DifferentSaucerVelocities/Sspos/Ssminus |
| `obj_fire_idx` | $4D6B | 9 | the torpedo-slot windows + ship<->ship index maps |
| `obj_clearsaucer` | $53FB | 2 | ClearSaucer_100 |
| `obj_entdwarf` | $5154 | 32 | EnteringDwarfAmoutns + Entdwtable |
| `obj_initpos_m1` | $5967 | 16 | InitialPositionSpaceDuel, base-1 |
| `obj_wave_tab` | $5BA5 | 20 | the five per-wave ramps indexed by DIFF |
| `obj_toggles` | $6CCD | 8 | TableInitialValuesToggles + Ttogdrone |
| `obj_km_tab` | $6CD9 | 54 | the six killer-mine speed/angle ramps |

Tables are indexed by the ROM's own **absolute address** (`COLL(0x447A+x)`
etc.) because several fetches use a base *before* the table plus a high
object index: `$447A,X` with X = `$21-$2F` really reads `$449B-$44A9`,
`$44A9,Y` with Y = 0-7 runs off the end of `_112` into `_115` and `_125`,
`$4571,X` reaches `ValueOwnershipNegativeNobody`, `$4D51,X`/`$4D69,X`
reach the `$4D6B` block, and `$53DC,X` reaches `ClearSaucer_100`.

Not extracted, because nothing references them: `BelowTableNotUsed`
($458E, 4 bytes) and `Moti20_120` ($53C3, 4 bytes) - both dead data
(grepped: zero references in the listing).
`DifficultyTableLo/Hi` ($46B6/$46BA) is a PHA/PHA/RTS address table with
no RAM effect; it became the `switch` in `up_the_difficulty()`.

## Quirks reproduced deliberately

1. **`BackAwayFromCollision`'s missing CLC.** The Y half only clears the
   carry on the negative branch, so a *zero* YINC adds an extra 1 (`Comp`
   leaves C set when A == 0). The X half has the CLC on both paths.
2. **`RetargetComets` targets the wrong object.** `TXA / EOR #$01` with
   the ships at `$21/$22` yields `$20`/`$23` - saucer 1 and the rod, not
   the other ship. Reproduced as coded.
3. **`Updif3_60` adds LMONHITS to itself** (`LDA LMONHITS / ADC LMONHITS`)
   although the comment says "total hits between them" - it almost
   certainly meant `LMONHITS+1`. Reproduced literally.
4. **`Fire3`'s dropped carry**: `ADC EACE` (the 3/2 scale) is followed by
   a `CLC` before `ADC $033F,X`, so an overflow out of the 3/2 multiply is
   silently lost.
5. **`CopyAttributesOfRock` stores `XINC,Y` into `YINC,X` twice** and
   never writes `XINC,X`.
6. **`ZeroAllRamPast` misses `$0300`** - the `DEX / BNE` loop stops at
   X = 0.
7. **`Klmi7`'s `ROR TEMPA` pair** shifts the *previous* contents of TEMPA
   out through the carry; TEMPA's final value therefore depends on its
   stale value, and the oracle sees it.
8. **`Scent5_20`'s `LDY SCSHSP,X`** loads a register nothing reads. No
   RAM effect, so nothing is emitted; noted here in case a later reading
   finds a use.
9. **`DestructionDuringCollision` $455C-$4565 is unreachable** (jumped
   over by the `JMP CheckShieldConditionPossibly` at $4559) - a second
   "who's shot was this" test. Left as a comment.
10. **`Newship` ($5B00) is not a loop.** `InitiaizePair` sets X = $02 and
    falls in once; the `CPX #$02 / BNE` guard is therefore always false
    and the re-entry sound always plays.

## Open questions

1. **The 6502 X entering `MotionUpdateRoutine` ($5174).** The ROM's
   straddle test indexes `$0308,X` / `$02D6,X` and compares against ship
   `$22`, so the *intent* is clearly X = 0. What is actually live is
   whatever `KillerMines` -> `CompetitiveWantWaitOther` left, which is 0
   or 1 on three frames in four and the mainline's own leftover X on the
   fourth (`$44 & 3 == 1` returns without touching X). It only matters
   during an onslaught in a combined-lives game (games 2/3), which the
   attract demo does reach. `killer_mines()` therefore takes and returns
   X, and `motion_update_routine()` takes it; the mainline must thread it
   (see "Interface fix-ups" 2). If an oracle diff shows this never
   matters, collapsing both back to `void` and hard-coding X = 0 is the
   cheap fallback.
2. **`InitializeComet` ($6B68) clobbers X invisibly.**
   `CompetitiveWantWaitOther` tail-calls it at $4A9C and the ROM's next
   consumer of X is `MotionUpdateRoutine`. The C code returns the
   pre-call X with a comment; once the comet module lands, that extern
   should become `uint8_t initialize_comet(void)` returning its exit X.
3. **Sound-trigger `(x_in, y_in)` at three sites is unknowable from here.**
   `Badhab` parks the caller's live X/Y in TEMPA/TEMPB, and at
   `$450D` (DestructionDuringCollision) and `$53E4` (KillXSaucer) the live
   registers are `AddPointsToScore`'s leftovers, while at `$5570`
   (MoveShip's ThrustSound) and `$5551/$5557`, `$5B24/$5B27`
   (Reenter/Reenter2) Y is the mainline caller's. Those calls pass the
   best-known X and `0` for Y, flagged in the code. This is the same
   issue `NOTES_soundcoins.md` raises as its open question 1; if the
   orchestrator drops the parameters and masks `$1C/$1D` instead, these
   call sites simplify.
4. **`Shipfriction`'s entry carry from `$54AB`** (`MoveShip`'s "if
   exploding" JMP) is the mainline caller's carry; `move_ship()` passes 0.
   It only affects bit 0 of TEMPA. The `$556E` entry is exact.
5. `RetargetComets`' `$20`/`$23` targets (quirk 2) and `Updif3_60`'s
   self-add (quirk 3) are the two places where the ROM most clearly
   disagrees with its own comments. If an oracle diff ever disagrees with
   the C, these are the first two to re-read.
6. **`$5967,Y` with Y = 0** would read the `RTS` opcode ending `L_90`
   ($60) and store it as an X position. Unreachable in practice
   (`NewastStartNewAsteroids_10` loops X = NROCKS..1 and NROCKS maxes at
   $0B), but the generator extracts the byte so the C matches if it ever
   happens.
