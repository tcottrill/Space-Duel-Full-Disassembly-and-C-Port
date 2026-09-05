# Oracle notes for the C-port author

Everything `tools/oracle.py` does that the C port must reproduce bit-for-bit,
plus what the first full attract run (600 frames, 2026-08-26) actually showed.
The oracle is the contract: when a probe diffs against `tests/ref/`, these are
the rules the reference bytes were generated under.

Run that produced `tests/ref/`:

    py c_src\tools\oracle.py attract --frames 600 --outdir c_src\tests\ref
    -> 600 frames, 17,556,949 cycles (11.61 s simulated), 2855 IRQs serviced,
       0 unimplemented opcodes, 0 writes to unmapped addresses, ~8 s wall.

## 1. The POKEY RANDOM LFSR (must match exactly)

One shared 17-bit LFSR serves BOTH POKEYs. It advances **only when the CPU
reads $100A or $140A**, one step = 8 bit-shifts per read. This is an oracle
definition, not chip emulation (the real chip free-runs; that would not be
replayable).

    uint32_t s = 0x1FFFF;              /* seed, at reset */

    uint8_t pokey_random_read(void)    /* any read of $100A or $140A */
    {
        for (int k = 0; k < 8; k++) {
            uint32_t bit = ((s >> 16) ^ (s >> 11)) & 1;   /* x^17 + x^12 + 1 */
            s = ((s << 1) | bit) & 0x1FFFF;
        }
        return (uint8_t)(s & 0xFF);    /* low 8 bits */
    }

First bytes returned from reset: the sequence is fully determined by the seed;
the C seam (`sd_hw_*`) must use this exact routine so replayed scenarios draw
the same random numbers in the same order. Note the order-of-reads dependency:
any C translation that reads RANDOM a different number of times than the ROM
did diverges from the oracle immediately — that makes the LFSR a free
instruction-path checksum.

## 2. Hardware model (what the reference dumps assume)

- **Clock** 1.512 MHz. **Cycle counts are approximate**: standard base-cycle
  table, +1 for a taken branch, no page-cross penalties. Absolute cycles do
  not matter to the C port — replay the IRQ schedule instead (section 3).
- **IRQ**: line asserted every 6144 cycles (246.09 Hz), held until the ROM
  writes $0E00 (IRQACK), serviced when I is clear (vector $FFFE).
- **IN0 $0800**: d7 = 3 kHz clock = `(cyc/252)&1` (low at reset); d6 = VG
  HALT; d4 = 1 (self-test off); d5,d3,d2,d1,d0 = 0.
- **VG HALT model**: d6 = 1, except for `--vg-draw-cycles` (default **4000**)
  cycles after each write to $0C80 (VGGO), during which it reads 0. 4000 is
  an arbitrary "the AVG took ~2.6 ms to draw" stand-in; it is comfortably
  shorter than the 24,576-cycle frame gate, so the mainline's HALT wait at
  $401F almost never blocks. The C seam's `sd_wait_vghalt()` can be a no-op
  as long as IRQ replay is honoured.
- **IN1 $0900-$0907**: all 0x00 (nothing pressed; $0907 = upright).
- **DIP/option ports**: reads of $1008 and $1408 return 0x00 (defaults;
  `--dip1008/--dip1408` to change). Gtoptn ($76DB) EORs $1008 with $85.
- **EAROM**: $0A00 reads 0x00 (blank part). Writes to $0E80/$0F00-$0F3F are
  logged only.
- **Watchdog** $0D00: ignored (healthy board).
- Unmapped reads return 0x00. The full run performed **zero** writes outside
  RAM, VRAM and the known registers.

### The coin/slam polarity trap (deliberate, keep it)

The coin routine (anonymous entry `L741A`, called from the IRQ at $8660)
treats IN0 coin bits HIGH as "coin absent" and d3 HIGH as "slam switch off".
With the oracle's all-zero idle bits, the slam input reads *active*, so the
pre-coin slam timer (TEMPA) is reloaded to $F0 every IRQ and coin status
cells $2D-$2F are cleared every pass — no credits ever register and attract
runs forever. This is intended for the attract scenario, but it means
**TEMPA/$2A-$2F contents in the reference RAM dumps reflect "slam held
active"**, not an idle cabinet. A future coin scenario must first raise
d3|d1|d0 (`("in0_set", 0x0B)`) and then pulse a coin bit low.

## 3. IRQ schedule (the timing contract)

`tests/ref/ref_index.json` records `irq_count` at **every** VGGO (`"vggo"`
array, 600 entries). Probe builds replay this: run exactly that many IRQ
services before each frame's mainline pass.

First 16 frames — first VGGO at cycle 2,421,626 (1.60 s after reset):

| frame | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| irq_count | 392 | 396 | 400 | 404 | 408 | 412 | 416 | 420 | 424 | 428 | 432 | 436 | 440 | 444 | 448 | 452 |

IRQs-per-frame distribution over the whole 600-frame run:
**{4: 556, 5: 20, 6: 22, 7: 1}** — nominally 4 (the $33 gate = every 4th
IRQ = 61.5 Hz), but 43 frames took 5-7 IRQs: the mainline occasionally
overruns one or more gate ticks (heavier display-list building during
attract-screen transitions). Average frame spacing ≈ 25.3 k cycles ≈ 59.8 Hz.
Do NOT assume 4 IRQs/frame in the C port; replay the recorded schedule.

## 4. Where the boot spends its time

Instruction-count profile from reset to frame 2 (~600 k instructions):

- **`StartThingsRunning` $80AB — 517 k of them (86%)**. After CLI it burns
  $61 ticks of $33 (each tick = 4 IRQs = 16.25 ms) as an "EAROM warm-up wait"
  (~1.58 s), then polls $0188 while the IRQ-driven EAROM state machine
  (`OutputEaromErasedWritten`, $8781, runs every 16th IRQ) reads the EAROM
  into the buffer. This is why the first VGGO lands only at 1.60 s / IRQ 392.
- With the blank EAROM (all reads 0x00) the boot takes the **copy path**:
  $0187 bit 0 ends up clear, so `CopyFromBufferBack` ($88B6) and
  `CopyOntimeFromBuffer` ($89A3) both run and load the zeroed buffer into
  the display area — the fresh-board behaviour; high-score table and ontime
  counters start zeroed.
- Coin routine + sound update (`InstructionsBracketsAreIllustration`,
  `ForceFieldUp`, `Ext*`) account for most per-IRQ work.
- 545 EAROM control writes and 4753 POKEY writes over the 600-frame run are
  logged in the oracle (in-memory; lengths reported on the console).

## 5. Frame snapshots and double buffering

Snapshots are taken **at the $0C80 write** — i.e. after the mainline's buffer
swap (`LDA $2001 / EOR #$02 / STA $2001 / STA GOADD`, $404E-$4056) and before
any of the next frame's list is built. Both dumps per captured frame:
`frame_NNNN.vram` ($2000-$27FF, 2048 bytes) and `frame_NNNN.ram`
($0000-$03FF, 1024 bytes). Captured: frames 1-16, then every 32nd (32..576);
34 frame pairs total.

Observed (and verified by AVG decode with `../disasm/avg.py` semantics):

- $2000/$2001 alternate `01 E2` / `01 E0` per frame: word $E201 = JMPL word
  $0201 -> CPU **$2402**; word $E001 = JMPL word $0001 -> CPU **$2002**.
  Odd frames display the upper buffer ($2402), even frames the lower ($2002).
- Buffer contents are real AVG code, e.g. frame 64 at $2002:
  `JSRL $3528, JSRL $3EC8, JSRL $3EC2, VCTR -216,-248,0, COLOR $1,14,
  JSRL $30EC, ...` (vector-ROM glyph calls for the attract screen).
- **Evidence for DESIGN.md's JMPL-fold open question**: the running attract
  header words are $E001/$E201 — direct vram targets, NOT the $E401 (word
  $0401) seed Poweron writes. The seed is overwritten before frame 1, so the
  attract capture never exercises the hypothesised word-$400-$7FF mirror.
  The question stays open; nothing in these dumps contradicts either reading.

## 6. Surprises / deviations to remember

1. **Opcodes added over the simulator the oracle grew from**: the full
   documented set of 151 (that small diagnostic-ROM simulator, written for
   bench tests of the board, had ~100 and no decimal mode). The ROM does
   execute SED arithmetic in the IRQ ($8672: EAROM/ontime BCD counters) —
   decimal ADC/SBC use the exact NMOS algorithm (N/V from the intermediate
   high-nibble sum in ADC; SBC flags purely binary). BRK and undocumented
   opcodes never occurred.
2. **JMP-indirect page-wrap bug** implemented; not observed to matter (no
   `JMP ($xxFF)` executed).
3. **Coverage**: 152 of 464 named routines executed in attract; 2709 distinct
   PCs; every executed PC exists as an `Lxxxx:` line in the annotated listing
   (0 disagreements). Eight anonymous JSR/JMP entry points executed (coin
   routine `L741A`/`L741C`, sound helpers `L6C79`, `L731F`, `L73A1`, EAROM
   helpers `L8856`/`L8858`/`L8865`) — see
   `tests/ref/coverage_attract.md`; these need names before translation.
4. **No uninitialized-RAM reads**: reset clears $0-$3FF, $2000-$27FF and both
   POKEY pages before use, so all state is deterministic from the model above.
   Note vram doubles as live state ($2001 buffer-select bit is *read back*
   by Start2_11) — the C port must keep that byte in `g.vram`, not a shadow.
5. **3 kHz clock phase**: starts LOW at cycle 0, half-period 252 cycles. The
   game path never busy-waits on it (only self-test does), so its phase is
   inert for attract — but it is part of the IN0 byte stored in
   `ref_index.json` captures.
6. **LFSR read counting**: RANDOM was read via $100A *and* $140A ($4AD0);
   both step the single shared LFSR. Order/count of reads is part of the
   contract (section 1).
