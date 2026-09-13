# The playable build — `app_loop.c`

`sd_win.exe` is the game now, not a test pattern. This file records the
hardware seam it implements, the evidence for every bit of it, the pacing
model and the numbers it actually delivers, what was verified and how, and
what is still open.

    build_win.bat   ->  sd_win.exe             the game
                        tests\sd_selftest.exe  headless scripted/timed run
                        tests\color_wheel.exe  renderer-only diagnostic
    build_all.bat   ->  tests\probe_attract.exe (unchanged; see §7)

`main_stub.c` is **deleted** — `tests\color_wheel.c` is the preserved copy
of it and is the supported renderer diagnostic. `app_loop.c` links only
into the two game binaries; the probe still links its own oracle-shaped
seam, and the two must never meet in one link.

---

## 1. Input map

### IN0 ($0800) — `sd_hw_in0()`

Idle byte **`0x3F`** plus the two synthesized bits (`0x40` HALT, `0x80`
3 kHz), i.e. `0xDF`/`0x9F` as the clock swings.

| bit | line | polarity | idle | host control | evidence |
|---|---|---|---|---|---|
| d0 | coin, **right** mech (`coins.c` X=2, DIP "Coin B" ×1/×4/×5/×6) | **active low** | 1 | coin1, key `5` | `coins.c` L741C: `coin_absent = (in0 >> (2-x)) & 1` — a 1 means *no coin*. AAE `input_ports_spacduel`: `PORT_BIT(0x01, IP_ACTIVE_LOW, IPT_COIN1)` |
| d1 | coin, **centre** mech (X=1, DIP "Coin A" ×1/×2) | **active low** | 1 | coin2, key `6` | same; multiplier is `ZMINE` d4 (`coins.c` L7497) |
| d2 | coin, **left** mech (X=0, always 1 unit-coin) | **active low** | 1 | coin3, key `8` | same; `coins.c` header, "X=0 is the left mech" |
| d3 | slam / tilt | **active low** | 1 | none | `coins.c` L7442: `if (!(in0 & 0x08)) $0025 = 0xF0` — low = switch tripped |
| d4 | self-test | **active low**, 0 = test mode | 1 | test, key `9` (held) or the **F2 toggle** (`diag`, edge-detected into `test_latch`) | `mainline.c` `sd_boot` → `beginning_pattern()`, `sd_mainline_frame` → `all_stop_please()` (`selftest.c`, since 2026-09-01, `NOTES_selftest.md`). AAE: `PORT_BITX(0x10, ... Service_Mode)`, `PORT_DIPSETTING(0x00, On)` |
| d5 | diagnostic step | **active low** | 1 | diag_step, key `F1` | AAE: `PORT_BITX(0x20, IP_ACTIVE_LOW, IPT_SERVICE, "Diagnostic Step")` |
| d6 | VG HALT | 1 = AVG finished | synthesized | — | `mainline.c` `$401F BIT HALT / BVC`; §3 below |
| d7 | 3 kHz clock | square wave | synthesized | — | NOTES_oracle.md §2/§6, `(cycles/252)&1` |

### THE POLARITY TRAP (NOTES_oracle.md §2), settled

The probe returns **`0x50`**. That leaves d3 **low** and d0-d2 **low**,
which the ROM reads as *slam switch tripped* and *a coin sitting in every
mech*. With slam active, `coin_routine`'s `_2` arm reloads `$0025` to `$F0`
on **every** IRQ and wipes the coin status cells `$2A-$2F` — so no coin can
ever complete its debounce and no credit can ever be tallied. That is
deliberate for the attract oracle (attract must run forever) and is exactly
why coins never register with the probe's byte.

A cabinet idles all four **high**. The observable consequence of getting
this right, from the self-test run:

    credits $$CRDT $20: 0 -> 1   $CNCT $26 = 0   $CMODE $24 = $02

The coin's own timing, straight out of `coins.c`, for anyone debugging it:
the coin bit must go low for **≥ 5 IRQs (~20 ms)** so the `$2D+X`
down-counter drops below `$1B` (shorter = "bounce", counter is reset to
`$1F`); on release the coin-off up-counter needs another **7 IRQs
(~28 ms)** to wrap, which arms the post-coin timer `$2A+X = $78`; that runs
out **120 IRQs (~490 ms)** later and *that* is when the credit appears. A
credit therefore lands about half a second after the key is released — as
on the real machine.

### IN1 ($0900-$0907) — `sd_hw_in1(idx)`

One switch pair per address, **ACTIVE HIGH**, tested with `BIT` (d7 = N,
d6 = V). Idle `0x00` — the same byte the oracle used, so this map cannot
move the probe. Every bit was traced to a C call site *and* cross-checked
against AAE's own hardware decode (`drivers/bwidow.cpp`
`READ_HANDLER(SDControls)`), which agrees on all of them.

| addr | d7 | d6 | C call site (the ROM's own read) |
|---|---|---|---|
| `$0900` HYPSW | **shield/hyperspace P1** | **fire P1** | d7: `objects.c` `twin_game_both_shields()` returns `sd_hw_in1(x)`, caller tests bit 7. d6: `objects.c` `fire_ships_torpedos()` — two `ASL`s put bit 6 in the carry, then `ROR LASTSW,X` |
| `$0901` | shield/fire P2 | | same call sites with x = 1 |
| `$0902` ROTL | **rotate left P1** | **rotate right P1** | `irq.c`: `sd_hw_in1(2+x) & 0x80` → `IANGLE,X++`; `& 0x40` → `IANGLE,X--` |
| `$0903` | rotate L/R P2 | | same, x = 1 |
| `$0904` STRT1 | **thrust P1** | **START** | d7: `objects.c` `move_ship()` `_11` reads `sd_hw_in1(4+x)` and tests N. d6: `mainline.c` `check_for_start_end()` `_17` `BIT STRT1 / BVC` |
| `$0905` OPTNA1 | thrust P2 | "selling players" jumper (0) | d7: `objects.c` `dorig3()` `_56`. d6: `mainline.c` `_12` (`TEMP5--` when set) |
| `$0906` GAMSEL | **SELECT GAME** | 2-coin-minimum jumper (0) | d7: `mainline.c` `_16` `SAVBOT` debounce (rising edge). d6: `mainline.c` `_80` |
| `$0907` CABERE | cocktail (0) | caberet (0) | `mainline.c` `uses_temp1_temp11()` (d7) and `nxtstep()` (d6). `0x00` = **upright** |

Host keys: `LCtrl` fire, `Up`/`Alt` thrust, `Space`/`Down`/`LShift` shield,
`Left`/`Right` rotate, `1` start, `7` (or `2`) select, `5`/`6`/`8` coin,
`Esc` quit, `ALT+ENTER` fullscreen. AAE labels `$0906` d7 START2; the ROM
calls it GAMSEL and uses it to step through the four games, so both host
keys reach it.

**d4 of IN0 is live since 2026-09-01** (`selftest.c`). `9` is the cabinet
switch line, held; `F2` is the host toggle, MAME-style: press in-game for
the bookkeeping screen, again to leave; held while the game starts, the
power-on diagnostics. `F1` is DIAGNOSTIC STEP. Both `mainline.c` entry
points now jump where the ROM does. Details, the PCB's own reset rules and
the verification: `NOTES_selftest.md`.

### Two things about starting a game that look like bugs and are not

1. **coin → SELECT → START.** `Pwron` sets `STRTLOK = $80` ("no starts
   allowed") and the only thing that clears bit 7 is
   `CheckForStartEnd_42`, on the rising edge of the GAME SELECT switch —
   and that code is only reached while a credit is showing. So a freshly
   powered cabinet needs a coin, then SELECT, then START. Verified:
   `STRTLOK before select = $80`, `after select = $40`, and START then
   works.
2. **One credit does not start every game.** `Ttplayr` ($6CD5) =
   `{2,1,2,1}`: games 0 and 2 cost two credits. `CheckForStartEnd_46`
   walks `Nxtstep` until it finds a game the credit can afford — with one
   credit from cold it lands on game 1.

### DIP switches

Routing: **POKEY1 ALLPOT ($1008) = DSW0**, read by `Gtoptn $76DB`
(lives/difficulty/language/bonus); **POKEY2 ALLPOT ($1408) = DSW1**, read
by `CheckForStartEnd _12` (coinage). That is AAE's `pokey_interface`
allpot wiring, `{ input_port_1_r, input_port_2_r }`.

Both banks are set from `[dips]` in `sd_win.ini` (see `README.md`), by the
same `dip_pick` backend helper the Asteroids Deluxe port uses: one key per
switch group, a word from a list, unknown words falling back to the default
and the accepted spelling written back. The defaults are the factory
settings and produce `DSW0 = $01`, `DSW1 = $00` — byte-identical to the
constants the backend returned before the keys existed, so nothing about
the port's behaviour moved. The ROM's EOR corrections land them on the
factory meanings, which is the check that the routing is the right way
round:

- `OPTN1 = 0x01 ^ 0x85 = 0x84` → lives `(0x84 & 3) + 3 = 3`; difficulty
  `(0x84>>2)&3 = 1` (normal); language `(0x84>>4)&3 = 0` (English); bonus
  index `(0x84>>6)&3 = 2` → `mainline_bonus_optn[2] = $10`. The attract
  screen duly reads **BONUS EVERY 10000**.
- `ZMINE = 0x00 ^ 0x02 = 0x02` → coin mode 2 = **1 credit per coin**, both
  mech multipliers ×1, bonus-adder off.

**Default: real coinage, 1 coin / 1 credit — not free play.** Coins work
(demonstrated), which is the more interesting thing to prove. Free play is
`coinage=free_play` (`DSW1 = $02`, so `ZMINE & 3 == 0`), which makes
`CheckForStartEnd` hand out `DIAGBI = 2` every frame.

### The switch bits, and the driver cross-check

Bit values are the AAE/MAME `bwidow` driver's `INPUT_PORTS_START(spacduel)`
— the same driver the Gravitar disassembly checks its hardware notes
against. Every one was re-derived from the ROM tables and agrees:

| bank | mask | option | settings (switch value → meaning) |
|---|---|---|---|
| DSW0 | `$03` | lives | `01`→3, `00`→4, `03`→5, `02`→6 &nbsp;(`(OPTN1 & 3) + 3`) |
| DSW0 | `$0C` | difficulty | `04`→easy, `00`→normal, `0C`→medium, `08`→hard &nbsp;(index into `Fighters`/`SpaceStation` `$7728`) |
| DSW0 | `$30` | language | `00`→English, `10`→German, `20`→French, `30`→Spanish |
| DSW0 | `$C0` | bonus life | `C0`→8000, `00`→10000, `40`→15000, `80`→none &nbsp;(index into `Bonus` `$7724` = `00,08,10,15`) |
| DSW1 | `$03` | coinage | `01`→2C/1P, `00`→1C/1P, `03`→1C/2P, `02`→free play |
| DSW1 | `$0C` | right mech | `00`→×1, `04`→×4, `08`→×5, `0C`→×6 |
| DSW1 | `$10` | centre mech | `00`→×1, `10`→×2 |
| DSW1 | `$E0` | bonus coins | index `DSW1>>5` into `NumberUnitCoinsRequired` `$74CF` = `7F,02,04,04,05,03,7F,7F`; mode 3 grants two |

The difficulty words are the ROM's own: the self-test prints messages
`$19/$10/$11/$25` = **EASY / NORMAL / MEDIUM / HARD** for switch 0-3
(`sub_8f43` + `$0D` into `selftest_msg_num`). NORMAL and MEDIUM both give
`DIFF = 2` in the fighter games and differ only in the space-station ones
(`Fighters` = `01,02,02,03`, `SpaceStation` = `01,01,02,03`).

**One correction to the driver.** It labels `DSW1 = $80` "6 credits/6
coins", but that setting is `NumberUnitCoinsRequired[4] = 5` — one bonus
coin every *five*, i.e. 6 credits for 5 coins. The ini key is
`6_credits_5_coins`. Every other label matches the ROM exactly.

**Not exposed as switches:** the three cabinet jumpers on `IN1` d6/d7
(`$0905` sell games/players, `$0906` two-coin minimum, `$0907` d6 caberet
and d7 cocktail). The driver does not model them either; the backend
answers 0 for all three, which is the standard upright wiring. Note the
cocktail bit's polarity: **d7 = 1 is cocktail**, not upright as
`AS2DEC.MAC`'s equate comment claims — `$690C LDX CABERE / BMI`, commented
"COCKTAIL?????" / "YEP...NO ADITIONAL FLIP NEEDED", settles it.

---

## 2. Pacing model

Machine time is the 246.09375 Hz IRQ (1.512 MHz / 6144 = 4.063492 ms).
`machine_pump()` converts elapsed wall-clock ms (`plat_now_ms()`) into IRQ
services, with Omega Race's 100 ms stall clamp. Both hardware poll loops
are **real waits** that keep servicing IRQs while they block, exactly as
the 6502 sat in them with interrupts enabled:

- `sd_wait_frame_gate()` — `$4027 LSR $33 / BCC`. Byte-for-byte the
  probe's `consume_gate_bit()`, except that running out of bits waits for
  machine time instead of synthesizing it.
- `sd_wait_vghalt()` — `$401F BIT HALT / BVC`. After a VGGO, HALT stays
  low for `avg_frame_time_ms()` of the list just started (avg.c's
  cycle-true mame_late model, validated on all 34 captured frames).

Nothing writes down a frame rate. The period **emerges** as
`max(frame gate, AVG draw time, the 6502's own time for the pass)` —
DESIGN.md's rule, fallen out of the two waits plus the CPU-time model added
on 2026-09-13 (the third term; see "The 6502's own time" below).
`sd_hw_irq_mark()` is a **no-op** here, with the reason in the code:
it exists so a *probe* can replay the oracle's recorded `irq_count` at four
exact ROM locations; on a cabinet real elapsed time already spreads a
pass's IRQs through it.

One subtlety worth knowing when reading the numbers: `$33` is a shift
register of *pending* gate ticks, not a one-shot. If a heavy frame
overruns, the ticks pile up and the next passes consume them with no wait
at all — which is why in-game frame times range from ~4.6 ms to ~19.9 ms
while the average stays near the gate. That is the ROM's own dynamics, not
jitter in the host.

### Measured frame rates

**Attract, real window** (from `sd_win.log`, which now records the status
line once a second — see §6):

    62.5 fps  frame 16.26 ms (min 15.76 max 16.75)  avg draw 11.46 ms  293 segs  1638 list bytes
    61.5 fps  frame 16.25 ms (min 15.70 max 16.81)  avg draw 11.30 ms  303 segs  1638 list bytes
    61.5 fps  frame 16.25 ms (min 16.15 max 16.37)  avg draw 11.46 ms  303 segs  1638 list bytes
    61.5 fps  frame 16.25 ms (min 15.68 max 16.87)  avg draw 10.60 ms  292 segs  1478 list bytes
    61.5 fps  frame 16.25 ms (min 16.13 max 16.40)  avg draw 15.31 ms  330 segs  2352 list bytes
    58.9 fps  frame 16.99 ms (min 16.14 max 18.10)  avg draw 15.76 ms  495 segs  2552 list bytes
    59.7 fps  frame 16.76 ms (min 15.65 max 17.67)  avg draw 17.18 ms  493 segs  2770 list bytes

So: **61.5 fps** while the display list costs less than the 16.26 ms gate,
and the rate drops (58.9-59.9 fps observed) as heavier attract screens push
the AVG past it. That is precisely what NOTES_avg.md predicted from the
cycle-true model, now observed live rather than computed.

**Headless model** (`tests\sd_selftest.exe`, synthetic clock, so this is
the model's own rate with the host taken out of it):

    attract        600 frames  segs 0..498 avg 299  frame 16.25..17.08 ms avg 16.28 (61.4 fps)
    in a game      142 frames  segs 92..625 avg 165  frame  4.61..19.86 ms avg 16.45 (60.8 fps)

The 45 fps of AAE/MAME is still not what this hardware model produces, and
NOTES_avg.md already explains why (it is a declared driver constant). Play
lists here reach ~2.8 kB and ~17 ms — they *do* cross the gate, but not by
enough to halve the rate.

### The 6502's own time (2026-09-13, backported from the Gravitar port)

The two waits above are the *hardware's* time. The third term is the
**CPU's**: on the board a Start2 pass is real 6502 work — `Gtoptn` and the
self-test test before the AVG wait, then `DoLowOnesEvery`, the frame gate,
the buffer swap at `$404E`, and everything that builds the next list up to
`L410D JSR AddHaltToVector`. A translated pass costs microseconds, so
before this the port handed over a finished list on every gate tick and
could not reproduce the ROM's own overrun frames: the oracle's 600-frame
attract run takes 4 IRQs on 556 passes but **5, 6 or 7 on 43 of them**, and
the port took 4 every single time. (Space Duel is milder than Gravitar,
whose port ran 2-5x too fast without this, because Space Duel's mainline
strobes the VG itself and its `$33` gate already paces the common case.)

**The costs are measured, not invented.** `tools/prof_fit.py` is an
observer over `tools/oracle.py` — the hardware model itself untouched, no
reference bytes written — that reports, per pass, the mainline's own cycles
(everything but the two hardware waits `$401F`/`$4027` and the IRQ handler)
against the display-list bytes the pass built, **split PRE/POST at the
first wait**: PRE is `$4110 → $401F`, POST is the rest.
`tools/prof_pass.py` is its companion, the per-routine breakdown of one
pass, for when a state's work does *not* follow its list length.

    py c_src\tools\prof_fit.py  <scratch> 3000 attract [--rows]
    py c_src\tools\prof_pass.py <scratch> 600 2 attract

Space Duel's equivalent of Gravitar's `(STATE, DSTATE)` pair is
**`(ATRACT $35, ATSTG $DC)`** — is a game running, and is this the special
attract stage. Fitted over attract 3000 frames + play 3000 frames +
selftest 440 frames, **6,046 passes**:

| ATRACT | ATSTG | passes | base | per_byte | sd | pre | handler | list bytes | = IRQ periods of work |
|---|---|---|---|---|---|---|---|---|---|
| `$00` | `$00` | 695 | 5047 | 48.28 | 1719 | 1877 | 798 | 190-504 | 2.66-5.50 |
| `$00` | `$80` | 2482 | 1180 | 56.56 | 1855 | 1864 | 800 | 226-574 | 2.61-6.30 |
| `$80` | `$00` | 2868 | 2207 | 51.35 | 1853 | 1843 | 490 | 140-302 | 1.66-3.13 |
| `$80` | `$80` | 1 | 23042 | 0 | — | 307 | 792 | 114 | 4.31 |

`base`/`per_byte`/`pre` are 6502 cycles; `handler` is IRQ-handler cycles
per IRQ. W cycles of mainline work occupy `W / (6144 - handler)` IRQ
periods, because the handler steals its share of every period; fractions
carry over, so a 4.01 averages 4.01. **No state takes Gravitar's
per-state-mean treatment**: the list length explains most of the spread
everywhere here (residual sd 1.7-1.9 k cycles against a 3.0-6.5 k spread
about the plain mean), so `per_byte` is real in all three populated states.
The `$80/$80` row is the single transition pass into a game; it gets the
mean because one pass has no slope.

**That the model is the right one is checkable, and it checks.** Group the
oracle's own attract passes by the number of IRQs it actually spent on
them, and the measured mainline work per pass is:

| IRQs the oracle spent | passes | mean list bytes | mean work | = IRQ periods |
|---|---|---|---|---|
| 3 (gate ticks left over) | 8 | 226 | 15,225 | 2.85 |
| 4 | 521 | 247 | 14,298 | 2.68 |
| 5 | 30 | 432 | 24,294 | 4.55 |
| 6 | 22 | 533 | 31,205 | 5.84 |
| 7 | 1 | 544 | 32,429 | 6.07 |

The overruns **are** the CPU time and nothing else: below 4 periods of work
the gate rules and the pass takes 4 IRQs; above it, the pass takes as many
IRQs as the work.

**Where it is charged.** `app_loop.c`'s `cpu_fits[]`, `cpu_charge()` and
`cpu_charge_cycles()`; `cpu_charge()` spends IRQ periods by calling
`machine_tick()`, i.e. by letting the machine's own clock run, so
everything (sound tempo, the EAROM machine, the fps lock) stays consistent.

- `sd_wait_vghalt()` — the pass's *first* hardware wait — looks the fit up
  from `(ATRACT, ATSTG)` and charges `pre`.
- `sd_hw_list_done()` — the new seam call at `L410D`, right after
  `vg_add_halt()` in `mainline.c` — is where the build's cost is first
  *known* (`VGLIST`/`EAC2` gives the length), so it charges
  `base + per_byte * bytes - pre`.

An "armed" flag keeps this to Start2 passes: `selftest.c` also calls
`sd_wait_vghalt()` (from `$85A1` and St2), loops that build no list and
have no fit, and only `sd_hw_list_done()` arms the flag. Consequence,
recorded: the first pass after a boot is uncharged (one pass), and the
first self-test HALT wait after leaving the game loop consumes a stale arm
worth ~0.35 IRQ, once.

**The probes are untouched by all of this.** They implement their own
`sd_hw_*` seam and replay the oracle's recorded IRQ schedule, so
`sd_hw_list_done()` is a no-op in `tests/probe_attract.c` and
`tests/probe_selftest.c` and no probe ever calls the charge or the fps
lock. Verified byte-for-byte: `probe_attract 600` still 33/34 with the
same 35 bytes on frame 576, `probe_selftest` still 122/122, 57/57, 77/77,
every counter line identical to the run before the model went in.

### Cadence after the model: the port against the oracle

Headless (`tests\sd_selftest.exe`, synthetic clock — the model's own rate
with the host taken out of it), 900 attract frames from boot:

| | before the model | after | the oracle, same 900 frames |
|---|---|---|---|
| attract, 900 frames | 61.2 fps (14.96-17.65 ms) | **55.0 fps** (12.19-28.44 ms) | 4.450 IRQs/pass = **55.3 fps** |
| in a game, 142 frames | 60.5 fps (16.54 ms avg) | **60.5 fps** (16.54 ms avg) | 4.00 IRQs/pass = 61.5 Hz |

0.5% from the oracle on attract, and play unchanged — which is the right
answer, not a lucky one: the oracle's `play` scenario takes **exactly 4
IRQs on all 1368 in-game frames** (STATUS.md), and the fit says a play pass
costs 1.66-3.13 IRQ periods, i.e. never enough to overrun the gate. The
model only bites where the ROM's own frames bite.

Live window (`sd_win.log`, `[main] fps_lock=62.5`, so every hardware step
is scaled by 62.5/61.523 = 1.0159 — 4 IRQs = 62.5 Hz, 5 = 50.0, 6 = 41.7):

    62.5 fps  frame 16.00 ms (min 15.55 max 16.49)  avg draw 11.38 ms  303 segs  1638 list bytes
    62.5 fps  frame 16.00 ms (min 15.89 max 16.12)  avg draw 11.46 ms  303 segs  1638 list bytes
    59.5 fps  frame 16.80 ms (min 15.85 max 24.06)  avg draw 15.38 ms  330 segs  2626 list bytes
    42.5 fps  frame 23.54 ms (min 19.99 max 28.00)  avg draw 17.19 ms  544 segs  2960 list bytes
    41.7 fps  frame 24.00 ms (min 19.98 max 28.08)  avg draw 17.56 ms  558 segs  3110 list bytes
    42.5 fps  frame 23.53 ms (min 19.88 max 27.97)  avg draw 14.77 ms  540 segs  2674 list bytes
    45.0 fps  frame 22.22 ms (min 19.87 max 24.13)  avg draw 14.22 ms  513 segs  2516 list bytes
    48.2 fps  frame 20.74 ms (min 15.98 max 24.13)  avg draw 14.04 ms  485 segs  2616 list bytes
    53.6 fps  frame 18.66 ms (min 15.90 max 24.07)  avg draw 14.29 ms  478 segs  2524 list bytes
    62.0 fps  frame 16.13 ms (min 12.07 max 20.25)  avg draw 12.08 ms  443 segs  2252 list bytes
    62.5 fps  frame 16.00 ms (min 15.87 max 16.11)  avg draw 12.19 ms  432 segs  2252 list bytes

The heavy attract screen now sits on **41.7 fps = exactly the 6-IRQ step**,
the light ones on **62.5 = the 4-IRQ step**, and the intermediate
one-second averages (45.0, 48.2, 53.6) are mixtures of 4-, 5- and 6-IRQ
passes — the same three steps, in the same proportions, that the oracle
takes ({4: 630, 5: 132, 6: 130, 7: 5} over the first 900 attract frames).
Before the model the same screens read 61.5-58.9 fps throughout: the AVG
draw time alone never took them below the gate by much, and the CPU was
free. (The "list bytes" in the status line is the AVG's *word* count times
two — vector-ROM subroutine words included — not the mainline's own list
length that `per_byte` multiplies; the two are different measures of the
same frame.)

### Power-on is fast-forwarded

`StartThingsRunning` burns `$61` gate ticks (~1.58 s of hardware time) as
the EAROM warm-up. On the wall clock that is 1.6 s of black, unpainted
window that reads as a hang, so `sd_app_init()` runs `sd_boot()` on the
**synthetic** clock and switches to the wall clock afterwards. The IRQ
sequence is bit-identical either way (388 IRQs to the first frame); only
the wall time it occupies changes.

> Trap, recorded because it cost an hour: the synthetic clock originally
> advanced by *exactly* the shortfall (`SD_TICK_MS - irq_acc`). Double
> rounding means `(t + d) - t` can come back a few ULPs **short** of `d`,
> so the accumulator parked forever a hair under one tick and the wait
> never ended. `machine_idle()` now adds 1e-6 ms of bias in synthetic mode
> (~0.25 ppm, and only in the mode where "wall time" is a fiction).

---

## 3. Rendering and the coordinate mapping

`sd_hw_vggo()` is the frame boundary: the mainline has just swapped the
`$2001` buffer-select word and strobed GOADD, so the list reachable from
word address 0 is the finished frame. `avg_run()` walks it and every lit
segment goes out through `plat_video_begin()` / `plat_video_line()` /
`plat_video_present()`. Dark moves (`lum == 0`) are reported by avg.c so
callers can trace the beam; they are dropped, not drawn.

**The mapping is a pure translation — no scale, no flip:**

    px = 260.0 + x        (BEAM_CX = 520/2)
    py = 197.5 + y        (BEAM_CY = 395/2)

avg.c emits AVG units around the beam centre, +x right, +y up. The
platform window is the AAE spacduel screen rectangle x 0..520, y 0..395,
y up (`AAE_DRIVER_SCREEN(1024,768, 0,520, 0,395)`), and AAE maps AVG units
into it **1:1** with the beam starting at the rectangle's centre
(`aae_avg.cpp`: `currentx = xcenter`, `deltax = x * scale`, no further
scaling). So one AVG delta LSB *is* one unit of this window.

Sanity check against the captured attract frames (via `tests\avg_dump.exe`
on `tests\ref\frame_*.vram`): x spans −255..+250 → **px 5..510** of 0..520,
y spans −149..+181 → **py 48..379** of 0..395. Nothing clips; the picture
sits slightly high in the window, which is what AAE shows too. Beam units
are square to 1.3% in the 4:3 design rect (1.969 px/unit across,
1.944 px/unit down).

**Nothing was mirrored or upside-down — no correction was needed.** The
first screenshot came out right way up and reading left-to-right.
Orientation is handled entirely upstream: the cocktail flip lives in the
ROM's own `UPDOWN` handling of the display list, and the OUT1 d6/d7 lines
the ROM sets to `$C0` on an upright cabinet ("ELSE FLIP FOR COCKTAIL
NORMAL", $6911) are **not** beam-flip hardware on this board — AAE and MAME
both ignore them, and so does this renderer.

---

## 4. EAROM and NVRAM

The part is an **ER-2055, 64 × 8**. Since 2026-09-03 it is MAME 0.286's
`er2055_device` model (`er2055.c`, the Asteroids Deluxe port's translation,
verbatim) behind the seam, wired as MAME's `bwidow.cpp` wires it (the same
decode as `asteroid.cpp`): EACTL bit 3 = CS1 (CS2 tied high), bit 2 = C1
*inverted*, bit 1 = C2, bit 0 = the clock. On the chip that makes
`earom.c`'s codes:

| seam call | on the chip |
|---|---|
| `sd_hw_earom_write(off, v)` | address = `off & $3F`, data latch = `v` |
| `sd_hw_earom_ctl($0E)` | C2 alone, selected: **erase** - the cell goes to `$FF` |
| `sd_hw_earom_ctl($0C)` | neither, selected: **write** - cell `&=` data latch |
| `sd_hw_earom_ctl($08/$09/$08)` | C1 alone, clock pulse: **read** - the falling edge latches the cell |
| `sd_hw_earom_ctl($00)` | deselect (ends the pulse; the NVRAM flush point) |
| `sd_hw_earom_read()` | the data latch |

Every operation fires only on a genuine transition while selected, so a
read never corrupts a cell and a same-value rewrite of the latch is a
no-op. The write being an AND is why the ROM erases each byte first -
`tests\probe_er2055.exe` proves a rewrite of the table with different
bits comes out right only through that erase (its check 6 drives
`earom.c`'s real state machine over a local chip). The previous, simpler
latch model (clock = read, `$0C` mask = write) produced the same on-disk
bytes, so existing `sd_c.nv` files carry over unchanged.

**NVRAM blob = the 64-byte image, raw, no header** (`sd_c.nv`). The core
owns the layout, and the layout *is* the part. Inside it, the ROM's own
map (NOTES_earom.md §1): batch 0 = high scores + initials, EAROM `$02-$1C`
plus checksum at `$1D`; batch 1 = bookkeeping, `$1E-$3D` plus checksum at
`$3E`. A real 64-byte file after a scripted high-score write:

    00 00 37 00 00 00 00 00  00 00 00 13 05 05 05 00
    00 00 00 00 00 00 00 00  00 00 00 00 00 59 00 00
    ...                                    ^^ batch-0 checksum at $1D

**A missing, short or absent file leaves the image all zeroes, which IS a
fresh blank part** — no special-casing anywhere. Both checksums are then 0
and match, `$0187` stays 0, and the boot's copy path reseeds the four
500-point top scores. Observed on a cold run:

    boot done, 388 IRQs, EAROM bad-checksum flags $00 (0 = both batches OK)
    top-of-table score bytes $DE/$ED/$FC/$10B = 05 05 05 05 (05 = the reseeded 500)

Flush points: the `$00` deselect that ends an erase/write pulse (the state
machine issues one every 16th IRQ even when idle, so a finished byte
reaches the disk within ~65 ms), plus `sd_app_exit()`. A power cut
mid-batch therefore looks like a bad checksum, which the ROM already
handles by zeroing that batch.

`sd_hw_out1()` shadows `g.out1` and forwards to `plat_leds_out()` (coin
counters d0/d1, start lamps d4/d5, cocktail flip d6/d7).

**The POKEYs (since 2026-09-03).** `app_loop.c` owns two `ad_pokey`
instances (`pokey.c`, the Asteroids Deluxe port's core, verbatim - MAME's
true LFSRs for the polys, Altirra's ALLPOT scan model, the Ron Fries
event renderer). `sd_hw_pokey_write()` writes them register for register
(masked to 16 - the ROM's power-on clear walks X = `$00..$FF`); a POTGO
strobe first re-samples the platform's DIP byte onto the chip's pot pins.
`sd_hw_pokey1_diffsw()`/`sd_hw_pokey2_optionsw()` read ALLPOT from the
chips: every one of the ROM's six reads is the LDA right after its POTGO
STA, so the read lands mid-scan and gets the still-counting-line mask,
i.e. the DIP byte. `sd_hw_pokey_random()` reads RANDOM from the polynomial
under this host's time model (pokey.h): `machine_pump()` advances both
chips 6144 POKEY cycles per IRQ (1.512 MHz / 246.09375 Hz), and each game
read first advances both by a flat 64 - the same stand-in for the 6502's
own cycles the Asteroids Deluxe host uses. The sequence after Inisou's
SKCTL reset is therefore a function of machine time alone, which is what
the chip does too; the old wall-clock-seeded free-running LFSR is gone.
Consequence for the headless self-test: a given attract length can hand
the scripted pilot an early death (600 frames does, 601 does not), so the
thrust/fire checks now wait for a live ship, watch every frame, and retry
after a death.

**Sound.** After each `sd_irq()` the loop renders one IRQ tick of both
chips (179.2 frames at 44.1 kHz, a fractional accumulator keeping the
long-run rate exact; the fps lock stretches the block with the tick),
sums them with saturation and pushes the block through `plat_audio_push`
- `mixer.c`'s XAudio2 stream voice on Windows, a counter in the headless
backend. Nothing is pushed while the clock is synthetic (the boot
fast-forward), so the stream never starts with 1.6 s of backlog. The
headless self-test checks frames pushed == IRQs × 44100 / 246.09375
(within the carry) and that the peak level is nonzero once the scripted
game has fired and exploded things.

---

## 5. What was verified, and how

### `tests\sd_selftest.exe` — the same `app_loop.c`, headless

Built from `app_loop.c` (with `SD_SELFTEST_MAIN`) + every core module +
`platform/headless`. It runs the **real** app loop and the **real** seam;
only the backend and the clock differ. Inputs are injected through
`hl_inputs`, and it round-trips the NVRAM blob through the actual
`sd_c.nv` file. Full output of `tests\sd_selftest.exe 600` from a cold
start (no `sd_c.nv`):

    SELFTEST: NVRAM absent (fresh blank part)
    SELFTEST: boot done, 388 IRQs, EAROM bad-checksum flags $00
    SELFTEST: top-of-table score bytes $DE/$ED/$FC/$10B = 05 05 05 05
      attract          600 frames  segs 0..498 avg 299   frame 16.25..17.08 ms avg 16.28 (61.4 fps)
      coin inserted    132 frames  segs 436..622 avg 559  frame 15.38..17.49 ms avg 16.78 (59.6 fps)
      credits $$CRDT $20: 0 -> 1   $CNCT $26 = 0   $CMODE $24 = $02
      STRTLOK $43D before select = $80 (bit7 = starts locked)
      STRTLOK after select      = $40, game type $34 = 1
      game started     142 frames  segs 92..625 avg 165   frame 4.61..19.86 ms avg 16.45 (60.8 fps)
      game flag $35 = $80 (bit7 = playing)  game type $34 = 1  credits = 0  lives $47/$48 = 2/0
      IANGLE $3D0: idle 128 -> rotate-left 248 -> rotate-right 128
      ship-0 velocity X 0000 -> C478   Y 0000 -> 0000   position $2D6/$308 = 12/05
      ship-0 status $B8 = 02  entry/shield $4F = 00
      ship-0 torpedo slots $BF-$C2 active: 0 at rest, peak 4 while firing
      EAROM write done after 222 frames; image[2..7] = 37 00 00 00 00 00
      after reboot: top score bytes $DE/$DF = 13 37 (expect 13 37), bad flags $00
    SELFTEST: PASSED (0 failures)

Which answers, in order:

- **attract animates** — segment count varies 0..498 frame to frame (a
  still picture is an explicit FAIL in the script);
- **a coin registers** — `DIAGBI` 0 → 1 with the corrected idle byte;
- **start begins a game** — after the ROM's own coin → SELECT → START
  sequence, `$35` bit 7 set, the credit spent, lives loaded;
- **the ship responds** — rotate moves `IANGLE`, thrust builds ship-0's
  16-bit velocity from `0000` to `C478`, fire puts all four of ship 0's
  torpedo slots (`$BF-$C2`) in the air;
- **the EAROM survives a restart** — a scripted high-score write
  (`transfer_high_scores_buffer` + `write_high_scores_initials`, ~222
  frames of the real 2-ticks-per-byte state machine), `sd_app_exit()`, the
  blob written to `sd_c.nv`, then a second `sd_app_init()` that reads it
  back and finds `$DE/$DF = 13 37` with clean checksums.

And across a **process** restart, which is the part that matters: running
the binary again with that `sd_c.nv` on disk,

    SELFTEST: NVRAM loaded from sd_c.nv
    SELFTEST: boot done, 388 IRQs, EAROM bad-checksum flags $00
    SELFTEST: top-of-table score bytes $DE/$ED/$FC/$10B = 13 05 05 05

— `$DE` comes back as `13`, i.e. the stored score, while the other three
tables are still the reseeded `05` (500) of a blank part. A fresh process
read the file, the checksums validated, and `CopyFromBufferBack` unpacked
it. `sd_win.exe` runs the identical `earom_load()` / `sd_hw_earom_*` code
over `plat_win.c`'s `plat_nvram_read/write` (a six-line `fopen`/`fread`,
unchanged from the Omega Race port).

### The real window

- Ran `sd_win.exe` and read `sd_win.log`: the fps table in §2.
- Screenshotted attract: "SPACE DUEL" in coloured 3-D cubes, both score
  panels with three ship glyphs each, "BONUS EVERY 10000", "©MCMLXXX ATARI
  INC", ships and shots moving. Correct orientation, correct aspect,
  nothing clipped, colours as `avg_rgb[]` intends.
- Drove the real keyboard with `keybd_event` (held keys, not `SendKeys`):
  `5` coin → `7` select → `1` start → `Up` thrust + `Left` + `Space`
  (Space was a fire key at the time; remapped to shield 2026-08-30).
  Screenshotted a live game: score panel with remaining ships, the player
  ship with two shots trailing it, four spinning rocks. **The windowed
  build takes a coin and plays.**

### The probe

`build_all.bat` still builds and `tests\probe_attract.exe 600` still
reports the regression bar exactly:

    PROBE: 600 frames run, 34 compared, 33 byte-identical, 35 mismatched bytes
    PROBE: pokey writes 3558, earom ctl 484, earom data 61, irq services 2855
    PROBE: RANDOM reads 1347
    STUBS: 8 temporary no-op stubs linked, 0 executed

Unchanged, as required. (Exit code 1 is the probe's normal "not all frames
clean" status for this known 33/34 baseline.)

### What a human should still check by hand

1. **Feel.** Nothing here measures whether the ship handles right — the
   inertia, the rotation rate, the shield drain. Play it.
2. **A full game to game-over in the window**, then quit and restart, and
   see the high score come back on the attract table. The scripted write
   proves the format and the file; only a real game exercises
   `UpdateInfoAtEnd` → `RequestBookkeepingUpdate` end to end.
3. **The other three games** (SELECT cycles all four). Only game 1 has
   been driven.
4. **Fullscreen** (ALT+ENTER) and a non-96-dpi monitor.
5. **The phosphor/beam knobs** in `sd_win.ini` (`linewidth`, `gain`,
   `phosphor_ms`) — tuned for Omega Race's mono beam, never eyeballed for
   a colour game.

---

## 6. Files changed outside `app_loop.c`

- **`build_win.bat`** — builds the three targets listed at the top.
  `color_wheel.exe` is a separate link and never sees `app_loop.c` (both
  define `sd_app_*`).
- **`main_stub.c`** — deleted (superseded by `tests\color_wheel.c`).
- **`platform/windows/plat_win.c`** — ONE change, four lines:
  `plat_status_text()` now also does `LOG_INFO("%s", s)`. Justification: the
  core sends that line about once a second and it carries the pacing
  numbers; a window title cannot be read back from a scripted or background
  run, and measuring the delivered frame rate is exactly what the pacing
  model had to be checked against. No contract change, no behaviour change
  to the game.
- **`sd_hw.h`** — was untouched when this file was first written; the
  CPU-time model (2026-09-13) added one call, `sd_hw_list_done()`, a timing
  sync point declared beside `sd_hw_irq_mark()` and documented there.
- **`mainline.c`** — one line for the same model: `sd_hw_list_done()` after
  `vg_add_halt()` at `L410D`. No ROM instruction, no state change.
- **`tests/probe_attract.c`, `tests/probe_selftest.c`** — the no-op
  implementation of that call, so the probes keep replaying only the
  oracle's recorded schedule.
- **`tools/prof_fit.py`, `tools/prof_pass.py`** — new; observers over the
  oracle that measured `cpu_fits[]`. They write no reference bytes.
- No game module other than the one `mainline.c` line, no `tools/oracle.py`
  change and no `tests/ref*/` file was touched for the pacing model.

---

## 7. Open issues

1. **No player-2 controls.** `plat_inputs` has no P2 fields, so `$0901`,
   `$0903` and `$0905` d7 read 0 and the second ship is dead in the
   two-player games. Game 3 (one player owns both ships through `$0900`)
   is unaffected. The fix is mechanical: add `p2_*` fields to
   `plat_inputs`, bind keys in `plat_win.c`, and fill in the three `case`
   arms in `sd_hw_in1()` — but it changes the platform contract, so it was
   left for a deliberate decision.
2. **Two untranslated ROM routines fire during play.** The self-test run
   caught `SplitRockIntoFragments $6554` (12 calls) and
   `PartSignedNumberExit $67D0` (8 calls) — both still no-op stubs.
   Rocks do not split and the signed arctangent returns an invalid angle,
   so enemy aim is wrong. Neither hangs or corrupts; the game plays.
   These two remain the top of the play-mode backlog.
   (`SinceCannotGetMust`, `RandomFuzz`, `StopFuseSound`, `InitializeComet`, `Inco10`,
   `BellsWistles` did not fire in the scripted run — comets and fuse sound
   are the paths that would reach them.)
3. ~~**The self-test/diagnostics are unreachable**~~ — done 2026-09-01
   (`selftest.c`, `NOTES_selftest.md`).
4. ~~**Audio is silent by instruction.**~~ — the two POKEYs now render
   and stream to the window (2026-09-03; `SOUNDS.md`, `NOTES_platform.md`).
   The interim `plat_pokey_reg` hook that received every write and dropped
   it is gone.
5. **A key press shorter than one frame (~16 ms) can be missed.** The
   backend's key state only updates when WinMain drains the message queue,
   which happens between passes because `sd_app_step()` blocks for the
   whole frame in the two hardware waits. Human presses are 3-12 frames
   long, so this only bites synthetic input (it is why the scripted run
   uses held keys). If it ever matters, the fix is a latch in the backend
   or a `plat_pump()` hook callable from inside the waits.
6. **The LFSR free run is an approximation** (§4): one step per IRQ rather
   than the chip's ~7000. Fine for gameplay, wrong for anything that ever
   wants to model POKEY noise timing.
7. **Gate P (a play-mode oracle capture) still does not exist.** This
   build makes play *reachable and observable*, but nothing here diffs
   in-game frames against the real ROM. Now that the idle IN0 byte is
   known-good, the scripted-coin oracle scenario can be written:
   `("in0_set", 0x3F)` then pulse a coin bit low.

## Addendum: the fps lock

The hardware frame gate is 61.5234 Hz (CLOCK_3KHZ/12/4 - current MAME
derives the same number in src/mame/atari/bwidow.cpp; AAE's "45" is a
legacy declared constant). On a 60 Hz PC panel that beats as one dropped
frame every ~0.65 s. `[main] fps_lock` in sd_win.ini (0 = authentic,
default) underclocks the WHOLE machine - `sd_app_set_fps_lock()` scales
the IRQ tick, the 3 kHz clock and the AVG busy window by one common
factor, as if the 12.096 MHz crystal were slower - so at fps_lock=60 the
game runs 2.48% slow but internally consistent and stutter-free on a
60 Hz panel (set it to the panel's real rate, e.g. 59.94, if needed;
pairs well with vsync=1). The headless self-test and the probes never
call the setter: all oracle-facing timing stays authentic.
