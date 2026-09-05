"""Resolve the true link base of every relocatable module, then map it.

locate.py finds the ROM address of a module's longest instruction run. That
anchor fixes the module in memory, but the module's *base* is earlier by
however many bytes its preamble emits. Rather than count the preamble by hand,
we iterate: run the mapper from the module's first line at a trial base, see
where the anchor line actually lands, and shift the base by the error. The ROM
validates every instruction, so this converges in a couple of passes.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import paths
import macsrc, mapper, image, locate

MODULES = ["AST2RT.MAC","AS2SAC.MAC","AS2POK.MAC","COIN65.MAC","A2NAME.MAC",
           "AS2MSG.MAC","AS2TST.MAC","A2IRQ.MAC","A2EARO.MAC","VGUTR2.MAC",
           "A2GOOF.MAC"]

def first_content(lines):
    """First line that can emit bytes (skip .TITLE/.SBTTL/comments/.GLOBL)."""
    skip = {".TITLE",".SBTTL",".ASECT",".CSECT",".RADIX",".ENABLE",".ENABL",
            ".DSABL",".LIST",".NLIST",".GLOBL",".PAGE",".INCLUDE",".NOCROSS",
            ".IIF",".DEFSTACK",".PRINT",".REM"}
    for i, l in enumerate(lines):
        if l.kind in ("blank","comment","label","assign"):
            continue
        if l.kind == "directive" and l.op.upper() in skip:
            continue
        return i
    return 0

def resolve(mem, path, syms, lo=0x6C00, hi=0x8FFF):
    lines = macsrc.parse_file(path)
    at, seq = locate.first_run(lines)
    if not seq:
        return lines, None, None
    hits = locate.scan(mem, seq, lo, hi)
    if len(hits) != 1:
        return lines, None, hits
    anchor_addr = hits[0]
    start = first_content(lines)
    base = anchor_addr
    for _ in range(8):
        m = mapper.Mapper(mem, lines, start, base, extra_syms=syms).run()
        got = m.addr.get(lines[at].n)
        if got is None:
            return lines, None, hits
        if got == anchor_addr:
            return lines, (base, m), hits
        base += anchor_addr - got
    return lines, None, hits

if __name__ == "__main__":
    mem = image.load()
    syms = mapper.include_symbols()
    print("%-12s %-7s %-7s %-16s %s" % ("module","base","end","instructions","desyncs"))
    print("-" * 62)
    results = {}
    for fn in MODULES:
        lines, res, hits = resolve(mem, paths.archive(fn), syms)
        if not res:
            print("%-12s  UNRESOLVED (candidate anchors: %s)" % (fn, hits))
            continue
        base, m = res
        tot = sum(1 for l in lines if l.kind == "insn" and l.n in m.addr)
        allins = sum(1 for l in lines if l.kind == "insn")
        end = max(m.addr.values())
        results[fn] = (base, end, m)
        print("%-12s $%04X   $%04X   %4d/%-4d       %d"
              % (fn, base, end, tot, allins, len(m.desyncs)))
