"""Anchor-free base sweep: pick the base that simply locks best (fewest
desyncs, then most instructions). No anchor constraint, because an anchor
derived from a repeated mnemonic run can itself be wrong."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import paths
import macsrc, mapper, image, modules, solve_bases

WINDOWS = {   # module -> (lo, hi) search range for its base
    "AS2POK.MAC": (0x7000, 0x7500),
    "A2EARO.MAC": (0x8600, 0x8E00),
    "A2NAME.MAC": (0x7400, 0x7800),
    "VGUTR2.MAC": (0x8C00, 0x8F43),
    "COIN65.MAC": (0x7300, 0x7700),
}

if __name__ == "__main__":
    mem = image.load()
    base_syms = mapper.include_symbols()
    for fn, (lo, hi) in WINDOWS.items():
        syms = dict(base_syms)
        if fn == "COIN65.MAC":
            syms.update(solve_bases.COIN_OPTS)
        lines = macsrc.parse_file(paths.archive(fn))
        start = modules.first_content(lines)
        allins = sum(1 for l in lines if l.kind == "insn")
        best = None
        for b in range(lo, hi + 1):
            m = mapper.Mapper(mem, lines, start, b, extra_syms=syms).run()
            sc = (-len(m.desyncs), m.locked)
            if best is None or sc > best[0]:
                best = (sc, b, m)
        sc, b, m = best
        print("%-12s base=$%04X  locked %3d/%-3d desyncs=%-3d end=$%04X"
              % (fn, b, m.locked, allins, len(m.desyncs), max(m.addr.values())),
              flush=True)
