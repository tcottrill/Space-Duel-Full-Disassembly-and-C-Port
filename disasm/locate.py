"""Find where the linker placed each relocatable (.CSECT) module.

A module's base is the address at which its instruction stream decodes cleanly
out of the ROM. We prefilter on the first long run of consecutive instruction
lines, then confirm by running the full mapper and demanding zero desyncs.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import paths
import m6502, macsrc, mapper, image

def first_run(lines, start=0, need=8):
    """Longest run of back-to-back instruction lines.

    Returns (index_of_first_line_in_run, [mnemonics]).  The index matters: the
    caller must anchor on the line the run actually starts at, not merely the
    first line anywhere that happens to use the same mnemonic.
    """
    run, run_at = [], None
    best, best_at = [], None
    for i, l in enumerate(lines):
        if i < start:
            continue
        if l.kind == "insn":
            if not run:
                run_at = i
            run.append(l.op.upper())
            if len(run) > len(best):
                best, best_at = list(run), run_at
        elif l.kind in ("directive", "macro", "assign"):
            run, run_at = [], None
    if len(best) >= need:
        return best_at, best
    return None, []

def scan(mem, seq, lo, hi):
    hits = []
    for base in range(lo, hi + 1):
        pc, ok = base, True
        for mn in seq:
            d = m6502.decode(mem, pc)
            if not d or d[0] != mn:
                ok = False
                break
            pc += d[3]
        if ok:
            hits.append(base)
    return hits

MODULES = ["VGUTR2.MAC","AS2MSG.MAC","AS2POK.MAC","AS2TST.MAC","AS2COI.MAC",
           "A2EARO.MAC","A2IRQ.MAC","A2NAME.MAC","AS2SAC.MAC","AST2RT.MAC",
           "COIN65.MAC","A2GOOF.MAC"]

if __name__ == "__main__":
    mem = image.load()
    syms = mapper.include_symbols()
    lo, hi = 0x6C00, 0x8FFF
    for fn in MODULES:
        path = paths.archive(fn)
        lines = macsrc.parse_file(path)
        ninsn = sum(1 for l in lines if l.kind == "insn")
        at, seq = first_run(lines)
        if not seq:
            print("%-12s  %4d insn  (no clean run to anchor on)" % (fn, ninsn))
            continue
        hits = scan(mem, seq, lo, hi)
        best = None
        for h in hits[:40]:
            mm = mapper.Mapper(mem, lines, at, h, extra_syms=syms).run()
            tot = sum(1 for l in lines[at:] if l.kind == "insn")
            score = (mm.locked - 5 * len(mm.desyncs), h, mm.locked, tot, len(mm.desyncs))
            if best is None or score > best:
                best = score
        if best:
            _, h, lk, tot, ds = best
            print("%-12s  %4d insn  base=$%04X  locked %d/%d  desyncs=%d  (%d candidate bases)"
                  % (fn, ninsn, h, lk, tot, ds, len(hits)))
        else:
            print("%-12s  %4d insn  NO MATCH (anchor len %d)" % (fn, ninsn, len(seq)))
