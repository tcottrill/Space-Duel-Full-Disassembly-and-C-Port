"""Read back the emitted .asm and prove it reproduces the ROM byte for byte.

Parses each emitted line, re-encodes it at the address its L-label states, and
compares against roms/. Any disagreement is a real defect in the disassembly.
"""
import sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
import paths
import m6502, image, encode
from m6502 import (IMP,ACC,IMM,ZP,ZPX,ZPY,ABS,ABX,ABY,IND,IZX,IZY,REL)

LINE = re.compile(r"^L([0-9A-F]{4}):\s+(\S+)\s*(.*?)\s*(?:;.*)?$")

def parse_operand(oper, labels, syms, mn):
    """Recover (mode, value) from rendered operand text."""
    o = oper.strip()
    def val(tok):
        tok = tok.strip()
        if tok.startswith("$"):
            return int(tok[1:], 16)
        if tok in labels:
            return labels[tok]
        if tok in syms:
            return syms[tok]
        return None
    if mn in m6502.BRANCHES:
        return REL, val(o)
    if o == "":
        return (ACC if ACC in m6502.TAB[mn] and False else IMP), None
    if o.startswith("#"):
        return IMM, val(o[1:])
    m = re.match(r"^\((.*),X\)$", o)
    if m: return IZX, val(m.group(1))
    m = re.match(r"^\((.*)\),Y$", o)
    if m: return IZY, val(m.group(1))
    m = re.match(r"^\((.*)\)$", o)
    if m: return IND, val(m.group(1))
    m = re.match(r"^(.*),X$", o)
    if m:
        v = val(m.group(1))
        zp_ok = ZPX in m6502.TAB[mn]
        return (ZPX if zp_ok and v is not None and v < 0x100 else ABX), v
    m = re.match(r"^(.*),Y$", o)
    if m:
        v = val(m.group(1))
        # there is no LDA/STA zp,Y - only LDX/STX have it, so abs,Y is forced
        zp_ok = ZPY in m6502.TAB[mn]
        return (ZPY if zp_ok and v is not None and v < 0x100 else ABY), v
    v = val(o)
    zp_ok = ZP in m6502.TAB[mn]
    return (ZP if zp_ok and v is not None and v < 0x100 else ABS), v

def run(path=None):
    path = path or paths.PROGRAM_ROM
    mem = image.load()
    labels, syms = {}, {}
    text = open(path).read().splitlines()
    # first pass: label addresses
    cur = None
    for ln in text:
        m = LINE.match(ln)
        if m:
            cur = int(m.group(1), 16)
            continue
        s = ln.strip()
        if s.endswith(":") and not s.startswith(";"):
            pass
    # labels come from the L-address on the following code line
    prev_names = []
    for ln in text:
        s = ln.strip()
        m = LINE.match(ln)
        if m:
            a = int(m.group(1), 16)
            for nm in prev_names:
                labels[nm] = a
            prev_names = []
            # the "L%04X:" prefix is itself a label definition in Ophis
            labels["L%04X" % a] = a
            continue
        if s and not s.startswith(";") and s.endswith(":"):
            prev_names.append(s[:-1])

    from rammap import build as rb
    from emit import clean_symbols
    vars_, _ = rb()
    for a, n in clean_symbols(vars_).items():
        syms[n] = a

    total = bad = data = insn = 0
    errors = []
    for ln in text:
        m = LINE.match(ln)
        if not m:
            continue
        a, mn, oper = int(m.group(1), 16), m.group(2), m.group(3)
        if mn == ".byte":
            vals = [int(x.strip()[1:], 16) for x in oper.split(",") if x.strip()]
            for i, v in enumerate(vals):
                total += 1; data += 1
                if mem.get(a + i) != v:
                    bad += 1
                    if len(errors) < 8: errors.append("$%04X data $%02X != ROM $%02X" % (a+i, v, mem.get(a+i)))
            continue
        mn = mn.upper()
        if mn not in m6502.TAB:
            continue
        mode, v = parse_operand(oper, labels, syms, mn)
        if mode in (IMP, ACC) and ACC in m6502.TAB[mn] and IMP not in m6502.TAB[mn]:
            mode = ACC
        b = encode.encode(mn, mode, v or 0, a)
        insn += 1
        if b is None:
            bad += 1
            if len(errors) < 8: errors.append("$%04X cannot encode %s %s" % (a, mn, oper))
            continue
        for i, x in enumerate(b):
            total += 1
            if mem.get(a + i) != x:
                bad += 1
                if len(errors) < 8:
                    errors.append("$%04X %s %s -> $%02X != ROM $%02X" % (a+i, mn, oper, x, mem.get(a+i)))
                break
    print("verified bytes : %d" % total)
    print("instructions   : %d" % insn)
    print("data bytes     : %d" % data)
    print("MISMATCHES     : %d" % bad)
    for e in errors:
        print("   " + e)
    return bad

if __name__ == "__main__":
    sys.exit(1 if run() else 0)
