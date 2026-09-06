# Integration wave — link, build, and the run to byte parity

Read `DESIGN.md` (the plan), `CONVENTIONS.md` (the rules)
and `NOTES_oracle.md` (the contract) first. This file records what the
integration wave changed, what the probe actually prints, and what is still
different — with the evidence for each claim.

## Probe results (the numbers, from the probe's own output)

    tests\probe_attract.exe 1
      PROBE: 1 frames run, 1 compared, 1 byte-identical, 0 mismatched bytes
      PROBE: masked separately: 14 bytes in the 6502 stack page $0100-$01FF
      PROBE: pokey writes 563, earom ctl 330, earom data 61, irq services 393
      PROBE: RANDOM reads 2
      STUBS: 8 temporary no-op stubs linked, 0 executed
      PROBE PASSED

    tests\probe_attract.exe 600
      frame 576: 35 mismatched bytes (+14 6502-stack-page bytes, masked)
      PROBE: 600 frames run, 34 compared, 33 byte-identical, 35 mismatched bytes
      PROBE: masked separately: 498 bytes in the 6502 stack page $0100-$01FF
      PROBE: pokey writes 3558, earom ctl 484, earom data 61, irq services 2855
      PROBE: RANDOM reads 1347
      STUBS: 8 temporary no-op stubs linked, 0 executed
      PROBE FAILED (33/34 clean)

**Gate 1: PASSED.** Vector RAM *and* game RAM are byte-identical at the
first captured VGGO.

**Gate N: 33 of 34 captured frames byte-identical** (vram *and* ram). The
34th (frame 576) differs in 35 bytes: 33 in vector RAM and 2 in game RAM
($025A, $037A — one torpedo's Y velocity and Y position). Diagnosis below;
it is sub-routine IRQ interleaving, not a translation error.

Corroborating checksums:

- **IRQ services 2855** — exactly the oracle's 2855 for the same run.
- **RANDOM reads 1347 vs the oracle's 1345.** The LFSR is the port's
  instruction-path checksum (NOTES_oracle.md §1). Logged read-for-read
  (`SD_PROBE_RND=<file>` on the probe, `--trace-random` on the oracle):
  **the first 1345 reads match in value AND in frame number**. The two
  extra C reads are `$4C74` in pass 600, after the oracle's 600-frame run
  had already stopped. The LFSR never desyncs during the compared frames.
- Progression of the total mismatch count as the fixes landed:
  13 395 → 13 361 → 637 → 556 → 47 → **35**.

## Step 1 — the three reported link blockers (all verified, all real)

1. **`expset()` was `static` in display.c.** Confirmed: `objects.c:145`
   externs it and calls it at two sites (ROM `$460C` / `$465D`). Removed
   the `static`, declared `void expset(uint8_t x)` in `display.h`.
2. **`killer_mines` / `motion_update_routine` externs in mainline.c were
   stale** (`void f(void)`). Verified against the listing before changing
   anything: `$40F8 JSR KillerMines` and `$40FB JSR MotionUpdateRoutine`
   are two separate JSRs, but `$517D LDA $0308,X` and `$5193 LDA $02D6,X`
   index with whatever 6502 X `KillerMines` left — so they are X-coupled
   exactly as reported. Externs corrected to `uint8_t killer_mines(uint8_t)`
   / `void motion_update_routine(uint8_t)` and the call site is now
   `motion_update_routine(killer_mines(0))`.
   *The seed is 0, and that is now settled by evidence, not intent:*
   `tests/ref/coverage_attract.md` shows `MotionUpdateRoutine $5174` with
   **2 distinct PCs** over 600 frames — only `$5174 LDA COMTIMER` and
   `$5177 BEQ` ever execute, so `$517D` is never reached in attract and the
   threaded X is inert here. NOTES_objects.md open question 1 is therefore
   *unresolved for play mode* and *proven irrelevant for attract*.
3. **display.c had private `static` copies of `inselo()` and
   `temp3_which_player0()`.** Confirmed. Both were compared line by line
   against `objects.c`'s versions and against the listing (`Inselo $50D5`,
   `Temp3WhichPlayer0 $5C24`, listing lines 2596 and 4372). **They are
   equivalent** — same stores, same order, same branch structure; the only
   differences are cosmetic (`g.vram[0x290+y]` vs `VRAM(A_VROCK1+y)`,
   `sd_vecrom[…]` vs `VROM(…)`, if/else vs the ROM's load-then-overwrite at
   `$5C64`/`$5C6F`, which has no side effects). The display.c copies were
   deleted and `display.c` now includes `objects.h`. No finding.

## Step 2 — the build

`c_src\build_all.bat` (modelled on the
[Omega Race port](https://github.com/tcottrill/Omega-Race-Full-Disassembly-and-C-Port)'s
`build_all.bat`)
compiles every core module + `tests\probe_attract.c` into
`tests\probe_attract.exe`, and `tests\avg_dump.c` + `avg.c sd_vecrom.c
sd_state.c` into `tests\avg_dump.exe` (avg_dump has no hardware seam of its
own, so it must not link the game modules). `/W4 /std:c11`, **warning-free**.
`score.c`, `score_data.c` and `stubs_missing.c` (no longer exists; it was
a staging file) are picked up conditionally so the file keeps working as
those come and go. The `'vswhere.exe' is not
recognized` line from `VsDevCmd.bat` is noise, not an error.

## Step 3/4 — the diffs, and the fixes that closed them

### FIX 1 — `TEMP7` ($15): `Newp2` did not return the 6502 Y it leaves

*Symptom:* frames 1-4 were otherwise perfect; `$0015` read `$00` in C and
`$02` in the oracle from the very first frame.

*Evidence:* `oracle.py --trace-write 0x15` showed the only writer during
attract is `$6FDF STY TEMP7` inside `L80RandomWave0`, called nine times in
one boot pass with Y = 0, 9, 8, 7, 6, 5, 4, 3, 2. The caller is
`NewastStartNewAsteroids_10` (`$5A6A`), whose loop is
`JSR L80RandomWave0 / ORA #$04 / STA $97,X / JSR Newp2 / DEX / BNE`.
Y starts at 0 (`$5A54 LDY #$00`) and thereafter is whatever `Newp2` left:
`Newp2`'s ATSTG path does `TXA / AND #$0F / TAY` at `$597B-$597E`, i.e.
Y = X & $0F — which reproduces 9, 8, 7 … 2 exactly. (Coverage confirms only
that path runs: `Newp2 $5977` has 14 distinct PCs = precisely
`$5977-$5995`.)

*Fix:* `newp2()` returns its exit Y (`x & 0x0F` on the ATSTG path, the
incoming y otherwise — `GetNewVelocity`/`NewRandomVelocityUsing` never touch
6502 Y), and `newast_start_new_asteroids` threads it:
`y = newp2(x, y);`. `objects.h` updated.

### FIX 2 — `$B8,X` read as `$97,X`: the ships' status byte (2 sites)

*Symptom:* from frame 5 the C spawned object `$2F` (a player-1 torpedo,
status `$12`) that the ROM never created, plus ~140 shifted vector-RAM bytes
per frame, growing to 13 361 mismatched bytes over the run. It also called
`SplitRockIntoFragments` six times — a routine `coverage_attract.md` proves
the ROM never enters during attract.

*Evidence:* `--trace-write 0xC6` showed the ROM never writes object `$2F`'s
status after boot. `--trace-pc 0x4C70 0x4C91 0x4C9D 0x4CB5 0x4CC0 0x4CBF`
showed the ROM reaching `$4C91` and immediately leaving via `Fire2` with
A = `$00` — i.e. `LDA $B8,X` found the ship *dead*. The C was reading
`$97,X` (objects `$00`/`$01`, i.e. the velocity seed and a live rock)
instead of `$B8,X` (objects `$21`/`$22`, the two ships).

*Fix (objects.c):*
- `fire_ships_torpedos_20` `$4C91`: `OST(x)` → `OST(x + 0x21)`.
- `move_ship` `$54A7`: `OST(x)` → `OST(x + 0x21)`.
- `move_ship` `$5529` (`STA $B8,X`, the ½-size re-entry picture):
  `OST(x) = 0x02` → `OST(x + 0x21) = 0x02`.

All other `$B8,X` sites in the listing (`$583F`, `$584A`, `$5BC6`) were
checked and were already correct in the C.

This one fix took the run from 13 361 mismatched bytes to 637.

### FIX 3 — `AddPointsToScore` ($5F68) translated (stub removed)

Translated into `score.c` from the listing, BCD through `sd_bcd.h`
(`bcd_adc` / `bcd_sbc`), every RAM store reproduced (TEMPA, PL0SCFLAG,OWNER,
the 3-byte live score `$3A,X`/`$3B,X`/`$3C,X`, TEMP9, NXTBON, `$47,X`,
CMBSCFLAG, CMBSCORE/$0041/`$42`, `$47`/`$48`), declared in `score.h`.
Its first two instructions (`BIT $35 / BMI`) make it an immediate RTS
outside a game, so it is behaviourally inert during attract — and
`coverage_attract.md` shows the ROM never even enters it there. The
`JMP ExtraLife2` tail is a call to `extra_life2(x, 0)`: the 6502 X is
tracked exactly, Y is the caller's and is unknowable here (the same
register-parking gap NOTES_objects.md open question 3 and
NOTES_soundcoins.md open question 1 describe) — flagged in the code.

### FIX 4 — mid-pass IRQ sync points (the interleaving, and how far it goes)

*Symptom (after fixes 1-3):* 4 RAM bytes — `SANGLE`/`SANGLE+1` (`$02A3`/
`$02A4`) and `IANGLE`/`IANGLE+1` (`$03D0`/`$03D1`) — differed by exactly
±2 on 9 of the 34 captured frames, and at frame 548+ the error propagated
into drawn geometry.

*Root cause, measured:* `IANGLE` is INC'd/DEC'd by **every** IRQ, gated on
bits 7 and 5 of `$44` (`$86D4-$86F6`); `$44` is INC'd by the **mainline**,
at `$68FD` (reached from `$4113 JSR UsesTemp1Temp11`). On hardware the
pass's ~4 IRQs are spread through the pass, so only some of them see each
new `$44` value. `oracle.py --trace-pc 0x68FD` measured it directly:
**2 (sometimes 3) IRQs fire after `INC $44` and before the next VGGO.**
The probe serviced *all* of a pass's IRQs at the frame gate, i.e. all after
the previous pass's `INC $44`, so each new `$44` value was applied to 2
ticks too many — exactly the observed ±2.

*Fix:* extend the existing "replay the machine's recorded IRQ schedule"
mechanism from one sample per pass (the VGGO, `tests/ref/vggo_sched.txt`)
to several. `oracle.py --irq-marks PC` (repeatable) records the irq_count at
each execution of a chosen mainline PC into `irq_marks.txt`; the probe
advances machine time to that count at the matching point via a new seam
call `sd_hw_irq_mark(point)` (`sd_hw.h`). **It never runs an IRQ the
recorded schedule did not** — it only moves some of a pass's IRQs from the
gate to where the real machine took them. Four sync points, each a real ROM
address and each a no-op in the real build:

| point | ROM | why |
|---|---|---|
| `SD_IRQ_MARK_MOTION` 0 | `$40FB` | Moti20/Pictur draw from SANGLE |
| `SD_IRQ_MARK_FRAME`  1 | `$4113` | `UsesTemp1Temp11` → `INC $44` |
| `SD_IRQ_MARK_SHIPS`  2 | `$40E5` | `MoveShip` integrates thrust from SANGLE |
| `SD_IRQ_MARK_FIRE`   3 | `$40D7` | `Fire3` launches along `ANGLE,X` = SANGLE |

Schedule file: `c_src\tests\sched\irq_marks.txt`, regenerate with

    py c_src\tools\oracle.py attract --frames 600 --outdir <scratch> \
        --irq-marks 0x40FB --irq-marks 0x4113 --irq-marks 0x40E5 --irq-marks 0x40D7

then copy `irq_marks.txt` to `c_src\tests\sched\`. If the file is missing the
probe says so and falls back to the old gate-only replay. Effect measured:
556 → 47 → 35 mismatched bytes, and all 36 IANGLE/SANGLE bytes gone.

## What is still different

### (a) The one documented mask: the 6502 hardware stack `$01E1-$01FF`

498 bytes over the 34 frames (13-15 per frame). **Justification:** the C
port has no 6502 hardware stack — subroutine linkage lives on the C stack —
so this region holds the oracle's return addresses and PHA-saved registers,
which the C port cannot and should not reproduce. The ROM sets `SP = $FE` at
reset (`$8040 LDX #$FE / TXS`) and the stack grows down; measured across all
34 captured frames it reaches no lower than **`$01EF`**, so `$01E1` is the
boundary with margin.

**Correction (orchestrator, post-wave).** This mask was first written as the
whole page `$0100-$01FF`, justified by "the listing contains zero operands
in page 1". That justification is **false**, and the wide mask was unsafe.
Page 1 below `$01E1` is *data* the game reads constantly:

| cell | address | used by |
|---|---|---|
| `$0122` | `$0122` | initials table (`SetUpInitialsHigh` writes `$0118,Y` at boot) |
| `$015E` | `$015E` | |
| `$016D` | `$016D` | EAROM buffer |
| `EACS`..`PLAYTIME` | `$018D-$0196` | EAROM state machine |
| `ONTIME` | `$018E` | **read by `irq.c`** every 4 seconds (BCD bookkeeping) |
| `$0197`/`$019B`/`$019F`/`$01AF` | `$0197`-`$01AF` | bookkeeping counters |
| `THRENG` | `$01E0` | highest data alias in `spaceduel_defines.asm` |

Verified empirically: dumping the C port's RAM for all 34 compared frames
and diffing page 1 against the reference shows differences at **exactly 16
addresses, `$01EF`-`$01FE`**, and nowhere else. So all of that data region
already matched — the wide mask was harmless in effect, but it would have
silently swallowed any future regression in the EAROM, initials or
bookkeeping code. The boundary now sits just above `THRENG`, that data is
**compared**, and its matching is part of what proves `earom.c` correct.
Re-running with the narrowed mask gives identical results (33/34, 35
mismatched, 498 masked).

The probe **counts and reports masked bytes on their own line**, never hides
them, and does not let them count against a frame being byte-identical. This
is the only mask in the harness.

### (b) Frame 576: 35 bytes, sub-routine IRQ interleaving (not fixable at
the mainline level)

RAM: `$025A` (YINC + `$28`) and `$037A` (OBJYL + `$28`) — one player-0
torpedo's Y velocity and Y position. vram: 33 bytes of ship/torpedo geometry
that follow from it.

*Evidence chain:*
1. `--trace-write 0x25A 0x37A`: that torpedo's Y velocity was written once,
   in pass 568, by `$4D1D STA YINC,Y` (`Fire3_40`) — value `$D5`; the C has
   `$D3`. Its **X** velocity (`$0228`) matches.
2. `Fire3` reads the launch angle **twice**: `$4CCA LDA ANGLE,X` for the X
   component and `$4CF5 LDA ANGLE,X` for the Y component. `ANGLE,X` with
   X = 2/3 *is* `SANGLE`/`SANGLE+1`, which the IRQ rewrites every tick
   (`$8709 STA SANGLE`).
3. `--trace-pc 0x4CCA 0x4CF5` + `--trace-write 0x2A3` for pass 568:
   the X read happened at **irq 2673**, the Y read at **irq 2674**, and the
   IRQ in between did `STA SANGLE = $94` (one rotation tick). The ROM
   launched that torpedo with two different angles, one per axis.

A probe that can only synchronise at mainline call boundaries cannot place
an IRQ *inside* `Fire3`. The same mechanism was also observed splitting the
two `Shpdisplays` calls inside `Moti20` (pass 555: ship 0 drawn at irq 2609,
ship 1 at irq 2610), which is what produced the frames 556-558 vram-only
divergence — vram differed while RAM and the LFSR were byte-identical.

Closing this would need a cycle-cost model in the C port so IRQs could land
at the right instruction, not merely the right routine. That is a real
piece of work and a deliberate non-goal of this wave; DESIGN.md's timing
section already names IRQ-vs-mainline interleaving as *the* known fidelity
risk. **It is reported, not masked.**

## Temporary stubs — `c_src\stubs_missing.c` (no longer exists in the tree)

Eight ROM routines are referenced by translated modules but have no
implementing module on disk. Each is a clearly-marked no-op carrying its ROM
label and address:

| routine | ROM | executed during the 600-frame run? |
|---|---|---|
| `SplitRockIntoFragments` | `$6554` | **no** |
| `PartSignedNumberExit`   | `$67D0` | **no** |
| `SinceCannotGetMust`     | `$6AA5` | **no** |
| `RandomFuzz`             | `$6B45` | **no** |
| `StopFuseSound`          | `$6B57` | **no** |
| `InitializeComet`        | `$6B68` | **no** |
| `Inco10`                 | `$6B6D` | **no** |
| `BellsWistles`           | `$768D` | **no** |

**Zero stubs executed** — the probe prints
`STUBS: 8 temporary no-op stubs linked, 0 executed`. This is enforced, not
assumed: every stub bumps a counter and writes a loud line to stderr on its
first call. It also agrees with `tests/ref/coverage_attract.md`, which shows
the real 6502 never entered any of these eight during attract. So no stub
touched any compared frame, and none of the numbers above is invalidated by
one. (Four more were stubbed here mid-wave and have since landed for real:
`UpdateHighScoreTable $6614`, `Display4Names $7529` and `AddPointsToScore
$5F68` in `score.c`, `UpdateInfoAtEnd $893E` appended to `earom.c`.)

`RandomFuzz` deserves a note: the ROM reads `RANDOM ($100A)` there, so if it
ever *did* execute it would desync the LFSR as well — which is a second
reason the counter matters.

## Changes to `tools/oracle.py`

The hardware model is **untouched** (verified: the instrumented oracle
re-run reproduces all 68 overlapping `tests/ref/` dumps byte-for-byte).
`tests/ref/` was not regenerated. What was added is pure observation, all
off by default:

- `--trace-write ADDR` (repeatable) — log frame/irq/PC/value for writes.
- `--trace-pc ADDR` (repeatable) — log frame/irq/A/X/Y at a PC.
- `--trace-random` — log every RANDOM read (and `RANDOM reads: N` is now
  always printed).
- `--trace-out FILE`, `--trace-max N` — where the traces go.
- `--capture-range A:B` — also dump every frame in a range (use a scratch
  `--outdir`; never regenerate `tests/ref` with it).
- `--irq-marks PC` (repeatable) — write `<outdir>/irq_marks.txt`, the
  irq_count at each execution of PC (see FIX 4).

## Changes to `tests/probe_attract.c`

Diagnostics and reporting only — no change to what counts as a match except
the single documented stack-page mask above:

- diff listing raised from 8 to 64 lines per section.
- `SD_PROBE_DUMP=<dir>` — dump the C port's own vram/ram per compared frame.
- `SD_PROBE_RND=<file>` — log every LFSR read; `RANDOM reads` in the summary.
- `sd_hw_irq_mark()` implementation + `tests/sched/irq_marks.txt` loading.
- `sd_stubs_report()` call in the summary.
- stack-page bytes counted and printed separately (see (a)).

## Files touched

- new: `build_all.bat`, `stubs_missing.c` (no longer exists in the tree),
  `NOTES_integration.md`,
  `tests/sched/irq_marks.txt`
- fixed: `objects.c` (+`objects.h`), `mainline.c`, `display.c`
  (+`display.h`), `score.c` (+`score.h`), `sd_hw.h`
- instrumented: `tools/oracle.py`, `tests/probe_attract.c`

## Open work

1. **A cycle-cost model** for the C port is the only way past frame 576 —
   see (b). Until then, three sub-routine sites are known to race the IRQ:
   `Fire3`'s two `ANGLE,X` reads, `Moti20`'s per-object `Pictur` calls, and
   `MoveShip`'s pair.
2. **Translate the eight stubs** so play-mode scenarios become possible;
   `PartSignedNumberExit $67D0` (the signed arctangent) and
   `SplitRockIntoFragments $6554` are the two that real gameplay hits hardest.
3. **Gate P (play)**: an oracle scenario with scripted coin + inputs, then
   the same probe.
