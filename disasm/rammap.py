"""Recover the RAM / zero-page variable layout from the source.

ASTRD2.MAC declares RAM with `LABEL: .BLKB n` runs anchored by `.=` origins,
before the program body at .=4000. Walking that section reproduces the address
of every game variable, which is what turns operands into readable names.

The walk must skip `.MACRO ... .ENDM` bodies. A macro definition emits nothing
where it is written - only where it is called - so counting the `.BYTE`/`.WORD`
lines inside one inflates the location counter. Four such lines sit ahead of
the page 0 declarations (ASTRD2.MAC lines 187 and 190 in VCTRSC, 238 in COLOR,
260 in MULBLD), which used to push every page 0 and page 1 variable 9 bytes too
high: VGBRIT landed at $09 instead of $00, SCORE at $43 instead of $3A. The
page 2/3, vector RAM and vector ROM sections open with their own `.=` origins
and so were never affected.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import paths
import macsrc, mapper, rtexpr

def build(srcdir=None, main="ASTRD2.MAC", stop_line=709):
    srcdir = paths.archive_dir(srcdir)
    lines = macsrc.parse_file(os.path.join(srcdir, main))
    syms = mapper.include_symbols(srcdir)
    ev = rtexpr.Expr(syms, radix=16)
    # let plain equates settle first
    for _ in range(8):
        for l in lines[:stop_line]:
            if l.kind == "assign" and l.op not in ("", "."):
                try:
                    syms[rtexpr.sym6(l.op)] = ev.eval(l.operand)
                except Exception:
                    pass

    vars_, pc, in_macro = {}, 0, False
    for l in lines[:stop_line]:
        if l.kind == "directive":
            d = l.op.upper()
            if d == ".MACRO":
                in_macro = True
                continue
            if d == ".ENDM":
                in_macro = False
                continue
        if in_macro:                       # a definition emits nothing here
            continue
        if l.kind == "directive" and l.op == ".=":
            try:
                pc = ev.eval(l.operand, dot=pc)
            except Exception:
                pass
            continue
        for name, _g in l.labels:
            vars_.setdefault(name, pc)
        if l.kind == "directive":
            d, o = l.op.upper(), l.operand.strip()
            if d == ".BLKB":
                try: pc += ev.eval(o, dot=pc)
                except Exception: pass
            elif d == ".BLKW":
                try: pc += 2 * ev.eval(o, dot=pc)
                except Exception: pass
            elif d == ".BYTE":
                pc += mapper.count_args(o)
            elif d == ".WORD":
                pc += 2 * mapper.count_args(o)
    # equates that name hardware registers are useful too
    _STORAGE.clear()
    _STORAGE.update(vars_)
    for k, v in syms.items():
        vars_.setdefault(k, v)
    return vars_, syms


_STORAGE = set()

def storage_labels(srcdir=None):
    """Names that came from a real declaration in the RAM walk, as opposed to
    an equate folded in afterwards. Atari's sources define plenty of constants
    whose value happens to equal a low RAM address (BLACK = 0, BLUE = 1), and
    without this a colour constant outranks the variable actually living there.
    """
    if not _STORAGE:
        build(srcdir)
    return frozenset(_STORAGE)

if __name__ == "__main__":
    v, syms = build()
    zp   = {k:a for k,a in v.items() if a < 0x100}
    page = {k:a for k,a in v.items() if 0x100 <= a < 0x400}
    io   = {k:a for k,a in v.items() if 0x800 <= a < 0x2000}
    vram = {k:a for k,a in v.items() if 0x2000 <= a < 0x2800}
    print("symbols recovered: %d  (zero page %d, RAM %d, I/O %d, vector RAM %d)"
          % (len(v), len(zp), len(page), len(io), len(vram)))
    print("\nsample zero-page variables:")
    for k, a in sorted(zp.items(), key=lambda kv: kv[1])[:12]:
        print("   $%02X  %s" % (a, k))
    print("\nsample I/O:")
    for k, a in sorted(io.items(), key=lambda kv: kv[1])[:12]:
        print("   $%04X %s" % (a, k))
