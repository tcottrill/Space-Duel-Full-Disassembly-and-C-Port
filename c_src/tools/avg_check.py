"""avg_check.py - Python cross-check for c_src/avg.c.

Builds byte-for-byte the same display list as c_src/tests/avg_dump.c, walks
it with an equivalent Python AVG (same flat memory map, reusing the verified
decoder helpers from disasm/avg.py), and prints segments in the identical
format. Diff this output against avg_dump.exe's:

    py c_src/tools/avg_check.py > check.txt
    avg_dump.exe > dump.txt
    fc check.txt dump.txt

With an argument, both sides load a 2048-byte vector-RAM capture
(c_src/tests/ref/frame_NNNN.vram) instead of the synthetic list:

    py c_src/tools/avg_check.py c_src/tests/ref/frame_0064.vram

The TIME line is the cycle-true draw time (mame_late_avgdvg.cpp model:
12.096 MHz master clock, 8 cycles per state-PROM tick, timer-register
durations for VCTR/SVEC/CNTR) - see avg.c for the per-op table.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "disasm"))    # the verified decoder
import avg                                          # noqa: E402  (s13, s5)
import paths                                        # noqa: E402

# ---- memory: the same flat map as avg.c ------------------------------------
VRAM = bytearray(0x800)                             # CPU $2000-$27FF

VECROM = paths.rom_bytes(paths.roms_dir(), "136006.106", 0x800)
VECROM += paths.rom_bytes(paths.roms_dir(), "136006.107", 0x1000)
assert len(VECROM) == 0x1800                        # CPU $2800-$3FFF


def fetch(wa):
    """Little-endian word at AVG word address wa; None past the ROMs."""
    off = (wa & 0x1FFF) << 1
    if off < 0x800:
        return VRAM[off] | (VRAM[off + 1] << 8)
    if off < 0x2000:
        return VECROM[off - 0x800] | (VECROM[off - 0x800 + 1] << 8)
    return None


# ---- the same display list avg_dump.c builds -------------------------------
def put_word(cpu_addr, lo, hi):
    off = cpu_addr - 0x2000
    VRAM[off], VRAM[off + 1] = lo & 0xFF, hi & 0xFF


def glyph_jsrl(entry):
    """The stored JSRL word for glyph table entry n ($324A, ASCVG order)."""
    off = (0x324A - 0x2800) + 2 * entry
    return VECROM[off] | (VECROM[off + 1] << 8)


def build_list():
    put_word(0x2000, 0x01, 0xE0)                    # JMPL word $001 -> $2002
    put_word(0x2002, 0x40, 0x80)                    # CNTR (CenterBeamInMiddle)
    put_word(0x2004, 0x00, 0x71)                    # SCAL 1,$00 (~0.498)
    put_word(0x2006, 0xE1, 0x64)                    # COLOR: lum $E, color 1
    a = glyph_jsrl(11)                              # 'A'
    put_word(0x2008, a & 0xFF, a >> 8)
    put_word(0x200A, 0xCE, 0x1F)                    # VCTR dy=-50 (w=$1FCE)...
    put_word(0x200C, 0x64, 0x20)                    # ...dx=+100, z=1 (w=$2064)
    put_word(0x200E, 0xFE, 0x43)                    # SVEC dx=-4, dy=+6, z=7
    b = glyph_jsrl(12)                              # 'B'
    put_word(0x2010, b & 0xFF, b >> 8)
    put_word(0x2012, 0x00, 0x20)                    # HALT


# ---- cycle-true timing helpers (avg.c avg_norm_shifts / avg_timer_reg) -----
AVG_MASTER_HZ = 12096000.0                          # mame_late_avgdvg.cpp:45


def norm_shifts(dvy, dvx):
    i = 0
    while (((dvy ^ (dvy << 1)) & 0x1000) == 0
           and ((dvx ^ (dvx << 1)) & 0x1000) == 0 and i < 16):
        i += 1
        dvy = (dvy & 0x1000) | ((dvy << 1) & 0x1FFF)
        dvx = (dvx & 0x1000) | ((dvx << 1) & 0x1FFF)
    return i


def timer_reg(nnorm, nbin, op1):
    t = 0
    for _ in range(nnorm):
        t = (t >> 1) | (0x4080 if op1 else 0x4000)
    if op1:
        t &= 0xFF
    for _ in range(nbin):
        t = (t >> 1) | (0x4080 if op1 else 0x4000)
    if op1:
        t &= 0xFF
    return t


# ---- the walker: mirrors avg.c op for op -----------------------------------
STOP_NAMES = {0: "HALT", 1: "JUMP0", 2: "STACK_OVER", 3: "STACK_UNDER",
              4: "BADFETCH", 5: "RUNAWAY"}


def run(word_addr=0, out=sys.stdout):
    pc, sp, stack = word_addr & 0x1FFF, 0, []
    x = y = 0.0
    scale = 0.0
    statz = color = 0
    bin_scale = 0
    time_units = 0.0
    cycles = 8                                      # VGGO lead-in PROM tick
    fetched = 0
    stop = 5                                        # RUNAWAY until proven

    while fetched < 0x8000:
        w0 = fetch(pc)
        if w0 is None:
            stop = 4
            break
        pc += 1
        fetched += 1
        op = (w0 >> 13) & 7

        if op in (0, 2):                            # VCTR / SVEC
            if op == 0:
                w1 = fetch(pc)
                if w1 is None:
                    stop = 4
                    break
                pc += 1
                fetched += 1
                dy, dx, z = avg.s13(w0), avg.s13(w1), (w1 >> 13) & 7
                k = norm_shifts(w0 & 0x1FFF, w1 & 0x1FFF)
                cycles += 8 * 8 + (0x8000 - timer_reg(k, bin_scale, False))
            else:
                dx = avg.s5(w0) * 2
                dy = avg.s5(w0 >> 8) * 2
                z = (w0 >> 5) & 7
                k = norm_shifts(((w0 >> 8) & 0x1F) << 8, (w0 & 0x1F) << 8)
                cycles += 6 * 8 + (0x100 -
                                   (timer_reg(k, bin_scale, True) & 0xFF))
            fdx, fdy = dx * scale, dy * scale
            lum = statz if z == 1 else z << 1
            x0, y0 = x, y
            x, y = x + fdx, y + fdy
            time_units += max(abs(fdx), abs(fdy))
            out.write("SEG %.4f %.4f -> %.4f %.4f c=%d l=%d\n"
                      % (x0, y0, x, y, color, lum))
        elif op == 3:                               # STAT / SCAL
            cycles += 7 * 8
            if w0 & 0x1000:
                scale = (((~w0) & 0xFF) / 256.0) / (1 << ((w0 >> 8) & 7))
                bin_scale = (w0 >> 8) & 7
            else:
                statz = (w0 >> 4) & 0xF
                color = w0 & 0x7
        elif op == 4:                               # CNTR
            cycles += 5 * 8 + (0x8000 - timer_reg(norm_shifts(w0 & 0xFF, 0),
                                                  0, False))
            x = y = 0.0
        elif op == 5:                               # JSRL
            a = w0 & 0x1FFF
            cycles += 5 * 8
            if a == 0:
                stop = 1
                break
            if len(stack) >= 7:                     # aae MAXSTACK-1 pushes
                stop = 2
                break
            stack.append(pc)
            pc = a
        elif op == 6:                               # RTSL
            cycles += 4 * 8
            if not stack:
                stop = 3
                break
            pc = stack.pop()
        elif op == 7:                               # JMPL
            a = w0 & 0x1FFF
            cycles += 3 * 8
            if a == 0:
                stop = 1
                break
            pc = a
        else:                                       # op 1: HALT
            cycles += 2 * 8
            stop = 0
            break

    out.write("STOP %s words=%d time=%.4f\n"
              % (STOP_NAMES[stop], fetched, time_units))
    out.write("TIME cycles=%d ms=%.4f\n"
              % (cycles, cycles * 1000.0 / AVG_MASTER_HZ))
    return stop


def load_vram(path):
    with open(path, "rb") as f:
        data = f.read()
    assert len(data) == len(VRAM), "%s: %d bytes" % (path, len(data))
    VRAM[:] = data


if __name__ == "__main__":
    sys.argv = paths.strip_roms_arg(sys.argv)
    if len(sys.argv) > 1:
        load_vram(sys.argv[1])
    else:
        build_list()
    run(0)
