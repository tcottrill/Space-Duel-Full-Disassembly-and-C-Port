# Space Duel C port — the self-test (AS2TST)

`selftest.c` is the translation of Owen Rubin's AS2TST module: the power-on
diagnostics ($8110-$8636), the bookkeeping screen ($89B9-$8C61 with its
message tables at $8CEF) and the signature-analysis bench mode ($8D33).
It is proven the same way as everything else in `c_src/`: three oracle
scenarios, three probes, **every captured frame byte-identical in both
vector RAM and game RAM** (256 of 256 frames across the three), with the
attract probe unchanged at its 33/34.

## 1. What the real PCB does (settled from the listing, not from an emulator)

There are two ways into test mode and three ways out, and only **one** of
them involves the watchdog:

| event | ROM path | reset? |
|---|---|---|
| SELF TEST switch closed while the game runs | `Start2` checks IN0 d4 every frame (`$4015 LDA HALT / AND #$10`) and `JMP AllStopPlease` ($8A1D): the **bookkeeping screen** | no — a plain jump; RAM survives (that is how the screen can show the game just played) |
| SELF TEST switch closed at power-up | `Poweron $8086` checks d4 and `JMP BeginningPattern` ($8110): RAM marches, ROM checksums, POKEY/EAROM checks, then `MainLineDiagLoop` ($8590), the **six diagnostic screens** | no — it *is* the reset code |
| switch opened on the bookkeeping screen | `$8C1D`: clear `$44/$45/NROCKS/SAUMIN`, `JMP Pwron` ($68CA, the warm start) | no |
| switch opened in the diagnostics | `$860E` → `WatchDogResetExit $8618: BNE $8618` — a deliberate spin with **no `STA $0D00`** in it, so the board's watchdog times out and resets the CPU, which now boots the game | **yes, the hardware watchdog** — the only watchdog reset in test mode |
| START + SELECT on the bookkeeping screen with option 0 showing | `OptionSelected $8CA6` RTS-jumps through `DoSelfTest $8C9E`; entry 0 is `$803E` → **`$803F`, the RESET vector**, i.e. a software jump to the reset code. With the switch still closed it lands in the full diagnostics — the operator's way from the bookkeeping screen to the diagnostic screens without a power cycle | a *software* restart, not the watchdog |

So: "entering test mode" never resets anything on the real PCB. MAME's F2 is
the same switch (a toggle in the emulator's UI); pressing it in-game shows the
bookkeeping screen, exactly as the cabinet's switch does.

The C port names both restarts `sd_hw_reset()` (sd_hw.h): the seam runs
`sd_boot()` again, which is what the CPU does after either event. The
watchdog's own timeout delay is not modeled; the restart is immediate.

## 2. Layout and the frame model

One C function per ROM routine, ROM address in the comment, exactly as the
other modules. The tables come from `tools/gen_selftest_data.py`
(cross-checked against the listing's `.byte` lines, 191/198 — the seven
non-`.byte` bytes are the `Sftjsr` RTS table, which the listing shows as
instructions). The ROM's own bytes for the checksum loop and the
signature-analysis copies come from `sd_progrom.c` (`tools/gen_progrom.py`,
$4000-$8FFF, verified against the ROM set and the 64K image,
`../disasm/build/spacduel_64k.bin`, built by `disasm/gen_from_roms.py`).

The frame model is `mainline.c`'s: one call = one pass of one loop = one
VGGO. The self-test has three infinite loops the CPU can be parked in (St2,
MainLineDiagLoop, the signature-analysis loop), and *which one* is program
counter state, not RAM — it is the single piece of state this module keeps
outside `g`: `sd_cpu_loop()`, reset by `Poweron`. `sd_mainline_frame()`
asks `selftest_frame()` first; when the CPU is in a test loop, that runs the
pass and the mainline does nothing.

Entry routines run the loop prologue and, where the ROM falls straight into
the loop body, its first pass (`all_stop_please()` ends by running the first
St2 pass — the ROM's `AllStopPlease` falls into `St2`). `beginning_pattern()`
runs everything up to `Ok2 $82CF JMP MainLineDiagLoop` and parks.

Two seam calls were added to sd_hw.h for the loops' hardware waits:

- `sd_wait_3khz(n)` — `$8592`, n × {`BIT HALT/BPL`, `BIT HALT/BMI`}: the
  diagnostics' frame timer (25 periods ≈ 8.33 ms). app_loop.c computes the
  exact edge from the 3 kHz model it already had for IN0 d7 and waits for
  it; the probe replays the IRQ schedule there.
- `sd_hw_reset()` — see §1.

## 3. Faithfulness notes (what the listing forced, and the two things it does not say)

- **Every store is reproduced**, including the marches': the full march
  (`L04`) writes $11, $22, $44, $88 into every cell of pages $01-$03 and
  $20-$27 and leaves **$88** there; `EorCksumRoms` clears pages 1-3 again but
  nobody clears vector RAM, so the diagnostics build their lists over a
  $88-filled vector RAM. The probe's vram diffs see exactly that.
- **The ROM checksums are computed, not assumed.** Each 4 KB ROM is EOR'd
  seeded with its index (`$825E TXA`), the 2 KB ship-picture ROM seeded with
  $FF and stored through the zero-page wrap of `STA $F1,X` into `$F0`
  (BGSHEN = AS2TST's `PNTTBL`). Atari built the ROMs so all seven come out 0;
  the generator prints them and the headless run checks them.
- **Register protocols derived, not guessed.** The three POKEY POTGO strobes
  in `CenterBeam`/`Optn2` store "whatever A holds"; tracing `SaveCFlag` and
  `AddY1ToVector` shows that is always the list pointer's low byte (BLUE), so
  that is what is written. The two `SetVectorGeneratorScale` calls in `St2`
  take Y from the previous routine: 3 after `UpdownVectorUpsideDown`
  (`AddVectorToVector` exits through `AddY1ToVector` with Y = 3), 1 after
  `Add2WordsToVector`. `Swtst`'s `ADC #$40` carries are provably 0 (the
  gathered byte never has its top bit set before the last `ROL`).
- **`ASL OPTNA1` / `ASL GAMSEL`** in `Swtst` are read-modify-writes of input
  addresses; the oracle logs the write-backs as "misc writes" to `$0905/$0906`
  and they reach nothing. Dropped, noted.
- **Deliberately NOT translated:** the RAM-error reporters
  (`BeginningPattern_5 .. NoiseLowerNibbleStatus` $8141-$8185, `L04_20 ..
  NoWtchdgdog` $81C3-$8243) and the VGROM alarm's *effect* beyond its two
  POKEY writes. They count beeps for a failed memory chip; the port's RAM is
  the host's and cannot fail those compares. Their existence and addresses
  are documented in `selftest.c`'s header.
- **The signature-analysis `BRK` ($8D56).** `XYSIG.MAC` (in Atari's source
  archive) labels it "IF SELF TEST SWITCH IS TURNED OFF, EXIT". On this
  board the BRK vector is the IRQ handler ($FFFE = `$8639`), which has no
  B-flag check: it runs and RTIs to `$8D58` — the `$00` operand of
  `LDA #$00` — a second BRK, whose RTI lands on `$8D5A STA BLACK` with
  A = $10. So on the real PCB the switch-off path is
  two IRQ services and BLACK = $10 (which, after the three `ROL BLACK`, makes
  the pattern index $80|jumpers and the table reads run off the end of the
  tables into the following code bytes — read from `sd_progrom` exactly as
  the ROM would). The mode never exits; Atari's intent did not survive the
  vector table. The port reproduces the hardware. The oracle treats BRK as
  fatal, so this mode has no reference frames; it is translated from the
  listing and reviewed, not diffed.

## 4. Verification

Three scenarios in `tools/oracle.py` (their input scripts are written to
`<refdir>/scenario.txt` and replayed by the probe, so the switch timing is
the oracle's, not a copy):

| scenario | frames | what it covers | result |
|---|---|---|---|
| `selftest` | 440 | attract → switch on (frame 100) → bookkeeping; SELECT ×4 through the options; START+SELECT on option 0 → **software reset** → power-on diagnostics with the switch still on; a shield+fire closure shown on the switch line; DIAG STEP through all six screens (OBJ 2→4→6→8→$A→wrap to 2); SELECT on the crosshatch (color switch) | **122/122** byte-identical |
| `selftest_exit` | 180 | attract → switch on (60) → bookkeeping → switch off (120) → `Pwron` → attract | **57/57** |
| `selftest_boot` | 260 | switch on at RESET (coins idle high): the marches from cold, checksums, POKEY RANDOM (the 4 reads the oracle counts), EAROM, all six screens | **77/77** |

    tests\probe_selftest.exe 440 tests\ref_selftest
    tests\probe_selftest.exe 180 tests\ref_selftest_exit
    tests\probe_selftest.exe 260 tests\ref_selftest_boot
    tests\probe_attract.exe  600                           (still 33/34)

Two new mid-pass IRQ sync points were needed (the same mechanism
`probe_attract` already uses, `oracle.py --irq-marks`, now six PCs — sd_hw.h
lists them):

- point 4, `$8C24` (bookkeeping exit): IRQs before the `$44 = 0` store still
  rotate IANGLE by `$44`'s old bits; replaying them after it left
  `IANGLE/SANGLE` two counts off.
- point 5, `$803F` (the restart): IRQs the oracle took between the VGGO and
  the restart decremented a TOTOBJ the restart then wiped; replaying them
  after the wipe left `TOTOBJ/$33` four counts off.

Both were 2-4 byte, single-cause diffs that the probe reported and the marks
removed; nothing in `selftest.c` changed for them. The first probe run
(before the marks were recorded for these refs) also showed the attract
portion's known four angle cells — the coarse gate-only replay — which is
why `probe_selftest` loads `irq_marks.txt` from its ref dir.

RANDOM read counts match the oracle where the run ends on a VGGO
(229/229 `selftest`, 4/4 `selftest_boot`); `selftest_exit` shows 275 vs 273
because the probe finishes the Start2 pass that the oracle's last VGGO cut
short (two reads in that pass's build). Not a divergence.

Headless (`tests\sd_selftest.exe`) has a new phase driving the **app loop's**
side — F2 latch, `sd_wait_3khz`, `sd_hw_reset` — through F2 → bookkeeping →
option 0 → diagnostics → DIAG STEP → F2 → game. It passes.

## 5. Using it

| key | line | what |
|---|---|---|
| **F2** | host toggle of IN0 d4 | press once in-game: the bookkeeping screen; press again: back to attract. Held while the game starts: the power-on diagnostics |
| **9** | the cabinet's SELF TEST switch, held | same line, momentary |
| **F1** | DIAGNOSTIC STEP (IN0 d5) | hold ~3 frames in the diagnostics: next screen (Cocktail status → picture → sound/scale → color bars → crosshatch → status) |
| **7** (SELECT) | GAMSEL d7 | bookkeeping: each release steps the option (message under PUSH START & SELECT); crosshatch: held, steps the box color |
| **1** + **7** | START + SELECT | bookkeeping: execute the option — 0 restart (→ diagnostics while F2 is on), 1 clear scores, 2 clear times, 3 clear both |
| F1 held + 7 | DIAG STEP + SELECT | diagnostics: signature analysis (a black screen with the upright jumpers; no way out but F2… which, see §3, the hardware ignores — quit the app) |

Timing on the port, as on the hardware: the bookkeeping screen has no frame
gate — it re-triggers the AVG as soon as it halts, and its ~660-segment list
takes ~22 ms to draw, so it runs at ~45 Hz, AVG-bound. The diagnostics run on
the 3 kHz timer, 8.33 ms per pass, and their lists are short, so ~120 Hz.
Leaving the diagnostics reboots: `boot_fast` fast-forwards the 1.58 s EAROM
warm-up the same way power-on does (NOTES_playable.md), so it is instant on
the wall clock.

## 6. Open

- Signature analysis is translated but has no oracle (BRK), see §3.
- `plat_inputs` still has no player-2 or cocktail lines, so the switch line of
  the status screen shows those as 0, and the cocktail 'C' / flip paths are
  reachable only by a change to the platform contract.
- The watchdog timeout delay before the diagnostics exit is not modeled.
