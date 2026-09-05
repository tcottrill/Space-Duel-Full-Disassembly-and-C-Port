"""Pin every module's link base by searching a window around the contiguity
prediction (the linker placed .CSECTs back to back) and scoring how well the
module's instruction stream locks against the ROM."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import paths
import macsrc, mapper, image, locate, modules

ORDER = ["AST2RT.MAC","AS2SAC.MAC","AS2POK.MAC","COIN65.MAC","A2NAME.MAC",
         "AS2MSG.MAC","AS2TST.MAC","A2IRQ.MAC","A2EARO.MAC","VGUTR2.MAC",
         "A2GOOF.MAC"]

def score_base(mem, lines, start, base, syms, anchor_line=None, anchor_addr=None):
    m = mapper.Mapper(mem, lines, start, base, extra_syms=syms).run()
    if anchor_line is not None:
        if m.addr.get(anchor_line) != anchor_addr:
            return None, m
    return m.locked - 10 * len(m.desyncs), m

if __name__ == "__main__":
    mem = image.load()
    syms = mapper.include_symbols()
    print("%-12s %-7s %-7s %-13s %-8s %s" % ("module","base","end","instructions","desyncs","anchor"))
    print("-" * 70)
    prev_end = None
    rows = []
    for fn in ORDER:
        path = paths.archive(fn)
        lines = macsrc.parse_file(path)
        at, seq = locate.first_run(lines)
        hits = locate.scan(mem, seq, 0x6C00, 0x8FFF) if seq else []
        anchor_addr = hits[0] if len(hits) == 1 else None
        anchor_line = lines[at].n if at is not None else None
        start = modules.first_content(lines)

        lo = (prev_end - 8) if prev_end else 0x6EE5
        hi = (prev_end + 64) if prev_end else 0x6EE5
        if anchor_addr:
            lo, hi = min(lo, anchor_addr - 2048), min(hi, anchor_addr)
        best = None
        for b in range(lo, hi + 1):
            sc, m = score_base(mem, lines, start, b, syms, anchor_line, anchor_addr)
            if sc is not None and (best is None or sc > best[0]):
                best = (sc, b, m)
        if not best:
            print("%-12s  UNRESOLVED" % fn)
            prev_end = None
            continue
        _, base, m = best
        end = max(m.addr.values()) if m.addr else base
        tot = sum(1 for l in lines if l.kind == "insn" and l.n in m.addr)
        allins = sum(1 for l in lines if l.kind == "insn")
        adj = "contiguous" if prev_end == base else ("gap %+d" % (base - prev_end) if prev_end else "-")
        print("%-12s $%04X   $%04X   %4d/%-4d     %-8d %s"
              % (fn, base, end, tot, allins, len(m.desyncs), adj))
        rows.append((fn, base, end, len(m.desyncs)))
        prev_end = end
