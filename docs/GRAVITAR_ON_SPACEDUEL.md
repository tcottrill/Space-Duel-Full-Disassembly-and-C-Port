# Gravitar on a Space Duel PCB: CPU interposer memory map and decode

A working note for running the Gravitar ROM set on Space Duel hardware.
The plan is an interposer board in the 6502 socket that carries the extra
RAM and the whole program image, so the game PCB itself is touched only on
the vector bus. Everything here is derived from the two disassemblies
(`disasm/spaceduel_defines.asm` here, `gravitar_defines.asm` in the
Gravitar repository) and the listings they generate; nothing comes from a
Space Duel schematic, and the items that need one are called out.

## 1. Why an interposer

Gravitar needs more of three things than the Space Duel board provides,
and one of them cannot be fixed from the CPU socket.

| resource | Gravitar needs | Space Duel board has | fixed by |
|---|---|---|---|
| CPU RAM | data through `$0517`; power-on clear at `$E850` sweeps pages 4-7 (2K) | 1K at `$0000-$03FF`; the self-test marches pages 1-3 only | interposer SRAM |
| program ROM | 28K (`$9000-$EFFF` plus R7 code at `$5000`) | 20K in five 4K sockets | interposer EPROM |
| vector ROM on the AVG bus | 10K at `$2800-$4FFF` plus the R7 list at `$562E`; the AVG reaches `$2000-$5FFE` | 6K, R7 and N/P7 | the game PCB (section 6) |
| vector RAM | 2K, highest reference `$27FE`, buffers at pages `$20` and `$24` | 2K at `$2000-$27FF` | nothing |
| I/O | `$6000-$89FF` | `$0800-$17FF` | the ROM patch (section 7) |

The AVG fetches its display lists over the board's own vector bus, which
never passes through the CPU socket. So the interposer serves the CPU and
only the CPU; the AVG's copy of the vector data lives on the board.

## 2. Interposer parts

- One 6116 (2K x 8 SRAM). One chip is the whole 2K; a second has no job,
  because vector RAM stays on the board where the AVG can read it.
- One 27C512 (64K x 8 EPROM), holding the complete relocated Gravitar
  image (section 5). The CPU never uses the board's ROM sockets.
- One 74LS245 between the CPU data bus and the board's data bus, enabled
  only on pass-through cycles.
- One 16V8 GAL, or a 74LS138 plus a few gates, for the decode.
- Control lines straight through: phi0 in, phi2 out, R/W, /IRQ, /NMI,
  /RES, RDY, SYNC, SO. The board keeps generating the IRQ, the 3 kHz
  clock, the watchdog and the reset exactly as it does for Space Duel.

## 3. CPU memory map through the interposer

This is what the relocated Gravitar sees. The middle column says which
device answers; "board" means the 74LS245 is enabled and the access goes
to the Space Duel PCB unchanged.

| CPU range | served by | contents |
|---|---|---|
| `0000-07FF` | 6116 | zero page, stack, game RAM (Gravitar's full 2K) |
| `0800-0FFF` | board | Space Duel I/O, see below |
| `1000-13FF` | board | POKEY 1 |
| `1400-17FF` | board | POKEY 2 |
| `1800-1FFF` | board | nothing decoded on the board; passed through for simplicity |
| `2000-27FF` | board | vector RAM, the CPU side of the AVG's dual-ported 2K |
| `2800-4FFF` | 27C512 | the CPU's copy of the vector ROM (checksum only) |
| `5000-5FFF` | 27C512 | R7: the LOOSEU module, 6502 code and AVG data interleaved |
| `6000-8FFF` | 27C512 | unused; fill `$FF`. Gravitar's old I/O lived here and must be gone after the patch |
| `9000-EFFF` | 27C512 | program, D1 through M1 |
| `F000-FFFF` | 27C512 | copy of `$E000-$EFFF`, so the vectors at `$FFFA` resolve |

The Space Duel I/O the patched program uses, from
`spaceduel_defines.asm`:

| address | register | Gravitar's original |
|---|---|---|
| `0800` | `In0`: 3 kHz, VG halt, diag step, self-test, slam, coins (same bit layout as Gravitar's) | `$7800` |
| `0900-0907` | `In1`: one switch per address in d7 (and d6) | `$8000` d4-d0 and `$8800` d7-d5 |
| `0A00` | EAROM read | `$7000` |
| `0C00` | coin counters d0/d1, start lamps d4/d5, cabinet flip | `$8800` write |
| `0C80` | VG go | `$8840` |
| `0D00` | watchdog | `$8980` |
| `0D80` | VG reset | `$8880` |
| `0E00` | IRQ ack | `$88C0` |
| `0E80` | EAROM control | `$8900` |
| `0F00-0F3F` | EAROM write, address in the low six bits | `$8940-$897F` |
| `1000` | POKEY 1 | `$6000` |
| `1400` | POKEY 2 | `$6800` |

Why the CPU needs the vector ROM copy: Gravitar's self-test at `$EA06`
EOR-checksums `$2800-$2FFF` as a special case, then pages `$30-$5F`
("14K of VECROM"), then `$90-$EF`, all by CPU reads. And the CPU executes
R7's code at `$5000`. Both come from the interposer EPROM.

## 4. Decode logic

Inputs to the decoder: A11-A15, R/W, phi2. Three regions, by the top five
address bits:

```
RAMSEL = /A15 & /A14 & /A13 & /A12 & /A11                ; $0000-$07FF
PASS   = /A15 & /A14 & (  /A13 & /A12 &  A11             ; $0800-$0FFF
                        | /A13 &  A12                    ; $1000-$1FFF
                        |  A13 & /A12 & /A11 )           ; $2000-$27FF
ROMSEL = /RAMSEL & /PASS                                 ; $2800-$FFFF
```

Device pins:

```
6116    /CE = /RAMSEL
        /OE = /RW                  ; drive the bus on reads only
        /WE = /( /RW & PHI2 )      ; write strobe qualified by phi2

27C512  /CE = /ROMSEL
        /OE = /RW
        A0-A15 straight from the CPU; the image is linear 64K

74LS245 A side = CPU, B side = board
        /OE = /PASS
        DIR = /RW                  ; write: CPU to board (A to B); read: board to CPU
```

16V8 equations, same thing in CUPL form:

```
PIN 1 = A11;  PIN 2 = A12;  PIN 3 = A13;  PIN 4 = A14;  PIN 5 = A15;
PIN 6 = RW;   PIN 7 = PHI2;
PIN 12 = !RAMCE;  PIN 13 = !RAMWE;  PIN 14 = !ROMCE;  PIN 15 = !BUFOE;  PIN 16 = DIR;

pass   = !A15 & !A14 & ( !A13 & !A12 & A11  #  !A13 & A12  #  A13 & !A12 & !A11 );
ramsel = !A15 & !A14 & !A13 & !A12 & !A11;

RAMCE  = ramsel;
RAMWE  = ramsel & !RW & PHI2;
ROMCE  = !ramsel & !pass;
BUFOE  = pass;
DIR    = !RW;
```

Bus behaviour, cycle by cycle:

- **RAM or ROM cycle.** The 245 is off. The board still sees the address
  on its own bus and will select its 1K RAM (`$0000-$03FF`), its VG
  window (`$2000-$3FFF`) or an empty ROM socket, but none of that reaches
  the CPU. Board RAM gets written with a floating data bus during writes
  to `$0000-$03FF`; harmless, nothing reads it. CPU reads of `$2800-$3FFF`
  still cost the board a VG-window cycle; harmless, and only the self-test
  sweeps that range.
- **Pass-through cycle.** SRAM and EPROM are off, the 245 is on, and the
  board's I/O, POKEYs and vector RAM behave exactly as under Space Duel.
- Writes to `$2800-$FFFF` go nowhere. Gravitar makes none.
- Leave the board's five program sockets empty. They are isolated anyway,
  but an empty socket cannot double-drive.

Timing is not tight: the 6502 runs at 1.512 MHz (661 ns cycle, phi2 high
about 330 ns), so 150 ns EPROM and SRAM parts and a 15 ns GAL have margin.

## 5. The EPROM image

Start from the Gravitar repository's `disasm/build/gravitar_64k.bin`,
which is the rev-3 ROM set laid into a 64K image at CPU addresses. Three
changes make it the interposer image:

1. **Relocate the I/O** (section 7). Regenerate through the Gravitar
   `emit_ca65.py` + `flat.cfg` chain with the alias values changed, so the
   145 hardware-touching instructions move together.
2. **Mirror M1 to `$F000-$FFFF`.** On the Gravitar board the socket
   decode does this; on the interposer the image has to carry the copy.
3. **Fix the checksum bytes** in every 4K block the patch touched. The
   self-test EOR-sums each block seeded with its index and stores the
   results at `$6B,X`; any non-zero result mutes the sound and flags the
   ROM.

`$0000-$27FF` of the image is never selected and can hold anything.
`$6000-$8FFF` should be `$FF`.

## 6. What stays on the game PCB: the vector bus

The AVG reads `$2000-$27FF` (its RAM) and `$2800-$5FFF` (ROM) as a
14-bit byte offset from `$2000`. Two cases:

- **The replacement AVG module carries its own vector memory.** Load it
  with the same bytes and the row-7 sockets on the Space Duel board are
  irrelevant. Nothing else to do.
- **The module uses the board's vector bus.** Then a 27C512 on an adapter
  in the N/P7 position carries the data, and three things change on the
  board:
  - **Address bit 13.** The socket only carries VA0-VA12 (the largest
    original part is 4K). VA13 comes by flying lead from the module or the
    counter it drives, to the EPROM's A13.
  - **ROM select.** Must cover `$2800-$5FFF`, that is
    `/CE = /(VA13 | VA12 | VA11)`, not the socket's own `$3000-$3FFF`
    select. Leave R7 empty.
  - **RAM select.** The board's vector RAM select must include `/VA13`,
    or a fetch at `$4000-$47FF` hits RAM and ROM together. Whether Space
    Duel's decoder already includes that bit needs the schematic or a
    scope; it is the one item here that cannot be settled from the ROMs.

The vector EPROM can use the same 64K image as the interposer. The EPROM
address is the VG offset plus `$2000`, which is one inverter:

```
EPROM A0-A12 = VA0-VA12
EPROM A13    = /VA13
EPROM A14    =  VA13
EPROM A15    = 0
```

Or burn a separate 16K image with the bytes for CPU `$2800-$5FFF` at
offset `$0800-$3FFF` and tie A14 and A15 low.

Gravitar's own list builder at `$E43F` already masks five high bits
(`AND #$1F`), which is what encodes a `$5xxx` JSRL target, so no software
change is needed for the reach.

## 7. The software patch, for reference

Everything the program touches outside RAM and vector RAM, counted from
the Gravitar listing:

| target | instructions |
|---|---|
| POKEY 1 and 2 | 75 |
| `IN0` | 24 |
| watchdog | 13 |
| `IN2` and the output latch | 11 |
| EAROM read, control, write | 9 |
| VG go and reset | 8 |
| `IN1` | 4 |
| IRQ ack | 1 |
| **total** | **145** |

All of them go through aliases in `gravitar_defines.asm`, so the
relocation is a table change plus a relink. The hand work:

- **`READSW` at `$CC8A`** builds the switch byte from `IN2` d7-d5 and
  `IN1` d4-d0. Space Duel presents one switch per address in d7 of
  `$0900-$0907`, so this becomes eight loads and shifts, about 40 bytes in
  place of 20. Gravitar's five controls, two starts and cocktail all have
  Space Duel inputs.
- **Three self-test reads of `IN1`** (`$E61A`, `$ECB0`, `$EDA8`), one of
  which reads the test-select jumpers on d5-d7 that Space Duel lacks.
- **Lamp bits.** Coin counters on d0/d1 and lamps on d4/d5 on both
  boards; the two lamp bits are swapped between the drivers.
- **DIPs.** Both boards hang option switches on the POKEY pot lines, so
  the reads relocate with the POKEYs; only the switch legends differ.

After the relink, scan the listing for any remaining reference to
`$6000-$89FF`. There must be none: under the interposer those addresses
read `$FF` from the EPROM and writes vanish, so a missed one fails
silently.

## 8. Bring-up order

1. Interposer alone, Space Duel image in the EPROM with the board's own
   ROMs pulled. Space Duel should run unchanged; this proves the decode,
   the 245 and the SRAM without any Gravitar variable in play.
2. Vector side alone, still Space Duel: the vector EPROM in N/P7 with the
   Space Duel bytes. Proves the adapter and the selects for the original
   6K.
3. Extend `local/sd_jmpl_bits.s` to test word bits 10-12 with HALT
   targets placed in the vector EPROM at `$4000`, `$4800` and `$5000`.
   That is the only direct proof that the AVG reach and the VA13 wiring
   are right before Gravitar depends on them.
4. Gravitar image in both EPROMs. Self-test first: the ROM checksums and
   the RAM march cover every region this document touches.
