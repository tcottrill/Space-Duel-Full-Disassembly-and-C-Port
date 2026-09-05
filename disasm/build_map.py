"""Build the consolidated source-line -> ROM-address map for the whole game.

Two kinds of module:
  * ASTRD2.MAC is .ASECT with an explicit .=4000, so it maps directly.
  * The .CSECT modules were placed by the linker. Their longest instruction run
    pins them in memory (each has exactly one candidate address in the ROM), and
    mapping forward from that anchor is reliable. We additionally try to reach
    back to the module base so preamble data tables get addresses too.
"""
import sys, os, collections
sys.path.insert(0, os.path.dirname(__file__))
import paths
import macsrc, mapper, image, locate, modules, m6502

MAIN = ("ASTRD2.MAC", 709, 0x4000)
CSECTS = ["AST2RT.MAC","AS2SAC.MAC","AS2POK.MAC","COIN65.MAC","A2NAME.MAC",
          "AS2MSG.MAC","AS2TST.MAC","A2IRQ.MAC","A2EARO.MAC","VGUTR2.MAC",
          "A2GOOF.MAC"]

# Bases the fixed-point search could not reach because of preamble data whose
# size the mapper mis-estimates. Each is confirmed by contiguity: the unmapped
# gap begins exactly at the previous module's end address.
KNOWN_BASE = {
    # Link bases solved by anchor-free sweep: the base at which each module's
    # instruction stream locks against the ROM with the fewest desyncs. These
    # supersede an earlier guess based on module contiguity, which was wrong
    # for AS2POK, AS2TST and A2EARO (AS2TST's true base is 19 bytes below the
    # value the fixed-point search settled on, because a relock hid the offset).
    "AST2RT.MAC": 0x6EE5,   # 141/141, 0 desyncs
    "AS2SAC.MAC": 0x703C,   #  54/54,  0 desyncs
    "AS2POK.MAC": 0x7197,   # 146/146, 0 desyncs
    "COIN65.MAC": 0x7425,   # 118/206, 27 desyncs - shared Atari coin library
    "A2NAME.MAC": 0x7529,   # 198/198, 1 desync
    "AS2MSG.MAC": 0x7730,   #  99/99,  0 desyncs
    "AS2TST.MAC": 0x802C,   # 614/614, 0 desyncs; POWERON lands on RESET $803F
    "A2IRQ.MAC":  0x8639,   # 132/132, 0 desyncs; equals the IRQ vector
    "A2EARO.MAC": 0x8749,   # 593/593, 0 desyncs
    "VGUTR2.MAC": 0x8E42,   # 142/142, 0 desyncs
    "A2GOOF.MAC": 0x8F43,   #  10/10,  0 desyncs
}

# option switches AS2COI.MAC sets before including the shared coin routine
COIN_OPTS = {"INCLUDE": 1, "BONADD": 1, "EMCTRS": 3, "COIN01": 1, "SLAM": 0}


def build(srcdir=None):
    srcdir = paths.archive_dir(srcdir)
    mem = image.load()
    syms = mapper.include_symbols(srcdir)
    out = {}          # module -> {line_no: addr}
    src = {}          # module -> [Line]
    info = {}         # module -> dict

    fn, ln0, org = MAIN
    lines = macsrc.parse_file(os.path.join(srcdir, fn))
    m = mapper.Mapper(mem, lines, ln0, org, extra_syms=syms).run()
    out[fn], src[fn] = dict(m.addr), lines
    info[fn] = dict(base=org, desyncs=len(m.desyncs), labels=m.labels, label_at=m.label_at,
                    insn=sum(1 for l in lines if l.kind=="insn" and l.n in m.addr))

    for fn in CSECTS:
        path = os.path.join(srcdir, fn)
        lines = macsrc.parse_file(path)
        start0 = modules.first_content(lines)
        if fn in KNOWN_BASE:
            msyms = dict(syms)
            if fn == "COIN65.MAC":
                msyms.update(COIN_OPTS)
            mb = mapper.Mapper(mem, lines, start0, KNOWN_BASE[fn], extra_syms=msyms).run()
            out[fn], src[fn] = dict(mb.addr), lines
            info[fn] = dict(base=KNOWN_BASE[fn], desyncs=len(mb.desyncs),
                            labels=dict(mb.labels), label_at=dict(mb.label_at),
                            insn=sum(1 for l in lines if l.kind=="insn" and l.n in mb.addr))
            continue
        at, seq = locate.first_run(lines)
        hits = locate.scan(mem, seq, 0x6C00, 0x8FFF) if seq else []
        if len(hits) != 1:
            info[fn] = dict(base=None, desyncs=-1, labels={}, label_at={}, insn=0, note="ambiguous anchor")
            out[fn], src[fn] = {}, lines
            continue
        anchor = hits[0]
        # authoritative: map forward from the anchor line
        ma = mapper.Mapper(mem, lines, at, anchor, extra_syms=syms).run()
        amap = dict(ma.addr)
        labels = dict(ma.labels)
        # best effort: reach back to the module base so the preamble is covered
        start = modules.first_content(lines)
        # Fixed-point iteration: map from the module start at a trial base, see
        # where the anchor line lands, shift the base by the error, repeat.
        if fn in KNOWN_BASE:
            msyms = dict(syms)
            if fn == "COIN65.MAC":
                msyms.update(COIN_OPTS)
            mb = mapper.Mapper(mem, lines, start, KNOWN_BASE[fn], extra_syms=msyms).run()
            merged = dict(mb.addr); merged.update(amap)
            lab = dict(mb.labels); lab.update(labels)
            out[fn], src[fn] = merged, lines
            la = dict(mb.label_at); la.update(ma.label_at)
            info[fn] = dict(base=KNOWN_BASE[fn], desyncs=len(mb.desyncs), labels=lab, label_at=la,
                            insn=sum(1 for l in lines if l.kind=="insn" and l.n in merged),
                            note="base from contiguity")
            continue
        best, base_try, seen = None, anchor, set()
        for _ in range(8):
            if base_try in seen or not (0x4000 <= base_try <= 0x8FFF):
                break
            seen.add(base_try)
            mb = mapper.Mapper(mem, lines, start, base_try, extra_syms=syms).run()
            got = mb.addr.get(lines[at].n)
            if got is None:
                break
            if got == anchor:
                best = (mb.locked - 10 * len(mb.desyncs), base_try, mb)
                break
            base_try += anchor - got
        if best:
            _, base, mb = best
            merged = dict(mb.addr); merged.update(amap)   # anchor map wins
            lab = dict(mb.labels); lab.update(labels)
            out[fn], src[fn] = merged, lines
            la = dict(mb.label_at); la.update(ma.label_at)
            info[fn] = dict(base=base, desyncs=len(mb.desyncs), labels=lab, label_at=la,
                            insn=sum(1 for l in lines if l.kind=="insn" and l.n in merged))
        else:
            out[fn], src[fn] = amap, lines
            info[fn] = dict(base=None, desyncs=len(ma.desyncs), labels=labels, label_at=dict(ma.label_at),
                            insn=sum(1 for l in lines if l.kind=="insn" and l.n in amap),
                            note="anchor-only (base not recovered)")
    return mem, src, out, info

def coverage(mem, src, out):
    cov = set()
    for fn, amap in out.items():
        for n, a in amap.items():
            l = src[fn][n-1]
            if l.kind == "insn":
                d = m6502.decode(mem, a)
                if d:
                    for i in range(d[3]):
                        cov.add(a + i)
    return cov

if __name__ == "__main__":
    mem, src, out, info = build()
    print("%-12s %-7s %-7s %-8s %s" % ("module","base","insns","desyncs","note"))
    print("-"*58)
    for fn in [MAIN[0]] + CSECTS:
        i = info[fn]
        b = ("$%04X" % i["base"]) if i["base"] else "   -  "
        print("%-12s %-7s %-7d %-8s %s" % (fn, b, i["insn"], i["desyncs"], i.get("note","")))
    cov = coverage(mem, src, out)
    lo, hi = 0x4000, 0x8FFF
    inrange = sum(1 for a in cov if lo <= a <= hi)
    print("\ninstruction bytes mapped in $4000-$8FFF: %d / %d  (%.1f%%)"
          % (inrange, hi-lo+1, 100.0*inrange/(hi-lo+1)))
