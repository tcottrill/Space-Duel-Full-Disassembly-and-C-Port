#!/usr/bin/env python3
"""oracle.py — differential-test oracle for the Space Duel C port.

Runs the REAL Space Duel ROM image (spacduel_64k.bin, MAME set 'spacduel'
rev 2) on a complete documented-opcode 6502 simulator and produces reference
dumps (vector RAM + main RAM at every displayed frame) that the C port is
byte-diffed against.  Its 6502 core was derived from a small diagnostic-ROM
simulator written for bench tests of the board.

Usage:
    py c_src\\tools\\oracle.py attract --frames 600 --outdir c_src\\tests\\ref

Outputs (in --outdir):
    frame_NNNN.vram   2048 bytes, $2000-$27FF at the VGGO of frame NNNN
    frame_NNNN.ram    1024 bytes, $0000-$03FF at the same instant
    ref_index.json    captured-frame index + irq_count at EVERY VGGO
    coverage_<scenario>.md  executed-routine table from the annotated listing

================================ HARDWARE MODEL ===============================

Every choice below is part of the oracle contract: the C port must reproduce
the same model bit-for-bit to diff clean.

CPU
  * All 151 documented 6502 opcodes/addressing modes.  Undocumented opcodes
    and BRK are fatal errors (they never execute in this ROM) and report the
    PC plus the last 32 instruction PCs.
  * Decimal mode (SED) ADC/SBC use the exact NMOS-6502 algorithm (Bruce
    Clark's 6502.org appendix, sequences 1 and 3): ADC takes N/V from the
    high-nibble intermediate sum and Z from the BINARY sum; SBC takes all
    flags from the binary computation and only the stored result is
    decimal-adjusted.  The IRQ handler ($8672) does SED arithmetic on the
    EAROM operation counters, so this matters.
  * JMP ($xxFF) reproduces the page-wrap bug (high byte fetched from $xx00).
  * INTERRUPT POLLING IS MAME's (src/devices/cpu/m6502/om6502.lst): the
    line is polled at the end of every instruction with the I flag AS IT
    STOOD BEFORE that instruction when the instruction is CLI, SEI or PLP
    ("prefetch(); P &= ~F_I; // Do *not* move it before the prefetch"),
    and with the new I after everything else, RTI included.  So an IRQ
    lands one instruction late after CLI, and a pending IRQ is still taken
    right after SEI.  (Backported from the Gravitar oracle, 2026-09-13; an
    earlier version polled with the current I and took the interrupt on the
    CLI itself - see NOTES_oracle.md section 7 for the before/after.)
  * CYCLE COUNTS ARE APPROXIMATE: base cycles per opcode from the standard
    table, +1 for a taken branch, NO page-cross penalties.  All timing below
    is defined in terms of these approximate cycles; the C port replays the
    IRQ-per-frame schedule recorded in ref_index.json rather than counting
    cycles itself, so absolute cycle accuracy is not required — only
    determinism.

IRQ  (clock 1.512 MHz, per the AAE bwidow.cpp driver)
  * The IRQ line is asserted every 6144 cycles (1512000/6144 = 246.09 Hz)
    and held until the program writes $0E00 (IRQACK).  It is serviced (7
    cycles, vector $FFFE) whenever the I flag is clear.  irq_count = number
    of times the service sequence ran (i.e. handler entries).

IN0 $0800
  * d7 = 3 kHz clock: (cyc // 252) & 1  (1512000/3000/2 = 252 cycles per
    half-period; starts LOW at cycle 0).
  * d6 = VG HALT (1 = AVG done).  Normally 1.  A write to $0C80 (VGGO)
    holds it 0 for --vg-draw-cycles cycles (default 4000), then 1 again.
  * d4 = 1 (self-test switch OFF = game mode).
  * d5 (diag step), d3 (slam), d2 (right coin mech), d1 (COIN1), d0 (COIN2)
    = 0 unless a scenario injects them.  NOTE the polarity consequence: the
    coin routine treats input HIGH as "coin absent" and slam bit HIGH as
    "switch off", so all-zeros means "coin present + slam active"; the slam
    pre-coin timer (TEMPA=$F0, reloaded every IRQ) then suppresses all coin
    acceptance — net effect: no credits, attract runs forever, exactly what
    the oracle wants.  A coin scenario must first RAISE d3 (slam off) and
    d0/d1 (coins absent), then pulse the coin bit low.

IN1 $0900-$0907
  * One switch per address, read via BIT (bits 7/6).  All reads return 0x00
    (nothing pressed) unless a scenario injects a value per address.
    $0907 (cabinet) = 0x00 = upright.

POKEY $1000-$14FF
  * Reads of $x00A (RANDOM, both POKEYs) return bytes from ONE shared
    deterministic 17-bit LFSR, stepped ONCE (= 8 bit-shifts) PER READ.

    EXACT ALGORITHM (the C port must reproduce this bit-for-bit):
        state: 17-bit register s, seeded 0x1FFFF
        one READ of $100A or $140A does:
            repeat 8 times:
                new_bit = ((s >> 16) ^ (s >> 11)) & 1   # x^17 + x^12 + 1
                s = ((s << 1) | new_bit) & 0x1FFFF
            return s & 0xFF                              # low 8 bits
    (This is the POKEY 17-bit polynomial-counter feedback; the tap choice
    and the step-per-read convention are oracle definitions — the real chip
    free-runs at a clock rate, which would not be reproducible.)
  * Reads of $1008 return --dip1008 (default 0x00) and $1408 return
    --dip1408 (default 0x00): option-switch / ALLPOT ports.  (Gtoptn at
    $76DB EORs $1008 with $85 to normalise "all off".)
  * All other POKEY reads return 0x00.
  * Every POKEY write is logged (cycle, addr, val) in pokey_writes.

EAROM
  * Reads of $0A00 return 0x00 (blank EAROM, as on a fresh board; the boot
    "data OK" path must cope).  Writes to $0E80 and $0F00-$0F3F are logged.

Outputs
  * Writes to $0C00 (coin counters/lamps), $0C80 (VGGO), $0D80 (VGRST) are
    logged with cycle numbers.  $0D00 (watchdog) writes are ignored
    (healthy board), but a stall detector aborts with diagnostics if no
    VGGO write occurs for 20 simulated seconds (30,240,000 cycles) after
    the first one, or within 60 s of reset.

Unmapped addresses read 0x00; writes outside RAM/VRAM/known registers are
ignored (logged in misc_writes for post-mortem).

Frames
  * Each write to $0C80 (VGGO) = one displayed frame; frame_number++ at the
    write.  Snapshots are taken AT that write, i.e. after the mainline's
    buffer swap at $404E-$4056 ($2001 EOR #$02) and before the AVG "draws".
==============================================================================
"""
import argparse
import json
import os
import re
import sys
import time
from collections import deque

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(PROJECT_ROOT, "disasm"))
import paths
ASM_PATH = paths.PROGRAM_ROM

CPU_HZ = 1_512_000
IRQ_PERIOD = 6144          # 246.09 Hz
CLOCK3K_HALF = 252         # 3 kHz square wave half-period
STALL_LIMIT = 20 * CPU_HZ  # abort if VGGO silent this long
BOOT_LIMIT = 60 * CPU_HZ   # abort if the FIRST VGGO never comes


def load_image(romdir=None):
    """The 64K CPU image: disasm/build/spacduel_64k.bin if gen_from_roms.py
    has written it, else built from the ROM directory (--roms, $SD_ROMS or
    <root>/roms), $8000-$8FFF mirrored to $FFFF."""
    if romdir:
        return bytearray(paths.image64k(romdir, write=False))
    return bytearray(paths.load_image64k())


# --------------------------------------------------------------------------
# 6502 opcode table: op -> (mnemonic, mode, base_cycles).  Documented set only.
# --------------------------------------------------------------------------
_TBL = """
00 BRK imp 7|01 ORA izx 6|05 ORA zp 3|06 ASL zp 5|08 PHP imp 3|09 ORA imm 2
0A ASL acc 2|0D ORA abs 4|0E ASL abs 6|10 BPL rel 2|11 ORA izy 5|15 ORA zpx 4
16 ASL zpx 6|18 CLC imp 2|19 ORA aby 4|1D ORA abx 4|1E ASL abx 7|20 JSR abs 6
21 AND izx 6|24 BIT zp 3|25 AND zp 3|26 ROL zp 5|28 PLP imp 4|29 AND imm 2
2A ROL acc 2|2C BIT abs 4|2D AND abs 4|2E ROL abs 6|30 BMI rel 2|31 AND izy 5
35 AND zpx 4|36 ROL zpx 6|38 SEC imp 2|39 AND aby 4|3D AND abx 4|3E ROL abx 7
40 RTI imp 6|41 EOR izx 6|45 EOR zp 3|46 LSR zp 5|48 PHA imp 3|49 EOR imm 2
4A LSR acc 2|4C JMP abs 3|4D EOR abs 4|4E LSR abs 6|50 BVC rel 2|51 EOR izy 5
55 EOR zpx 4|56 LSR zpx 6|58 CLI imp 2|59 EOR aby 4|5D EOR abx 4|5E LSR abx 7
60 RTS imp 6|61 ADC izx 6|65 ADC zp 3|66 ROR zp 5|68 PLA imp 4|69 ADC imm 2
6A ROR acc 2|6C JMP ind 5|6D ADC abs 4|6E ROR abs 6|70 BVS rel 2|71 ADC izy 5
75 ADC zpx 4|76 ROR zpx 6|78 SEI imp 2|79 ADC aby 4|7D ADC abx 4|7E ROR abx 7
81 STA izx 6|84 STY zp 3|85 STA zp 3|86 STX zp 3|88 DEY imp 2|8A TXA imp 2
8C STY abs 4|8D STA abs 4|8E STX abs 4|90 BCC rel 2|91 STA izy 6|94 STY zpx 4
95 STA zpx 4|96 STX zpy 4|98 TYA imp 2|99 STA aby 5|9A TXS imp 2|9D STA abx 5
A0 LDY imm 2|A1 LDA izx 6|A2 LDX imm 2|A4 LDY zp 3|A5 LDA zp 3|A6 LDX zp 3
A8 TAY imp 2|A9 LDA imm 2|AA TAX imp 2|AC LDY abs 4|AD LDA abs 4|AE LDX abs 4
B0 BCS rel 2|B1 LDA izy 5|B4 LDY zpx 4|B5 LDA zpx 4|B6 LDX zpy 4|B8 CLV imp 2
B9 LDA aby 4|BA TSX imp 2|BC LDY abx 4|BD LDA abx 4|BE LDX aby 4|C0 CPY imm 2
C1 CMP izx 6|C4 CPY zp 3|C5 CMP zp 3|C6 DEC zp 5|C8 INY imp 2|C9 CMP imm 2
CA DEX imp 2|CC CPY abs 4|CD CMP abs 4|CE DEC abs 6|D0 BNE rel 2|D1 CMP izy 5
D5 CMP zpx 4|D6 DEC zpx 6|D8 CLD imp 2|D9 CMP aby 4|DD CMP abx 4|DE DEC abx 7
E0 CPX imm 2|E1 SBC izx 6|E4 CPX zp 3|E5 SBC zp 3|E6 INC zp 5|E8 INX imp 2
E9 SBC imm 2|EA NOP imp 2|EC CPX abs 4|ED SBC abs 4|EE INC abs 6|F0 BEQ rel 2
F1 SBC izy 5|F5 SBC zpx 4|F6 INC zpx 6|F8 SED imp 2|F9 SBC aby 4|FD SBC abx 4
FE INC abx 7
"""
OPCODES = {}
for _e in _TBL.replace("\n", "|").split("|"):
    _e = _e.strip()
    if _e:
        _op, _mn, _md, _cy = _e.split()
        OPCODES[int(_op, 16)] = (_mn, _md, int(_cy))
assert len(OPCODES) == 151, len(OPCODES)


class OracleError(RuntimeError):
    pass


class Oracle:
    def __init__(self, image, args, scenario_events):
        self.mem = image                     # 64K ROM image ($2800-$FFFF used)
        self.ram = bytearray(0x400)
        self.vram = bytearray(0x800)
        self.args = args
        self.events = scenario_events        # {frame: [(kind, ...), ...]}
        # CPU state
        self.a = self.x = self.y = 0
        self.sp = 0xFD
        self.n = self.z = self.c = self.v = 0
        self.i = 1
        self.i_poll = 1                      # the I the IRQ poll sees (MAME)
        self.d = 0
        self.cyc = 0
        # IRQ
        self.irq_line = False
        self.next_irq = IRQ_PERIOD
        self.irq_count = 0
        # I/O state
        self.in0_base = 0x10                 # d4=1: self-test switch OFF
        self.in1 = bytearray(8)              # $0900-$0907
        # frame-0 events: the switch state the CPU comes out of RESET with
        # (a scenario that holds the self-test switch at power-on)
        for ev in scenario_events.get(0, []):
            self.apply_event(ev, "")
        self.dip = {0x1008: args.dip1008, 0x1408: args.dip1408}
        self.lfsr = 0x1FFFF
        self.vg_busy_until = 0               # cyc before which IN0 d6 reads 0
        # logs
        self.pokey_writes = []               # (cyc, addr, val)
        self.earom_writes = []               # (cyc, addr, val)
        self.output_writes = []              # (cyc, addr, val) $0C00/$0C80/$0D80
        self.misc_writes = []                # anything unmapped
        # --- DEBUG INSTRUMENTATION ONLY (--trace-write / --trace-pc) ---
        tw = getattr(args, "trace_write", None)
        self.trace_wr = set(tw) if tw else None
        tp = getattr(args, "trace_pc", None)
        self.trace_pcs = set(tp) if tp else None
        self.trace_log = []                  # (frame, irq, pc, addr, val)
        self.trace_pc_log = []               # (frame, irq, pc, a, x, y)
        self.trace_rnd = bool(getattr(args, "trace_random", False))
        self.rnd_count = 0                   # RANDOM reads so far
        self.rnd_log = []                    # (frame, n, pc, value)
        # frames
        self.frame = 0
        self.first_vggo = None
        self.last_vggo_cyc = 0
        self.vggo_log = []                   # per-frame: (frame, cyc, irq_count)
        self.captured = []                   # json entries for captured frames
        # coverage / debug
        self.pc_counts = [0] * 0x10000
        self.pc_hist = deque(maxlen=32)
        self.done = False

    # ---------------- LFSR (see header for the contract) ----------------
    def lfsr_read(self):
        s = self.lfsr
        for _ in range(8):
            s = ((s << 1) | (((s >> 16) ^ (s >> 11)) & 1)) & 0x1FFFF
        self.lfsr = s
        # --- DEBUG INSTRUMENTATION ONLY (--trace-random): observes, never
        # alters.  self.rnd_count is always maintained; the log only fills
        # when the flag is on.
        self.rnd_count += 1
        if self.trace_rnd:
            self.rnd_log.append((self.frame, self.rnd_count,
                                 self.pc_hist[-1] if self.pc_hist else 0,
                                 s & 0xFF))
        return s & 0xFF

    # ---------------- bus ----------------
    def in0(self):
        v = self.in0_base
        if (self.cyc // CLOCK3K_HALF) & 1:
            v |= 0x80
        if self.cyc >= self.vg_busy_until:
            v |= 0x40
        return v

    def rd(self, a):
        a &= 0xFFFF
        if a < 0x400:
            return self.ram[a]
        if a >= 0x2800:
            return self.mem[a]
        if 0x2000 <= a < 0x2800:
            return self.vram[a - 0x2000]
        if a == 0x0800:
            return self.in0()
        if 0x0900 <= a < 0x0908:
            return self.in1[a - 0x0900]
        if a == 0x0A00:
            return 0x00                       # blank EAROM
        if 0x1000 <= a < 0x1800:
            if (a & 0xFF) == 0x0A:            # RANDOM, either POKEY
                return self.lfsr_read()
            if a in self.dip:                 # ALLPOT option ports
                return self.dip[a]
            return 0x00
        return 0x00                           # unmapped / write-only

    def rd16(self, a):
        return self.rd(a) | (self.rd(a + 1) << 8)

    def wr(self, a, v):
        a &= 0xFFFF
        v &= 0xFF
        # --- DEBUG INSTRUMENTATION ONLY (--trace-write): does not alter the
        # hardware model, only observes it.  Off unless the flag is given.
        if self.trace_wr is not None and a in self.trace_wr:
            pc0 = self.pc_hist[-1] if self.pc_hist else 0
            self.trace_log.append((self.frame, self.irq_count, pc0, a, v))
        if a < 0x400:
            self.ram[a] = v
        elif 0x2000 <= a < 0x2800:
            self.vram[a - 0x2000] = v
        elif a == 0x0C80:
            self.output_writes.append((self.cyc, a, v))
            self.vggo()
        elif a == 0x0C00 or a == 0x0D80:
            self.output_writes.append((self.cyc, a, v))
        elif a == 0x0D00:
            pass                              # watchdog: healthy board
        elif a == 0x0E00:
            self.irq_line = False             # IRQACK
        elif a == 0x0E80 or 0x0F00 <= a < 0x0F40:
            self.earom_writes.append((self.cyc, a, v))
        elif 0x1000 <= a < 0x1800:
            self.pokey_writes.append((self.cyc, a, v))
        else:
            self.misc_writes.append((self.cyc, a, v))

    # ---------------- frames ----------------
    def frame_selected(self, f):
        # --- DEBUG INSTRUMENTATION ONLY (--capture-range): widens WHICH
        # frames are dumped.  It does not touch the hardware model, so the
        # bytes dumped for any frame are identical either way.  Never use
        # it to regenerate c_src/tests/ref.
        cr = getattr(self.args, "capture_range", None)
        if cr and cr[0] <= f <= cr[1]:
            return True
        # --capture-every N: a denser regular sample for short scenarios
        # (the self-test refs).  Selection only; the bytes are the same.
        ce = getattr(self.args, "capture_every", 0)
        if ce:
            return f <= 16 or f % ce == 0
        return f <= 16 or f % 32 == 0

    def vggo(self):
        self.vg_busy_until = self.cyc + self.args.vg_draw_cycles
        self.frame += 1
        f = self.frame
        if self.first_vggo is None:
            self.first_vggo = self.cyc
        self.last_vggo_cyc = self.cyc
        self.vggo_log.append((f, self.cyc, self.irq_count))
        note = ""
        for ev in self.events.get(f, []):
            note = self.apply_event(ev, note)
        if self.frame_selected(f) and f <= self.args.frames:
            with open(os.path.join(self.args.outdir, "frame_%04d.vram" % f), "wb") as fh:
                fh.write(self.vram)
            with open(os.path.join(self.args.outdir, "frame_%04d.ram" % f), "wb") as fh:
                fh.write(self.ram)
            self.captured.append({"frame": f, "cycle": self.cyc,
                                  "irq_count": self.irq_count,
                                  "in0": self.in0(), "note": note})
        if f >= self.args.frames:
            self.done = True

    def apply_event(self, ev, note):
        """Scenario events, applied at the VGGO opening the given frame.
        ('in0_set', mask) / ('in0_clear', mask): OR/clear bits in IN0 base.
        ('in1', index, value): set IN1 switch byte $0900+index.
        ('note', text): annotate the ref_index entry."""
        kind = ev[0]
        if kind == "in0_set":
            self.in0_base |= ev[1]
        elif kind == "in0_clear":
            self.in0_base &= ~ev[1] & 0xFF
        elif kind == "in1":
            self.in1[ev[1]] = ev[2] & 0xFF
        elif kind == "note":
            return ev[1]
        else:
            raise OracleError("unknown scenario event %r" % (ev,))
        return note or ("%s" % (ev,))

    # ---------------- CPU ----------------
    def push(self, v):
        self.ram[0x100 + self.sp] = v & 0xFF
        self.sp = (self.sp - 1) & 0xFF

    def pull(self):
        self.sp = (self.sp + 1) & 0xFF
        return self.ram[0x100 + self.sp]

    def setnz(self, v):
        v &= 0xFF
        self.n = v >> 7
        self.z = 1 if v == 0 else 0
        return v

    def flags(self, b):
        return (self.n << 7) | (self.v << 6) | 0x20 | (b << 4) | \
               (self.d << 3) | (self.i << 2) | (self.z << 1) | self.c

    def setflags(self, p):
        self.n = (p >> 7) & 1
        self.v = (p >> 6) & 1
        self.d = (p >> 3) & 1
        self.i = (p >> 2) & 1
        self.z = (p >> 1) & 1
        self.c = p & 1

    def adc(self, v):
        if self.d:
            # NMOS decimal ADC (6502.org appendix, sequence 1)
            al = (self.a & 0x0F) + (v & 0x0F) + self.c
            if al >= 0x0A:
                al = ((al + 0x06) & 0x0F) + 0x10
            s = (self.a & 0xF0) + (v & 0xF0) + al
            self.n = (s >> 7) & 1
            self.v = 1 if (~(self.a ^ v) & (self.a ^ s)) & 0x80 else 0
            if s >= 0xA0:
                s += 0x60
            self.z = 1 if ((self.a + v + self.c) & 0xFF) == 0 else 0
            self.c = 1 if s >= 0x100 else 0
            self.a = s & 0xFF
        else:
            r = self.a + v + self.c
            self.v = 1 if (~(self.a ^ v) & (self.a ^ r)) & 0x80 else 0
            self.c = 1 if r > 0xFF else 0
            self.a = self.setnz(r)

    def sbc(self, v):
        if self.d:
            # NMOS decimal SBC (sequence 3): flags from the BINARY computation
            al = (self.a & 0x0F) - (v & 0x0F) + self.c - 1
            if al < 0:
                al = ((al - 0x06) & 0x0F) - 0x10
            s = (self.a & 0xF0) - (v & 0xF0) + al
            if s < 0:
                s -= 0x60
            r = self.a + (v ^ 0xFF) + self.c
            self.v = 1 if (~(self.a ^ (v ^ 0xFF)) & (self.a ^ r)) & 0x80 else 0
            self.c = 1 if r > 0xFF else 0
            self.setnz(r)
            self.a = s & 0xFF
        else:
            r = self.a + (v ^ 0xFF) + self.c
            self.v = 1 if (~(self.a ^ (v ^ 0xFF)) & (self.a ^ r)) & 0x80 else 0
            self.c = 1 if r > 0xFF else 0
            self.a = self.setnz(r)

    def cmp_(self, r, v):
        self.c = 1 if r >= v else 0
        self.setnz(r - v)

    def fatal(self, msg):
        hist = " ".join("%04X" % p for p in self.pc_hist)
        raise OracleError("%s\n  cycle=%d frame=%d irq_count=%d\n  last PCs: %s"
                          % (msg, self.cyc, self.frame, self.irq_count, hist))

    def step(self):
        # IRQ line assertion (level held until IRQACK write to $0E00)
        if self.cyc >= self.next_irq:
            self.irq_line = True
            while self.cyc >= self.next_irq:
                self.next_irq += IRQ_PERIOD
        if self.irq_line and not self.i_poll:
            self.push(self.pc >> 8)
            self.push(self.pc & 0xFF)
            self.push(self.flags(0))
            self.i = 1
            self.i_poll = 1
            self.pc = self.rd16(0xFFFE)
            self.cyc += 7
            self.irq_count += 1
            return
        pc0 = self.pc
        self.pc_counts[pc0] += 1
        self.pc_hist.append(pc0)
        # --- DEBUG INSTRUMENTATION ONLY (--trace-pc): observes, never alters.
        if self.trace_pcs is not None and pc0 in self.trace_pcs:
            self.trace_pc_log.append((self.frame, self.irq_count, pc0,
                                      self.a, self.x, self.y))
        op = self.rd(pc0)
        ent = OPCODES.get(op)
        if ent is None:
            self.fatal("undocumented opcode $%02X at $%04X" % (op, pc0))
        mn, md, cy = ent
        if mn == "BRK":
            self.fatal("BRK at $%04X (not expected in this ROM)" % pc0)
        self.pc = (pc0 + 1) & 0xFFFF
        self.cyc += cy
        i_before = self.i                     # for the CLI/SEI/PLP poll rule

        # effective address / operand
        rd, rd16 = self.rd, self.rd16
        if md == "imp" or md == "acc":
            ea = None
        elif md == "imm":
            ea = self.pc
            self.pc = (self.pc + 1) & 0xFFFF
        elif md == "zp":
            ea = rd(self.pc)
            self.pc = (self.pc + 1) & 0xFFFF
        elif md == "zpx":
            ea = (rd(self.pc) + self.x) & 0xFF
            self.pc = (self.pc + 1) & 0xFFFF
        elif md == "zpy":
            ea = (rd(self.pc) + self.y) & 0xFF
            self.pc = (self.pc + 1) & 0xFFFF
        elif md == "abs":
            ea = rd16(self.pc)
            self.pc = (self.pc + 2) & 0xFFFF
        elif md == "abx":
            ea = (rd16(self.pc) + self.x) & 0xFFFF
            self.pc = (self.pc + 2) & 0xFFFF
        elif md == "aby":
            ea = (rd16(self.pc) + self.y) & 0xFFFF
            self.pc = (self.pc + 2) & 0xFFFF
        elif md == "izx":
            z = (rd(self.pc) + self.x) & 0xFF
            self.pc = (self.pc + 1) & 0xFFFF
            ea = rd(z) | (rd((z + 1) & 0xFF) << 8)
        elif md == "izy":
            z = rd(self.pc)
            self.pc = (self.pc + 1) & 0xFFFF
            ea = ((rd(z) | (rd((z + 1) & 0xFF) << 8)) + self.y) & 0xFFFF
        elif md == "ind":
            a = rd16(self.pc)
            self.pc = (self.pc + 2) & 0xFFFF
            # 6502 JMP-indirect page-wrap bug
            ea = rd(a) | (rd((a & 0xFF00) | ((a + 1) & 0xFF)) << 8)
        elif md == "rel":
            d = rd(self.pc)
            self.pc = (self.pc + 1) & 0xFFFF
            ea = (self.pc + (d - 256 if d > 127 else d)) & 0xFFFF
        else:
            self.fatal("bad mode %s" % md)

        m = mn
        if m == "LDA":
            self.a = self.setnz(rd(ea))
        elif m == "LDX":
            self.x = self.setnz(rd(ea))
        elif m == "LDY":
            self.y = self.setnz(rd(ea))
        elif m == "STA":
            self.wr(ea, self.a)
        elif m == "STX":
            self.wr(ea, self.x)
        elif m == "STY":
            self.wr(ea, self.y)
        elif m == "ADC":
            self.adc(rd(ea))
        elif m == "SBC":
            self.sbc(rd(ea))
        elif m == "AND":
            self.a = self.setnz(self.a & rd(ea))
        elif m == "ORA":
            self.a = self.setnz(self.a | rd(ea))
        elif m == "EOR":
            self.a = self.setnz(self.a ^ rd(ea))
        elif m == "CMP":
            self.cmp_(self.a, rd(ea))
        elif m == "CPX":
            self.cmp_(self.x, rd(ea))
        elif m == "CPY":
            self.cmp_(self.y, rd(ea))
        elif m == "BIT":
            t = rd(ea)
            self.n = t >> 7
            self.v = (t >> 6) & 1
            self.z = 1 if (self.a & t) == 0 else 0
        elif m == "ASL":
            if ea is None:
                self.c = self.a >> 7
                self.a = self.setnz(self.a << 1)
            else:
                t = rd(ea)
                self.c = t >> 7
                self.wr(ea, self.setnz(t << 1))
        elif m == "LSR":
            if ea is None:
                self.c = self.a & 1
                self.a = self.setnz(self.a >> 1)
            else:
                t = rd(ea)
                self.c = t & 1
                self.wr(ea, self.setnz(t >> 1))
        elif m == "ROL":
            if ea is None:
                t = (self.a << 1) | self.c
                self.c = 1 if t > 0xFF else 0
                self.a = self.setnz(t)
            else:
                t = (rd(ea) << 1) | self.c
                self.c = 1 if t > 0xFF else 0
                self.wr(ea, self.setnz(t))
        elif m == "ROR":
            if ea is None:
                t = self.a | (self.c << 8)
                self.c = t & 1
                self.a = self.setnz(t >> 1)
            else:
                t = rd(ea) | (self.c << 8)
                self.c = t & 1
                self.wr(ea, self.setnz(t >> 1))
        elif m == "INC":
            self.wr(ea, self.setnz(rd(ea) + 1))
        elif m == "DEC":
            self.wr(ea, self.setnz(rd(ea) - 1))
        elif m == "INX":
            self.x = self.setnz(self.x + 1)
        elif m == "INY":
            self.y = self.setnz(self.y + 1)
        elif m == "DEX":
            self.x = self.setnz(self.x - 1)
        elif m == "DEY":
            self.y = self.setnz(self.y - 1)
        elif m == "TAX":
            self.x = self.setnz(self.a)
        elif m == "TAY":
            self.y = self.setnz(self.a)
        elif m == "TXA":
            self.a = self.setnz(self.x)
        elif m == "TYA":
            self.a = self.setnz(self.y)
        elif m == "TSX":
            self.x = self.setnz(self.sp)
        elif m == "TXS":
            self.sp = self.x
        elif m == "PHA":
            self.push(self.a)
        elif m == "PLA":
            self.a = self.setnz(self.pull())
        elif m == "PHP":
            self.push(self.flags(1))
        elif m == "PLP":
            self.setflags(self.pull())
        elif m == "JMP":
            self.pc = ea
        elif m == "JSR":
            r = (self.pc - 1) & 0xFFFF
            self.push(r >> 8)
            self.push(r & 0xFF)
            self.pc = ea
        elif m == "RTS":
            lo = self.pull()
            hi = self.pull()
            self.pc = (((hi << 8) | lo) + 1) & 0xFFFF
        elif m == "RTI":
            self.setflags(self.pull())
            lo = self.pull()
            hi = self.pull()
            self.pc = (hi << 8) | lo
        elif m in ("BPL", "BMI", "BVC", "BVS", "BCC", "BCS", "BNE", "BEQ"):
            take = {"BPL": not self.n, "BMI": self.n,
                    "BVC": not self.v, "BVS": self.v,
                    "BCC": not self.c, "BCS": self.c,
                    "BNE": not self.z, "BEQ": self.z}[m]
            if take:
                self.pc = ea
                self.cyc += 1                 # approximate: no page penalty
        elif m == "CLC":
            self.c = 0
        elif m == "SEC":
            self.c = 1
        elif m == "CLI":
            self.i = 0
        elif m == "SEI":
            self.i = 1
        elif m == "CLV":
            self.v = 0
        elif m == "CLD":
            self.d = 0
        elif m == "SED":
            self.d = 1
        elif m == "NOP":
            pass
        else:
            self.fatal("unhandled mnemonic %s" % m)
        # MAME's poll rule (header, CPU): CLI/SEI/PLP are polled with the
        # I they started with; everything else, RTI included, with the new I.
        self.i_poll = i_before if m in ("CLI", "SEI", "PLP") else self.i

    def run(self):
        self.pc = self.rd16(0xFFFC)
        check_at = 0
        while not self.done:
            self.step()
            if self.cyc >= check_at:          # stall detector, checked coarsely
                check_at = self.cyc + 100_000
                if self.first_vggo is None:
                    if self.cyc > BOOT_LIMIT:
                        self.fatal("no VGGO within %ds of reset — boot stalled at $%04X"
                                   % (BOOT_LIMIT // CPU_HZ, self.pc))
                elif self.cyc - self.last_vggo_cyc > STALL_LIMIT:
                    self.fatal("no VGGO for %ds (last frame %d) — stalled at $%04X"
                               % (STALL_LIMIT // CPU_HZ, self.frame, self.pc))


# --------------------------------------------------------------------------
# Coverage: map executed PCs onto the annotated listing's named labels.
# --------------------------------------------------------------------------
def parse_listing():
    """Parse spaceduel_program_rom.asm.
    Returns (addr_set, named_starts, unnamed_entries):
      addr_set       — every $Lxxxx address present in the listing
      named_starts   — sorted [(addr, name)]: start address of each named,
                       non-local routine (labels 'Base_N' fold into 'Base')
      unnamed_entries— JSR/JMP targets written as bare Lxxxx (no name given
                       by the naming pass)"""
    lab_re = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):")
    addr_re = re.compile(r"^L([0-9A-F]{4}):")
    op_ref_re = re.compile(r"^L[0-9A-F]{4}:\s+(?:JSR|JMP)\s+L([0-9A-F]{4})\b")
    local_re = re.compile(r"^(.+)_(\d+)$")
    addr_set = set()
    named_starts = []
    unnamed_entries = set()
    seen = set()
    pending = None          # name waiting for its first Lxxxx address
    with open(ASM_PATH, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            ma = addr_re.match(line)
            if ma:
                addr = int(ma.group(1), 16)
                addr_set.add(addr)
                if pending is not None:
                    named_starts.append((addr, pending))
                    pending = None
                mo = op_ref_re.match(line)
                if mo:
                    unnamed_entries.add(int(mo.group(1), 16))
                continue
            ml = lab_re.match(line)
            if ml:
                name = ml.group(1)
                lm = local_re.match(name)
                if lm and lm.group(1) in seen:
                    continue                  # local label: same routine
                seen.add(name)
                pending = name
    named_starts.sort()
    # entries that actually have names are not "unnamed"
    starts = {a for a, _ in named_starts}
    unnamed_entries = {a for a in unnamed_entries if a not in starts}
    return addr_set, named_starts, unnamed_entries


def norm_pc(pc):
    """Fold the $9000-$FFFF mirror of J1 back onto $8000-$8FFF."""
    return 0x8000 | (pc & 0x0FFF) if pc >= 0x9000 else pc


def write_coverage(sim, path, scenario):
    addr_set, named_starts, unnamed_entries = parse_listing()
    counts = {}
    for pc, n in enumerate(sim.pc_counts):
        if n:
            p = norm_pc(pc)
            counts[p] = counts.get(p, 0) + n
    starts = [a for a, _ in named_starts]
    names = [nm for _, nm in named_starts]

    import bisect
    per_routine = {}          # name -> [start, distinct, dynamic]
    unmapped = []             # executed PCs with no preceding named label
    not_in_listing = []       # executed PCs absent from the listing entirely
    for pc in sorted(counts):
        if pc not in addr_set:
            not_in_listing.append(pc)
        idx = bisect.bisect_right(starts, pc) - 1
        if idx < 0:
            unmapped.append(pc)
            continue
        nm = names[idx]
        r = per_routine.setdefault(nm, [starts[idx], 0, 0])
        r[1] += 1
        r[2] += counts[pc]

    # executed ranges that begin at an anonymous JSR/JMP entry point
    anon_ranges = []
    for entry in sorted(unnamed_entries):
        if entry not in counts:
            continue
        idx = bisect.bisect_right(starts, entry)
        limit = starts[idx] if idx < len(starts) else 0x9000
        run_pcs = [p for p in sorted(counts) if entry <= p < limit]
        # stop the range at the first gap > 3 bytes (next routine's tail etc.)
        end = entry
        for p in run_pcs:
            if p - end > 3:
                break
            end = p
        anon_ranges.append((entry, end))

    def ranges_of(pcs):
        out = []
        for p in pcs:
            if out and p - out[-1][1] <= 3:
                out[-1][1] = p
            else:
                out.append([p, p])
        return out

    total_named = len(named_starts)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        w = fh.write
        w("# Space Duel oracle — PC coverage, scenario `%s`\n\n" % scenario)
        w("Generated by c_src/tools/oracle.py against "
          "disasm/spaceduel_program_rom.asm.\n")
        w("Frames simulated: %d; instructions executed: %d; distinct PCs: %d.\n"
          % (sim.frame, sum(counts.values()), len(counts)))
        w("PCs in the J1 mirror ($9000-$FFFF) are folded onto $8000-$8FFF.\n\n")
        w("## Named routines executed (%d of %d named labels)\n\n"
          % (len(per_routine), total_named))
        w("| routine | start | distinct PCs | dynamic count |\n")
        w("|---|---|---:|---:|\n")
        for nm, (st, dist, dyn) in sorted(per_routine.items(), key=lambda kv: kv[1][0]):
            w("| %s | $%04X | %d | %d |\n" % (nm, st, dist, dyn))
        w("\n## Executed ranges with NO named label\n\n")
        w("Anonymous JSR/JMP entry points (the naming pass left them as bare\n"
          "Lxxxx); coverage above attributes them to the nearest preceding\n"
          "named label, so they are broken out here:\n\n")
        if anon_ranges:
            for a, b in anon_ranges:
                w("- $%04X-$%04X (entered via `JSR/JMP L%04X`)\n" % (a, b, a))
        else:
            w("- (none)\n")
        w("\nExecuted PCs not present as `Lxxxx:` lines in the listing at all\n"
          "(would indicate the listing and the oracle disagree):\n\n")
        if not_in_listing:
            for a, b in ranges_of(not_in_listing):
                w("- $%04X-$%04X\n" % (a, b))
        else:
            w("- (none)\n")
        if unmapped:
            w("\nExecuted PCs before the first named label:\n\n")
            for a, b in ranges_of(unmapped):
                w("- $%04X-$%04X\n" % (a, b))
    return per_routine, anon_ranges, not_in_listing


# --------------------------------------------------------------------------
# Scenarios.  A scenario is a dict {frame_number: [event, ...]} applied at the
# VGGO that opens that frame — see Oracle.apply_event for event kinds.  Future
# scenarios (coin insertion, scripted gameplay) add entries here, e.g.:
#   def scenario_coin():
#       ev = {1: [("in0_set", 0x0B), ("note", "slam off, coins absent")]}
#       ev[120] = [("in0_clear", 0x02), ("note", "COIN1 down")]
#       ev[130] = [("in0_set", 0x02), ("note", "COIN1 up")]
#       return ev
# --------------------------------------------------------------------------
def scenario_attract():
    return {}


# --- self-test scenarios (c_src/selftest.c, probe tests/probe_selftest.c) ---
#
# IN0 polarity for these: d4 = 0 is TEST ON; the diagnostics treat d5 (diag
# step) OR d3 (slam) LOW as "switch pushed" ($85B3 AND #$28), so a diag
# scenario must idle both HIGH or the screens step every 3 frames.  The
# attract portions keep the attract oracle's idle low nibble (coins present +
# slam tripped = no credits) so the captured attract frames stay comparable;
# d5 is never read by the game path.

def scenario_selftest():
    """Attract, then the switch on -> bookkeeping (St2), SELECT stepped
    through the four options, START+SELECT on option 0 -> RESET with the
    switch still on -> the power-on diagnostics, stepped through all six
    screens (with a switch shown, the color switch, and the wrap to 2)."""
    ev = {0: [("in0_set", 0x20), ("note", "diag step not pressed")]}
    ev[100] = [("in0_clear", 0x10), ("in0_set", 0x08),
               ("note", "SELF TEST on (slam off) -> bookkeeping")]
    for i, f in enumerate((120, 130, 140, 150)):     # SELECT x4: option 1,2,3,0
        ev[f] = [("in1", 6, 0x80), ("note", "SELECT down")]
        ev[f + 4] = [("in1", 6, 0x00), ("note", "SELECT up -> option %d" % ((i + 1) & 3))]
    ev[170] = [("in1", 4, 0x40), ("in1", 6, 0x80),
               ("note", "START+SELECT, option 0 -> RESET -> diagnostics")]
    ev[174] = [("in1", 4, 0x00), ("in1", 6, 0x00), ("note", "released")]
    ev[190] = [("in1", 0, 0xC0), ("note", "shield+fire shown on the switch line")]
    ev[200] = [("in1", 0, 0x00)]
    for f, obj in ((220, 4), (250, 6), (330, 8), (360, 0x0A), (410, 2)):
        ev[f] = [("in0_clear", 0x20), ("note", "DIAG STEP down")]
        ev[f + 6] = [("in0_set", 0x20), ("note", "DIAG STEP up -> OBJ $%02X" % obj)]
    ev[380] = [("in1", 6, 0x80), ("note", "SELECT: crosshatch color switch")]
    ev[390] = [("in1", 6, 0x00)]
    return ev


def scenario_selftest_exit():
    """Attract, switch on -> bookkeeping, switch off -> Pwron -> attract."""
    ev = {0: [("in0_set", 0x20)]}
    ev[60] = [("in0_clear", 0x10), ("in0_set", 0x08),
              ("note", "SELF TEST on -> bookkeeping")]
    ev[120] = [("in0_set", 0x10), ("note", "SELF TEST off -> Pwron")]
    return ev


def scenario_selftest_boot():
    """Power-on with the switch on: RAM marches, checksums, POKEY/EAROM
    checks, then the diagnostic screens from cold; coins absent."""
    ev = {0: [("in0_clear", 0x10), ("in0_set", 0x2F),
              ("note", "SELF TEST on at RESET; step/slam/coins idle high")]}
    for f, obj in ((40, 4), (80, 6), (160, 8), (200, 0x0A), (240, 2)):
        ev[f] = [("in0_clear", 0x20), ("note", "DIAG STEP down")]
        ev[f + 6] = [("in0_set", 0x20), ("note", "DIAG STEP up -> OBJ $%02X" % obj)]
    return ev


def scenario_play():
    """A game: slam off + coins absent, COIN1 pulsed 10 frames (>= 5 IRQs
    low), SELECT, START, then a scripted pilot (rotate / thrust / fire
    bursts) for as long as the run lasts.  Used to measure the ROM's frame
    cadence DURING PLAY (NOTES_selftest.md postscript) and as the seed of
    the play-mode probe (Gate P)."""
    ev = {1: [("in0_set", 0x0F), ("note", "slam off, coins absent")]}
    ev[60] = [("in0_clear", 0x02), ("note", "COIN1 down")]
    ev[70] = [("in0_set", 0x02), ("note", "COIN1 up; credit ~120 IRQs later")]
    ev[110] = [("in1", 6, 0x80), ("note", "SELECT down (unlocks START)")]
    ev[116] = [("in1", 6, 0x00)]
    ev[130] = [("in1", 4, 0x40), ("note", "START down")]
    ev[140] = [("in1", 4, 0x00), ("note", "START up: playing")]
    f = 160
    while f < 2000:                                   # the pilot
        ev[f] = [("in1", 2, 0x80)]                    # rotate left
        ev[f + 12] = [("in1", 2, 0x00), ("in1", 4, 0x80)]   # thrust
        ev[f + 24] = [("in1", 4, 0x00)]
        for k in range(0, 24, 6):                     # fire, edge-detected
            ev[f + 30 + k] = [("in1", 0, 0x40)]
            ev[f + 33 + k] = [("in1", 0, 0x00)]
        f += 60
    return ev


SCENARIOS = {"attract": scenario_attract,
             "play": scenario_play,
             "selftest": scenario_selftest,
             "selftest_exit": scenario_selftest_exit,
             "selftest_boot": scenario_selftest_boot}


def write_scenario(events, path):
    """scenario.txt: every input event, one per line '<frame> <kind> <args>',
    so a probe replays exactly the switch changes the oracle applied (at
    the VGGO opening that frame; frame 0 = at RESET).  Notes are comments."""
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("# <frame> in0_set|in0_clear <mask> | in1 <index> <value>\n")
        for f in sorted(events):
            for ev in events[f]:
                if ev[0] == "note":
                    fh.write("# %d: %s\n" % (f, ev[1]))
                elif ev[0] in ("in0_set", "in0_clear"):
                    fh.write("%d %s 0x%02X\n" % (f, ev[0], ev[1]))
                elif ev[0] == "in1":
                    fh.write("%d in1 %d 0x%02X\n" % (f, ev[1], ev[2]))


def main():
    ap = argparse.ArgumentParser(description="Space Duel differential-test oracle")
    ap.add_argument("scenario", nargs="?", default="attract", choices=sorted(SCENARIOS))
    ap.add_argument("--frames", type=int, default=600)
    ap.add_argument("--outdir", default=os.path.join(PROJECT_ROOT, "c_src", "tests", "ref"))
    ap.add_argument("--vg-draw-cycles", type=int, default=4000,
                    help="cycles IN0 d6 (VG HALT) stays 0 after a VGGO (default 4000)")
    ap.add_argument("--dip1008", type=lambda s: int(s, 0), default=0x00,
                    help="byte returned by reads of $1008 (POKEY1 option port)")
    ap.add_argument("--dip1408", type=lambda s: int(s, 0), default=0x00,
                    help="byte returned by reads of $1408 (POKEY2 option port)")
    ap.add_argument("--roms", default=None,
                    help="ROM directory or zip (default: the disasm/build "
                         "image, else <root>/roms)")
    # --- DEBUG INSTRUMENTATION ONLY: these flags add observation, they do
    # not change the hardware model or the reference bytes.  Use a scratch
    # --outdir when tracing; never regenerate c_src/tests/ref with them.
    ap.add_argument("--trace-write", type=lambda s: int(s, 0), action="append",
                    metavar="ADDR",
                    help="log every write to ADDR as frame/irq/pc/value "
                         "(repeatable); debug only")
    ap.add_argument("--trace-pc", type=lambda s: int(s, 0), action="append",
                    metavar="ADDR",
                    help="log every execution of ADDR with A/X/Y "
                         "(repeatable); debug only")
    ap.add_argument("--irq-marks", type=lambda s: int(s, 0), metavar="PC",
                    action="append",
                    help="write <outdir>/irq_marks.txt: the irq_count at "
                         "every execution of PC (implies --trace-pc PC; "
                         "repeatable - each PC becomes a numbered sync "
                         "point).  Lets a probe replay the IRQ schedule at "
                         "points inside the mainline pass, not only at the "
                         "VGGO.")
    ap.add_argument("--capture-range",
                    type=lambda s: tuple(int(p, 0) for p in s.split(":")),
                    metavar="A:B",
                    help="also dump every frame in [A,B] (debug only - use a "
                         "scratch --outdir, never c_src/tests/ref)")
    ap.add_argument("--capture-every", type=int, default=0, metavar="N",
                    help="dump frames 1-16 and every Nth frame instead of "
                         "every 32nd (the self-test refs use 4)")
    ap.add_argument("--trace-random", action="store_true",
                    help="log every RANDOM ($x00A) read as frame/n/pc/value; "
                         "debug only")
    ap.add_argument("--trace-max", type=int, default=200,
                    help="max trace lines printed per trace list")
    ap.add_argument("--trace-out", default=None,
                    help="write the full trace to this file instead of stdout")
    args = ap.parse_args()
    if args.irq_marks:
        args.trace_pc = (args.trace_pc or []) + list(args.irq_marks)
    os.makedirs(args.outdir, exist_ok=True)

    events = SCENARIOS[args.scenario]()
    write_scenario(events, os.path.join(args.outdir, "scenario.txt"))
    sim = Oracle(load_image(args.roms), args, events)
    t0 = time.time()
    err = None
    try:
        sim.run()
    except OracleError as e:
        err = str(e)
    wall = time.time() - t0

    # ref_index.json — captured frames + irq_count at EVERY VGGO
    index = {
        "scenario": args.scenario,
        "rom": "spacduel_64k.bin",
        "model": {
            "cpu_hz": CPU_HZ,
            "irq_period_cycles": IRQ_PERIOD,
            "clock3k_half_cycles": CLOCK3K_HALF,
            "vg_draw_cycles": args.vg_draw_cycles,
            "dip1008": args.dip1008,
            "dip1408": args.dip1408,
            "lfsr": "17-bit, seed 0x1FFFF, 8 shifts/read of "
                    "s=((s<<1)|(((s>>16)^(s>>11))&1))&0x1FFFF, return s&0xFF",
            "cycles": "approximate: base table, +1 taken branch, no page penalties",
            "irq_poll": "MAME m6502: CLI/SEI/PLP polled with the prior I, RTI with the new",
        },
        "frames_total": sim.frame,
        "error": err,
        "captured": sim.captured,
        "vggo": [{"frame": f, "cycle": c, "irq_count": q} for f, c, q in sim.vggo_log],
    }
    with open(os.path.join(args.outdir, "ref_index.json"), "w", encoding="utf-8") as fh:
        json.dump(index, fh, indent=1)

    # --- IRQ landmark schedule (--irq-marks): the irq_count at each
    # execution of a chosen mainline PC.  Same principle as vggo_sched.txt
    # (replay the machine's recorded IRQ schedule), one sample per pass
    # finer.  Observation only; the hardware model is untouched.
    if args.irq_marks:
        slot = {pc: i for i, pc in enumerate(args.irq_marks)}
        path = os.path.join(args.outdir, "irq_marks.txt")
        n = 0
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("# mainline IRQ sync points: <point> <frame> <irq_count>\n")
            for i, pc in enumerate(args.irq_marks):
                fh.write("# point %d = PC $%04X\n" % (i, pc))
            for f, q, pc0, a, x, y in sim.trace_pc_log:
                if pc0 in slot:
                    fh.write("%d %d %d\n" % (slot[pc0], f, q))
                    n += 1
        print("irq marks -> %s (%d samples, %d points)"
              % (path, n, len(args.irq_marks)))

    cov_path = os.path.join(args.outdir, "coverage_%s.md" % args.scenario)
    write_coverage(sim, cov_path, args.scenario)

    # console summary
    print("scenario %s: %d frames, %d cycles (%.2fs simulated), %d IRQs, %.1fs wall"
          % (args.scenario, sim.frame, sim.cyc, sim.cyc / CPU_HZ, sim.irq_count, wall))
    if sim.vggo_log:
        print("first VGGO at cycle %d; IRQs at first 16 frames: %s"
              % (sim.first_vggo, [q for _, _, q in sim.vggo_log[:16]]))
        deltas = {}
        prev = None
        for _, _, q in sim.vggo_log:
            if prev is not None:
                d = q - prev
                deltas[d] = deltas.get(d, 0) + 1
            prev = q
        print("IRQs-per-frame distribution:", dict(sorted(deltas.items())))
    print("pokey writes: %d, earom writes: %d, output writes: %d, misc writes: %d"
          % (len(sim.pokey_writes), len(sim.earom_writes),
             len(sim.output_writes), len(sim.misc_writes)))
    if sim.misc_writes:
        print("  first misc writes:", [("$%04X" % a, v) for _, a, v in sim.misc_writes[:8]])

    print("RANDOM reads: %d" % sim.rnd_count)

    # --- DEBUG INSTRUMENTATION ONLY: dump whatever --trace-* collected. ---
    if sim.trace_log or sim.trace_pc_log or sim.rnd_log:
        lines = []
        if sim.rnd_log:
            lines.append("RANDOM TRACE (%d reads)" % len(sim.rnd_log))
            lines.append("  frame      n     pc    val")
            for f, n, pc0, v in sim.rnd_log:
                lines.append("  %5d %6d  $%04X  $%02X" % (f, n, pc0, v))
        if sim.trace_log:
            lines.append("WRITE TRACE (%d hits)" % len(sim.trace_log))
            lines.append("  frame   irq     pc     addr  val")
            for f, q, pc0, a, v in sim.trace_log:
                lines.append("  %5d %6d  $%04X  $%04X  $%02X" % (f, q, pc0, a, v))
        if sim.trace_pc_log:
            lines.append("PC TRACE (%d hits)" % len(sim.trace_pc_log))
            lines.append("  frame   irq     pc     A   X   Y")
            for f, q, pc0, a, x, y in sim.trace_pc_log:
                lines.append("  %5d %6d  $%04X  $%02X  $%02X  $%02X"
                             % (f, q, pc0, a, x, y))
        if args.trace_out:
            with open(args.trace_out, "w", encoding="utf-8") as fh:
                fh.write("\n".join(lines) + "\n")
            print("trace: %d lines -> %s" % (len(lines), args.trace_out))
        else:
            for ln in lines[:args.trace_max]:
                print(ln)
            if len(lines) > args.trace_max:
                print("  ... %d more trace lines (use --trace-out)"
                      % (len(lines) - args.trace_max))

    if err:
        print("ABORTED:", err)
        sys.exit(1)


if __name__ == "__main__":
    main()
