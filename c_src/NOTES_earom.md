# EAROM module notes (A2EARO, $8747-$89B0 -> earom.c/earom.h)

What the translation established; read with the listing open. Verified
against `spaceduel_program_rom.asm` and the boot sequence in
`NOTES_mainline.md`; tables byte-checked with `tools/gen_earom_data.py`
(all OK vs the 64K image, `../disasm/build/spacduel_64k.bin`, built by
`disasm/gen_from_roms.py`).

## 1. Layout: two checksummed batches in the ER-2055

| batch bit | contents | EAROM addrs | checksum | RAM buffer |
|---|---|---|---|---|
| 0 ($01) | high scores + initials | $02-$1C (27 bytes) | $1D | $0164-$017E |
| 1 ($02) | bookkeeping: ontime, games played | $1E-$3D (32 bytes) | $3E | $0192-$01B1 |

Batch parameters come from two 4-byte tables: `$8747` = {first addr,
checksum addr} per batch, `EaromOffsetLowestByte` `$874B` = {buffer lo, hi}.
The checksum is the plain 8-bit sum of the data bytes (EACS, $018D).
Batch 1's buffer starts at BONTIME ($0192): the ontime counter's slot is the
first 4 bytes, games-played counters live at $01A6+ inside the same buffer
(maintained by UpdateInfoAtEnd, not this module).

## 2. State cells

Named (sd_state_defs.h): `EACS $018D` running checksum; `ONTIME-$0191
$018E-$0191` live 4-byte BCD ontime counter (the IRQ bumps it every ~4 s
while no game is on); `BONTIME-$0195 $0192-$0195` its buffer slot; `$016D $016D`
is just a named byte inside the batch-0 buffer (never addressed directly by
this code); `PLAYTIME $0196` first games-played... (used via `PLAYTIME,X` by
UpdateInfoAtEnd). Unnamed (local `EA_*` macros over `g.ram[0xXX]`):

| cell | role |
|---|---|
| $0184 | zero flag: $FF = write zeros (and clear RAM buffer as it goes) |
| $0185 | pending batch request bits |
| $0186 | per-batch mode: bit set = erase/write, clear = read (only ReadEverything clears it) |
| $0187 | bad-checksum flags per batch (bit 0/1) |
| $0188 | current operation: $80 erase byte, $40 write byte, $20 read byte, 0 idle |
| $0189 | buffer index of current byte |
| $018A | current EAROM address |
| $018B | checksum (= last) EAROM address |
| $018C | mask of the batch being serviced |
| $C7/$C8 | buffer pointer lo/hi - this is EASRCE, the EAROM transfer pointer (the old RAM map named $C7/$C8 OBP0MINES, hence the note that used to sit here) |

## 3. The state machine and its cadence

`output_earom_erased_written` ($8781) is one tick, called by `sd_irq` every
16th 246 Hz tick (INTRPT & $0F == 0, i.e. every ~65 ms), plus synchronously
from `read_everything`, plus recursively from its own tail while reading.

Tick structure:

1. If $0188 == 0 and $0185 != 0: pick the **highest** pending batch bit
   (the ROR-$018C/ASL-A scan; exits with X = bit number, $018C = mask),
   set $0188 = $80 (erase/write) or $20 (read) from $0186, clear the bit in
   $0185, load the batch parameters from the tables.
2. Always: EACTL = $00 (deselect - this ends the previous erase/write
   pulse; it is why the oracle logs a control write every 16th IRQ even
   when idle).
3. Dispatch on $0188:
   - **$80 erase**: write $00 to EADAL+addr (latches the address), $0188 =
     $40, EACTL = $0E, return. The ~65 ms until the next tick is the
     part's erase time.
   - **$40 write**: $0188 = $80 (next byte's erase); if $0184 zero the
     buffer byte first; data = buffer byte, or EACS (and $0188 = 0, done)
     when addr == $018B; write data to EADAL+addr; checksum += data;
     $0189++/$018A++; EACTL = $0C, return.
   - **$20 read**: EACTL $08, EADAL+addr = $08 (address latch, data moot),
     EACTL $09, NOP, EACTL $08, read EAIN. Data byte: store to buffer,
     checksum += byte, advance, EACTL = $00 and **jump back to the top**
     ("DO ALL READS AT ONCE") - a read batch completes inside one tick.
     Checksum byte: compare with EACS; mismatch zeroes buffer[index..0]
     and ORs $018C into $0187; either way $0188 = 0 and it chains back to
     the top (which starts the next pending batch, if any).

So: reads are synchronous (both batches finish inside the `read_everything`
call), writes take **2 ticks per byte** = ~130 ms/byte, ~3.6 s for batch 0,
~4.3 s for batch 1. $0188 != 0 is the "busy" indicator other code polls
(boot $80BB, self-test $82D2, operator screen $8BE5).

The chain tails are the anonymous entries the oracle flagged:
`sub_8856` (Y=0 variant), `sub_8858` (checksum/advance), `sub_8865`
(EACTL = Y; Y == 0 re-enters the machine). In C they are static functions;
the re-entry is a bounded mutual recursion (worst case ~62 frames deep for
a full 2-batch read - trivial).

## 4. Register protocols (derived from all call sites)

| routine | in | out |
|---|---|---|
| RequestZeroEarom $8759 | A = batch bits (only entered from $874F/53/57 prefixes with A = 2/1/3) | - |
| ZeroEarom/Eazhis/Eazero | none | - |
| WriteHighScoresInitials $875D / RequestBookkeepingUpdate $8761 | none | - |
| ReadEverything $8777 | none ($80B8, $82B9, $82DA) | buffers + $0187 valid on return |
| OutputEaromErasedWritten $8781 | none (IRQ $864A) | - |
| sub_8856 | A = byte for checksum | chains |
| sub_8858 | A = byte, Y = EACTL code | chains |
| sub_8865 | Y = EACTL code | Y==0 re-enters machine |
| TransferHighScoresBuffer $886F | none ($4E91) | buffer $0164 packed, 27 bytes |
| SaveCopy $8911 | Y = buffer idx (not advanced), X = 2..0 | A = validated BCD byte or Subnum[X] |
| SaveOriginal $8929 | Y = buffer idx (pre-incremented!), X | A = validated initial ($00, $0A-$24) or Subl[X] |
| CopyFromBufferBack $88B6 | none ($80CA, self-test) | live cells $DD.../$0119... |
| CopyOntimeFromBuffer $89A3 | none ($80CE, game start/end) | BONTIME -> ONTIME (4 bytes) |

Live-cell map used by the copies (unnamed, `g.ram[]`): scores $DD/$EC/$FB/
$010A (+X, X = 2..0; only $00DE $DE has a define), initials $0119/$0128/
$0137/$0155/$0146 (+X). All-zero top 2P-fighter score after unpack =>
"just cleared EAROM" and every table's top score is reseeded to 500
($05 middle byte at $DE/$ED/$FC/$010B).

## 5. Blank-EAROM boot (the oracle's path)

StartThingsRunning $80AB: ~1.58 s warm-up wait, then `JSR ReadEverything`;
by the time the $80BB poll of $0188 runs, both batch reads already finished
inside the call (section 3). Blank part: every `sd_hw_earom_read()` returns
0, so data sum = 0 and the checksum byte = 0 - **checksums match**, $0187
stays 0. Boot then takes the copy path: `CopyFromBufferBack` (bit 0 of
$0187 clear) unpacks zeros - which validate as scores and blanks - and the
all-zero test reseeds the four 500-point top scores; `CopyOntimeFromBuffer`
always runs and zeroes the live ontime. Matches NOTES_oracle.md section 4.
Note the boot check only gates on batch 0's bad bit; a bad bookkeeping
checksum would still be copied to ONTIME (zeros, since the mismatch path
wiped the buffer).

Attract steady state: no requests pending, so the every-16th-tick call is
just deselect-and-return - one EACTL($00) write per call, which the seam
must forward so the oracle's control-write log parity holds (545 over the
600-frame run: boot reads + idle deselects).

## 6. NVRAM persistence hooks (for the later real build)

Everything funnels through the three seam calls, so persistence is entirely
a platform concern:

- `sd_hw_earom_ctl(v)`: state machine for the platform side too - latch the
  pending address/data on $0E (erase) / $0C (write) pulses; commit-to-file
  on the $00 deselect that ends a pulse is the natural flush point.
- `sd_hw_earom_write(off, v)`: off = EAROM address 0-$3F. During reads it is
  only an address latch (data byte is $00 or $08 garbage - do not store it
  unless the last ctl code was $0C/$0E).
- `sd_hw_earom_read()`: return blob[latched addr]; a missing/empty NVRAM
  file must read as all $00 - that IS the fresh-board path proven above,
  no special-casing needed.

Probe/headless builds keep the oracle model: reads return 0, ctl/data
writes appended to a log for sequence diffing.

## 7. Externs

earom.c depends only on `sd_state.h` + `sd_hw.h` (no cross-module calls).
Consumers (for the orchestrator's header consolidation, all in earom.h):
`irq.c` externs `output_earom_erased_written` (already present); mainline
will need `read_everything`, `copy_from_buffer_back`,
`copy_ontime_from_buffer`; score/game-end needs
`transfer_high_scores_buffer`, `write_high_scores_initials`,
`request_bookkeeping_update` (via UpdateInfoAtEnd); self-test needs
`eazero`, `eazhis`, `zero_earom`, `read_everything`.

## 8. Dropped artifacts and open questions

Dropped (rule 7, each noted in code): SEI/CLI around CopyOntimeFromBuffer;
PHA/PLA register saves in SaveCopy and the boot path (stack-page bytes are
not modelled - same policy as irq.c's register save/restore).

Open:
- **RESOLVED 2026-08-26: UpdateInfoAtEnd $893E / AddGameTimeSubroutime
  $8997** are now translated and appended to this file (see section 9
  below) - they belong here after all: they're the tail of the game-end
  sequence that hands off into `RequestBookkeepingUpdate`, and their only
  RAM effects (PLAYTIME/ONTIME/games-played counters/BONTIME) are all cells this
  module already owns or stages for the EAROM. **Averag $89B9** remains
  unassigned: confirmed by reading `UpdateInfoAtEnd`'s full body that it
  does not call `Averag` (it tail-jumps straight to
  `RequestBookkeepingUpdate`, $8994) - `Averag` is reached only from
  `AllStopPlease` ($8A1D, the self-test/game-end summary screen), which
  is a separate, much larger routine outside this module's scope. Still
  suggest score.c or a future selftest.c when someone translates
  `AllStopPlease`.
- $0186 is never cleared after a write batch completes (only ReadEverything
  resets it) - stale write bits are harmless because $0185 gates servicing,
  but any future "re-read one batch" feature must go through ReadEverything.
- The `EA_MASK` ROR loop writes $018C eight times with intermediate values;
  the C version computes the same final value through the same macro cell.
  Invisible to frame-boundary diffs; only an instruction-level trace would
  see the intermediates.
- SaveOriginal's substitute initials Subl = {$0C,$0B,$0E} decode to "L K N"
  in glyph codes ($0A = A) - Atari easter egg initials; kept verbatim.

## 9. UpdateInfoAtEnd $893E / AddGameTimeSubroutime $8997 (added 2026-08-26)

Game-end bookkeeping, called once per finished game from mainline.c's
`chkst1()` ($4397), immediately before `update_high_score_table()`
(score.c). No arguments; reads `ZP_34` (game-select switch, 0-3).

**AddGameTimeSubroutime ($8997)**: one decimal byte of the just-finished
game's elapsed time (`GTIME`, $03B0, 4 bytes) folded into the per-game-
type running total `PLAYTIME` ($0196+, 4 games x 4 bytes). In: `*x` = PLAYTIME
index, `*y` = GTIME index, `cin` = incoming carry (threaded call to call,
starting from `UpdateInfoAtEnd`'s `CLC`). Out: `PLAYTIME[x]` updated, `*x`/`*y`
advanced by 1, returns outgoing carry. Its only caller unrolls it 4 times
(`$8948-$8951`) rather than looping, so the C translation keeps the same
4 explicit calls (`static` helper, not exposed in earom.h - nothing else
calls it).

**UpdateInfoAtEnd ($893E)** itself, in order:
1. `PLAYTIME[game*4 .. game*4+3] += GTIME[0..3]` (decimal, via the helper above).
2. `ONTIME[0..3] += GTIME[0..3]` (decimal) - folds the elapsed game time
   into the live ontime counter, which the IRQ stops advancing while a
   game is in progress (comment in the listing: "THIS COUNTER WAS OFF
   DURING THE GAME").
3. Increments the 3-byte BCD games-played counter for this game type at
   unnamed `g.ram[0x1A6 + game*3 .. +2]` (no macro exists for this base;
   `$01AF` $01AF happens to alias game-type index 3 of this same array -
   `0x1A6 + 3*3 == 0x1AF` - noted in a comment rather than used, since
   using `$01AF,X`-style indexing across game types would be misleading).
4. Stages `ONTIME` into `BONTIME` (4 bytes) and tail-calls
   `request_bookkeeping_update()` to start the EAROM write - this was
   already implemented (section 4/7 above); no new seam calls needed.

No hardware I/O, no VG calls; pure RAM/BCD. Compiles /W4-clean together
with score.c/score_data.c (see NOTES_score.md section verifying the
build). `sd_bcd.h` (`bcd_adc`) is now included by earom.c for the decimal
adds; no NMOS-N-flag branch depends on any of these adds (nothing branches
on N after them), so only the carry chain matters here, unlike Averag's
decimal SBC (which is why Averag was left unassigned rather than folded
in "for free" - it would need a decimal-SBC helper these routines don't
otherwise require).
