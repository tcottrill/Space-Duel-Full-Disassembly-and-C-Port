"""Encode a 6502 instruction so emitted lines can be byte-checked against ROM."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import m6502
from m6502 import (IMP,ACC,IMM,ZP,ZPX,ZPY,ABS,ABX,ABY,IND,IZX,IZY,REL,SIZE)

def encode(mn, mode, value, pc):
    """Return the byte list for one instruction, or None if it cannot encode."""
    mn = mn.upper()
    t = m6502.TAB.get(mn)
    if not t or mode not in t:
        return None
    op = t[mode]
    if mode in (IMP, ACC):
        return [op]
    if mode == REL:
        off = (value - (pc + 2)) & 0xFF
        d = value - (pc + 2)
        if d < -128 or d > 127:
            return None
        return [op, off]
    if SIZE[mode] == 2:
        if not 0 <= value <= 0xFF:
            return None
        return [op, value]
    return [op, value & 0xFF, (value >> 8) & 0xFF]

def verify(mem, pc, mn, mode, value):
    b = encode(mn, mode, value, pc)
    if b is None:
        return False
    return all(mem.get(pc + i) == v for i, v in enumerate(b))

if __name__ == "__main__":
    import image
    mem = image.load()
    # round-trip every reachable instruction: decode then re-encode must match
    import trace
    t = trace.default_trace(mem)
    bad = 0
    for a in sorted(t.starts):
        mn, mode, val, n = t.instr[a]
        if not verify(mem, a, mn, mode, val):
            bad += 1
            if bad <= 5:
                print("  round-trip FAIL at $%04X: %s %s %r" % (a, mn, m6502.MODE_NAME[mode], val))
    print("round-trip check: %d instructions, %d failures" % (len(t.starts), bad))
