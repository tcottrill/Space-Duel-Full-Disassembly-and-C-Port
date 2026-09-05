"""Recover the RAM / zero-page variable layout from the source.

ASTRD2.MAC declares RAM with `LABEL: .BLKB n` runs anchored by `.=` origins,
before the program body at .=4000. Walking that section reproduces the address
of every game variable, which is what turns operands into readable names.
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

    vars_, pc = {}, 0
    for l in lines[:stop_line]:
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
    for k, v in syms.items():
        vars_.setdefault(k, v)
    return vars_, syms

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
