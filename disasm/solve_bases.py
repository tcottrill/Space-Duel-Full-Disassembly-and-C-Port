"""Definitively solve each relocatable module's link base.

Fixed-point iteration alone can settle on a base that is off by the size of a
preamble it mis-counted, because the mapper's relock hides the error (this is
what happened with AS2TST: it converged on $803F when the true base was $802C,
19 bytes earlier). So we follow the iteration with a local sweep and demand the
base that maximises clean locking, preferring zero desyncs.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import paths
import macsrc, mapper, image, locate, modules

# option switches AS2COI.MAC sets before it includes the shared coin routine
COIN_OPTS = {"INCLUDE": 1, "BONADD": 1, "EMCTRS": 3, "COIN01": 1, "SLAM": 0}

MODULES = ["AST2RT.MAC","AS2SAC.MAC","AS2POK.MAC","COIN65.MAC","A2NAME.MAC",
           "AS2MSG.MAC","AS2TST.MAC","A2IRQ.MAC","A2EARO.MAC","VGUTR2.MAC",
           "A2GOOF.MAC"]

def solve(mem, fn, syms, span=96):
    lines = macsrc.parse_file(paths.archive(fn))
    at, seq = locate.first_run(lines)
    if not seq:
        return lines, None
    hits = locate.scan(mem, seq, 0x6C00, 0x8FFF)
    if len(hits) != 1:
        return lines, None
    anchor = hits[0]
    start = modules.first_content(lines)
    # 1) iterate to get in the neighbourhood
    base, seen = anchor, set()
    for _ in range(10):
        if base in seen or not (0x4000 <= base <= 0x8FFF):
            break
        seen.add(base)
        m = mapper.Mapper(mem, lines, start, base, extra_syms=syms).run()
        got = m.addr.get(lines[at].n)
        if got is None or got == anchor:
            break
        base += anchor - got
    # 2) local sweep to shake out a mis-counted preamble
    best = None
    for b in range(base - span, base + span + 1):
        if not (0x4000 <= b <= 0x8FFF):
            continue
        m = mapper.Mapper(mem, lines, start, b, extra_syms=syms).run()
        if m.addr.get(lines[at].n) != anchor:
            continue
        score = (-len(m.desyncs), m.locked)
        if best is None or score > best[0]:
            best = (score, b, m)
    if not best:
        return lines, None
    _, b, m = best
    return lines, (b, m)

if __name__ == "__main__":
    mem = image.load()
    base_syms = mapper.include_symbols()
    print("%-12s %-7s %-7s %-14s %s" % ("module","base","end","instructions","desyncs"))
    print("-" * 60)
    prev = None
    for fn in MODULES:
        syms = dict(base_syms)
        if fn == "COIN65.MAC":
            syms.update(COIN_OPTS)
        lines, res = solve(mem, fn, syms)
        allins = sum(1 for l in lines if l.kind == "insn")
        if not res:
            print("%-12s  unresolved" % fn)
            continue
        b, m = res
        end = max(m.addr.values())
        adj = "" if prev is None else ("contiguous" if b == prev else "gap %+d" % (b - prev))
        print("%-12s $%04X   $%04X   %3d/%-3d        %-4d %s"
              % (fn, b, end, m.locked, allins, len(m.desyncs), adj))
        prev = end
