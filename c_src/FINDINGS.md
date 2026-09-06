# Space Duel: what the C port proved, and what it found

Written 2026-08-26, at the end of the first build-out. This is the durable
record — what the exercise set out to do, what it established, and the
things it turned up that were not knowable from the disassembly alone.

Companion docs: `README.md` (build and run), `DESIGN.md` (architecture),
`NOTES_*.md` (per-subsystem detail).

---

## 1. The claim, and the evidence for it

**The disassembly is correct.** Not "assembles to the right bytes" — that
was already known — but *means* the right thing. The C port is an
independent re-derivation of the program's behaviour from the annotated
listing, and it reproduces the real machine's state exactly:

```
tests\probe_attract.exe 1     -> PROBE PASSED (0 mismatched bytes)
tests\probe_attract.exe 600   -> 34 compared, 33 byte-identical,
                                 35 mismatched bytes (all on frame 576)
```

Both **vector RAM** (the display list the AVG actually draws) and **game
RAM** are byte-identical to the real ROM on 33 of 34 captured frames, over
600 frames of attract mode. Supporting invariants that all agree:

- **IRQ services: 2855 = the oracle's 2855.**
- **POKEY LFSR read-for-read** (1345/1345 in the compared window). This one
  is the sharpest instrument in the project: the LFSR advances *only* on a
  RANDOM read, so its position is a checksum over the instruction path. A
  port that takes one wrong branch reads RANDOM a different number of times
  and diverges immediately.
- **Every executed PC exists in the listing** — 2709 distinct PCs, 0
  disagreements. The oracle and the disassembly never contradict each other.

### Why this is stronger than byte-verification
`../disasm/NOTES.md` already records the trap: the AVG decoder was once
sign-magnitude (the wrong convention), and byte-level verification *never
caught it*, because decode and re-encode shared the same error and
round-tripped perfectly while producing nonsense values. Byte fidelity is
not semantic fidelity. The probe closes that gap from the other side: the C
port never round-trips anything, it re-derives the bytes from meaning.

### What is NOT proven
Attract mode exercises 152 of 464 named routines. Everything reached only
by play — scoring, high-score entry, rock splitting, most of the enemy AI —
links and stays quiet, but is verified only against the listing, not against
the machine. **Gate P (a play-mode oracle scenario with scripted coin and
inputs) is the single highest-value piece of remaining work.** `app_loop.c`
has now settled the idle IN0 byte that scenario needs (§4 below).

---

## 2. Bugs the differential harness caught

Every one of these passed code review and would have been invisible without
byte-level differential testing against the real machine.

| bug | effect | how it surfaced |
|---|---|---|
| `objects.c` read `$B8,X` as `$97,X` at 3 sites | confused ship slots (`$21/$22`) with object slots (`$00/$01`) — **the port fired a torpedo the ROM never fired** | 13,361 → 637 mismatched bytes from this one fix |
| `Newp2` ($5977) didn't return its exit Y | `TEMP7` stuck at 0 forever | oracle write-trace on `$15` showed the ROM's Y sequence 0,9,8,…,2 |
| `explosion()` declared with no args | wrong values parked in `TEMPA`/`TEMPB` | cross-module signature audit (see §3) |
| `expset()` declared `static` | link failure | integration |
| stale `killer_mines`/`motion_update_routine` externs | X not threaded between them | integration; the ROM couples them via `$517D LDA $0308,X` |

The first one is the headline: it is a *plausible* misreading of an indexed
address that produces a game that looks like it works.

---

## 3. Structural findings about the ROM

**Registers are part of the call contract, everywhere.** 6502 routines here
communicate through live A/X/Y and carry far more than through named cells.
Two examples that forced API changes across modules:

- Sound triggers must take `(x_in, y_in)`: `Badhab` ($72FA) parks the
  caller's live X and Y into `TEMPA`/`TEMPB`, which are oracle-visible. A
  "clean" `void gates(void)` signature is *wrong*.
- `InitializeComet`'s X clobber, `Newp2`'s exit Y, `GetRotationColorCode`
  returning Y=2 which its caller then uses as a list offset — all load-bearing.

The convention that prevents this: derive every routine's protocol from **all**
its call sites before translating, and document it above the function.

**Deliberate clobbers are real behaviour.** `DoLowOnesEvery` clobbers the VG
list pointer while rewriting the eight persistent rock stubs at `$2290-$22C3`.
Reproducing that faithfully was necessary for parity.

**Base-1 table addressing appears more than once.** `L80RandomWave0` indexes
`$6FB8,X` where `$6FB8` is the `RTS` opcode ending the previous routine;
`objects.c` has the same pattern at `$5967`. Tables must be extracted from
the binary, not transcribed from the listing, or these bytes are lost.

---

## 4. Hardware findings

**The AVG memory map is flat — no mirror.** The `$E401` word `Poweron`
seeds at `$2000` is **dead code**: `LswVectorAddress` ($6C96) overwrites it
with `$E001` (JMPL → CPU `$2002`) before the first VGGO ever fires. The
double buffers are `$2002`/`$2402`, toggled by `EOR #$02` on `$2001`.
Confirmed three ways: both reference AVG implementations (`aae_avg.c`,
`mame_late_avgdvg.cpp`) walk a flat byte offset; the seed is provably
overwritten pre-frame-1; and walking all 34 captured frames shows every
frame HALTing cleanly with no fetch ever entering the ship-picture region.

**Space Duel does not run at 45 FPS.** Cycle-true AVG timing — traced
through the real state PROM (136002-125) and validated cycle-for-cycle
against a port of the reference state machine on all 34 frames — puts
attract frames at **11.3–15.9 ms**, all under the 16.26 ms `$33` frame gate,
i.e. **~61.5 fps**. The measured playable build agrees: 61.5 fps in attract,
sagging to ~59 on heavy screens where the list crosses the gate. AAE's "45"
is a *declared driver constant* (`AAE_DRIVER_VIDEO_CORE(45,0,…)`), not a
measurement. Whether play-mode lists routinely cross the gate is still open
and answerable with a play capture.

**The coin/slam polarity trap.** Idle IN0 is `0x3F` (plus HALT/3 kHz), not
`0x50`. With d3 low the ROM reads *slam tripped*, reloads `$0025 = $F0`
every IRQ and wipes `$2A-$2F` — so no coin can ever register. This is
exactly why the oracle's attract scenario runs forever coin-free (correct
for attract) and why the first playable build would have ignored every coin.
One byte separates "attract screen" from "working cabinet".

**Frame pacing is emergent.** Both hardware waits are implemented for real:
`sd_wait_vghalt()` blocks for the cycle-true draw time of the list just
issued, `sd_wait_frame_gate()` consumes `$33` bits. Nothing is hard-coded,
so the frame period falls out as `max(gate, draw time)` — and because `$33`
is a shift register of *pending* ticks, an overrun frame is repaid by the
next ones, giving the authentic 4.6–19.9 ms swing in play.

**The 6502 stack page is not all stack.** Page 1 below `$01E1` is *data*:
the initials table (`$0122`), the EAROM buffer and its state machine
(`$016D-$0196`), the bookkeeping counters (`$0197-$01AF`) and `THRENG`
(`$01E0`). Measured stack low-water mark across all frames is `$01EF`. An
early blanket `$0100-$01FF` mask — justified as "the listing has no page-1
operands", which is false — would have hidden any regression in the EAROM
and initials code. Narrowed to `$01E1-$01FF`; the data below it is compared
and matches, and that matching is a large part of what proves `earom.c`.

---

## 5. Verification techniques worth reusing

- **A software oracle beats a hardware rig.** The Omega Race port needed
  real hardware for differential testing. Here, `tools/oracle.py` runs the
  actual ROM image and dumps RAM + vector RAM at every VGGO. It is
  re-runnable, scriptable, instrumentable (`--trace-write`, `--trace-pc`,
  `--irq-marks`) and diffable in CI.
- **Replay the machine's own schedule.** IRQ timing is recorded per frame
  and replayed, rather than assumed. When frame-gate-only replay proved too
  coarse, the fix was to record *more* sample points (four mid-pass sync
  points), not to fudge the comparison.
- **Exhaustive verification where the domain is small.** The multiply
  routine was checked against all 65,536 input pairs; the sine tables
  against the mathematical ideal across the full circle (±0.5 LSB).
- **Cross-check generated data against the listing.** Every extracted table
  is byte-compared with the `.byte` lines; deliberate exceptions (the
  base-1 code bytes) are reported, not silently absorbed.
- **Never mask to make a diff disappear.** The one mask in the harness is
  counted, printed on its own line, justified in writing, and was narrowed
  the moment its justification was found wanting.

---

## 6. Process finding: parallel agents on a shared oracle

Roughly a dozen agents translated the ROM concurrently, partitioned by
module with strict file ownership. What made it work:

- **A byte-exact acceptance test that no agent could argue with.** Opinions
  don't survive contact with a 2 KB diff.
- **Written conventions with teeth** (`CONVENTIONS.md`): one C function per
  ROM routine with its address, reproduce every RAM store, derive protocols
  from all call sites, extract tables rather than transcribe them.
- **Agents catching each other.** The sound module's register-parking
  discovery forced the fix to `display.c`'s `explosion()` signature. The
  objects author found three defects in *other* modules while integrating.
- **Agents declining bad instructions.** Told to fix a store-ordering bug in
  `initialize_score_headings`, the display agent checked the listing, found
  the code already correct, and said so rather than "fixing" working code.

The failure mode to watch: an agent reporting a plausible justification that
is actually false (the stack-page mask). The defence is the same as for the
code — check the claim against the source, don't accept the summary.

---

## 7. State of play

**It plays.** `sd_win.exe` boots, runs attract at 61.5 fps, takes a coin,
starts a game on coin → SELECT → START, and the ship rotates, thrusts and
fires from the keyboard. High scores persist to `sd_c.nv` through a real
64-byte ER-2055 EAROM image. Verified by screenshot, by log, and by a
headless scripted game that asserts credits, lockout, game flag, angle,
velocity, torpedo slots and NVRAM round-trip.

Open, in priority order:

1. **Shields don't work / both buttons fire** — the hardware decode and our
   seam agree; needs empirical diagnosis with the headless harness.
2. **Eight stubbed routines**, three of which execute in play: rock
   splitting, the arctangent enemies aim with, and comet spawn.
3. **No player-2 controls** (platform contract lacks P2 fields).
4. **Gate P**: the play-mode oracle scenario — the biggest remaining
   proof, and now unblocked.
5. ~~Self-test/operator screens (`AS2TST` untranslated)~~ — translated and
   oracle-clean 2026-09-01 (`NOTES_selftest.md`); audio (deferred).
