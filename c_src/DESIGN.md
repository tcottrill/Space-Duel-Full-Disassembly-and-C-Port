# Space Duel — C source port: design

Template: the [Omega Race port](https://github.com/tcottrill/Omega-Race-Full-Disassembly-and-C-Port).
Goal: **prove the disassembly** in `../disasm/` by translating the program
ROM to C and demonstrating, frame by frame, that the C version produces the same
machine state as the real ROMs.

## What we have that Omega Race did not

- A byte-exact annotated disassembly with Atari's own comments (85% source
  attribution), already re-encoded to 0 mismatches against the ROM set.
- A working mini 6502 simulator, written for bench tests of the board, that runs
  the real 64K image (`../disasm/build/spacduel_64k.bin`, built by
  `disasm/gen_from_roms.py`).
  Extended into `tools/oracle.py`, it is the differential-test rig: run the real
  ROM in software, snapshot RAM + vector RAM at every VGGO, and byte-diff the C
  port against it. Omega Race needed real hardware for this; here the oracle is
  a script.

## Architecture (mirrors Omega Race)

- Platform-agnostic core: game modules translated one C function per ROM routine,
  each carrying its ROM address. `platform/` seam identical in shape to Omega
  Race's (`plat_video_line`, `plat_input_poll`, `plat_sample_*`, NVRAM blob).
- The display pipeline is the real one: translated VG-utility routines
  (`VGUTR2`, $8E42) write **actual AVG bytes** into a real 2 KB vector RAM
  through the real list pointer (zp $01/$02), and `avg.c` — a C transcription of
  the AVG state machine — walks vector RAM + vector ROM and emits line segments.
  What reaches the screen is what the beam drew.
- No 6502 core at runtime. The oracle (Python) is a build/test-time tool only.

## The one deliberate departure: state model

Omega Race used `omega_state g` with named struct fields. Space Duel phase 1
uses the machine's real memory layout:

```c
typedef struct {
    uint8_t ram[0x400];    /* $0000-$03FF: zp + stack + game RAM */
    uint8_t vram[0x800];   /* $2000-$27FF: real AVG display-list bytes */
    /* ... hardware-seam shadows (POKEY regs, EAROM, outputs) ... */
} sd_state;
```

with every named RAM symbol from `spaceduel_defines.asm` exposed as a macro
alias (`#define SDELAY  (g.ram[0x26D])`). Rationale:

1. **Byte-diffability.** The whole point of phase 1 is proof. With raw arrays,
   `probe` harnesses can diff the entire 1 KB RAM + 2 KB vector RAM against the
   oracle after every frame. A struct would need a serialization map and would
   fight 6502 idioms.
2. **6502 idioms translate exactly.** Indexed runs that span several symbols
   (`LDA GENDING,X` across both players' BCD scores), `(zp),Y` pointer walks
   (EAROM buffer copies, initials entry), and the VG list pointer all work
   unchanged against a flat array.
3. It is a phase, not the endpoint. Once parity is proven, refactoring toward
   named fields can proceed module by module with the diff harness as a safety
   net (this is the order Omega Race effectively followed: prove, then polish).

## Timing model

- Machine time = the 246.09 Hz IRQ (1.512 MHz / 6144 cycles, per the AAE
  `bwidow.cpp` driver: `timer_set(TIME_IN_HZ(246))`).
- The mainline (`Start2`, $4012) free-runs: waits for VG HALT, then for the
  ~61.5 Hz gate ($33, incremented by every 4th IRQ). One mainline pass = one
  displayed frame; nominally 4 IRQs per frame.
- IRQ-vs-mainline interleaving is the known fidelity risk (cells like INTRPT,
  SECOND, GTIME, IANGLE advance per IRQ). The oracle logs the IRQ count at each
  VGGO so probe builds can replay the exact schedule; cells that remain
  interleaving-dependent get a documented diff mask, never a silent one.
- **Real-hardware pacing is NOT 61.5 Hz**: MAME runs Space Duel at ~45 FPS
  (confirmed 2026-08-26), i.e. on hardware the $401F VG-HALT wait
  regularly blocks past the frame gate — the AVG draw time dominates. The
  oracle's fixed 4000-cycle HALT model (~60 fps) remains the *diff contract*
  only; the playable build paces frames from avg.c's accumulated draw-time
  model (AAE 1500 ns/unit), Omega Race-style, and should land near 45 fps.

## Verification gates

1. **Gate V (vector ROM/AVG):** `avg.c` renders known shapes (CHR_* glyphs,
   ships) with segment output matching `../disasm/shapes_preview.html`
   facts (two's-complement deltas, SCAL complement rule, z==1 = STAT intensity).
2. **Gate 1 (first frame):** vector RAM at the first VGGO of attract mode,
   byte-identical to the oracle.
3. **Gate N (attract loop):** first ~600 attract frames vram-identical; RAM
   diff clean modulo the documented mask.
4. **Gate P (play):** coined game with scripted inputs replayed identically in
   oracle and C build (oracle injects the same input bytes).
5. Every later module lands with a probe that diffs against an oracle scenario.

## Module map (one .c per ROM subsystem, names from the listing)

| module | ROM | contents |
|---|---|---|
| `mainline.c` | $4000-$41xx, $8xxx | Poweron, Start2 loop, CheckForStartEnd, attract |
| `vgutil.c` | $8E42-$8F52 (VGUTR2) | Add2WordsToVector, JSRL/JMPL adders, DisplayDigit, long/short vector builders, AddHaltToVector, SaveInpuParameers |
| `irq.c` | $8639 (A2IRQ) | the 246 Hz service |
| `coins.c` | $7425 (COIN65) | coin/credit routine ($741A) |
| `earom.c` | $8749 (A2EARO) | EAROM state machine + buffer copies |
| `msgs.c` | $7730 (AS2MSG) | message/language tables, VectorGeneratorMessageProcessor |
| `score.c` | | scoring, high score table, initials (A2NAME) |
| `objects.c` / `enemies.c` | | ships, mines, saucer, comets, collision (phase 2+) |
| `selftest.c` | $8110 / $8A1D (AS2TST) | POST + operator screens + signature analysis — landed 2026-09-01, oracle-clean (`NOTES_selftest.md`); `sd_progrom.c` carries $4000-$8FFF for its checksum loop |
| `avg.c` | — | AVG state machine (from aae_avg.cpp semantics) |
| `sd_vecrom.c` | $2800-$3FFF | generated vector ROM bytes |
| `app_loop.c`, `platform/` | — | as Omega Race |

## Open questions (tracked here, resolved by evidence)

- **JMPL address fold (RESOLVED 2026-08-26): flat map, no mirror; the $E4
  seed is dead code.** The mirror hypothesis is rejected. Evidence:
  1. Both reference AVG implementations model the program counter as a FLAT
     byte offset from the vectorram base ($2000), continuing straight into
     the ROM bytes above it, with no fold anywhere: AAE
     `aae/vidhrdwr/aae_avg.cpp` lines 558-570 (`pc = (firstwd & 0x1fff) << 1`
     into `vec_mem`, which line 686 points at CPU memory + vectorram base)
     with `AAE_DRIVER_VECTORRAM(
     0x2000, 0x800)` in `aae/drivers/bwidow.cpp` line 788ff; and the late-MAME
     state machine `mame_late_avgdvg.cpp` line 509 (`vectorram[vg->pc ^ 1]`),
     line 780 (`vg->pc = vg->dvy << 1`), line 1535 (base = CPU region +
     $2000). AVG word $000-$3FF = vector RAM $2000-$27FF, $400-$7FF = CPU
     $2800-$2FFF (ship-picture ROM), $800-$FFF = vector ROM $3000-$3FFF.
  2. The anomalous seed is never executed. Poweron writes $2000/1 = $01/$E4
     (JMPL word $0401) at $8090-$8097, but no VGGO is strobed on the boot
     path (mainline strobe: `STA GOADD` $4056 only; $8608/$8AAA/$8D49 are
     self-test); the boot path ends with `JMP Pwron` ($80D1), and Pwron
     ($68CA) calls LswVectorAddress ($6C96) which rewrites $2000/1 =
     $01/$E0 — JMPL word $001 = CPU $2002 — before Start2 runs. The frame
     swap ($404E: `LDA $2001 / EOR #$02 / STA $2001 / STA GOADD`) then
     toggles $E0/$E2 = word $001/$201 = CPU $2002/$2402, exactly the double
     buffers. The seed also plants HALT at $2003 AND $2403 — belt-and-braces
     for either buffer, moot since the word is replaced before first use.
  3. The game can only generate flat 12-bit targets: AddJmplToVector ($8E7D)
     / AddJsrlToVector ($8E8E) compute operand = (CPU_addr >> 1) & $0FFF
     (LSR/AND #$0F/ORA opcode, TXA/ROR), i.e. the word offset from $2000
     for any target in $2000-$3FFF. And no JSRL/JMPL in the whole vector ROM
     listing (`../disasm/spaceduel_vector_rom.asm`) targets CPU
     $2800-$2FFF.
  `avg.c` therefore implements the flat map: words $000-$3FF from `g.vram`,
  $400-$FFF from `sd_vecrom` (which holds all of CPU $2800-$3FFF, so even
  the ship-picture region reads the true bytes, as the hardware would), and
  flags a diagnostic when the PC enters $400-$7FF or >= $1000 (program ROM,
  not carried), since nothing legitimate ever goes there.
