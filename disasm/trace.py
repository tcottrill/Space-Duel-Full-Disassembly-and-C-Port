"""Recursive-descent tracer over the Space Duel program ROM.

Produces, for $4000-$8FFF:
  starts   - set of addresses that begin an instruction on a reachable path
  covered  - set of addresses consumed by those instructions
  xrefs    - {target: set(source)} for JSR/JMP/branch targets
  drefs    - {target: set(source)} for data operand references
  indirect - JMP ($xxxx) sites that a static trace cannot follow
"""
import sys, os, collections
sys.path.insert(0, os.path.dirname(__file__))
import m6502, image
from m6502 import ABS, ABX, ABY, ZP, ZPX, ZPY, IZX, IZY, IND, REL, IMM

class Trace:
    def __init__(self, mem, lo=image.CODE_LO, hi=image.CODE_HI):
        self.mem, self.lo, self.hi = mem, lo, hi
        self.starts = set()
        self.covered = set()
        self.instr = {}                       # addr -> (mn, mode, val, n)
        self.xrefs = collections.defaultdict(set)
        self.drefs = collections.defaultdict(set)
        self.indirect = {}                    # site -> pointer address
        self.entries = {}                     # addr -> why
        self.bad = []                         # addr where decode failed on a code path

    def _in(self, a):
        return self.lo <= a <= self.hi

    def add_entry(self, addr, why):
        if self._in(addr):
            self.entries.setdefault(addr, why)

    def run(self):
        work = list(self.entries)
        seen = set()
        while work:
            pc = work.pop()
            while True:
                if pc in seen or not self._in(pc):
                    break
                d = m6502.decode(self.mem, pc)
                if d is None:
                    self.bad.append(pc)
                    break
                mn, mode, val, n = d
                seen.add(pc)
                self.starts.add(pc)
                self.instr[pc] = d
                for i in range(n):
                    self.covered.add(pc + i)

                if mode == REL:
                    self.xrefs[val].add(pc)
                    if val not in seen:
                        work.append(val)
                elif mn == "JSR":
                    self.xrefs[val].add(pc)
                    if val not in seen:
                        work.append(val)
                elif mn == "JMP" and mode == ABS:
                    self.xrefs[val].add(pc)
                    if val not in seen:
                        work.append(val)
                elif mn == "JMP" and mode == IND:
                    self.indirect[pc] = val
                elif mode in (ABS, ABX, ABY, ZP, ZPX, ZPY, IZX, IZY):
                    self.drefs[val].add(pc)

                if mn in ("JMP", "RTS", "RTI", "BRK"):
                    break
                pc += n
        return self

def default_trace(mem):
    t = Trace(mem)
    v = image.vectors(mem)
    t.add_entry(v["RESET"], "RESET vector")
    t.add_entry(v["IRQ"],   "IRQ vector")
    t.add_entry(v["NMI"],   "NMI vector")
    return t.run()

if __name__ == "__main__":
    mem = image.load()
    t = default_trace(mem)
    span = image.CODE_HI - image.CODE_LO + 1
    print("instructions: %d" % len(t.starts))
    print("bytes covered: %d / %d  (%.1f%%)" % (len(t.covered), span, 100.0*len(t.covered)/span))
    print("branch/call targets: %d" % len(t.xrefs))
    print("data refs in ROM range: %d" % sum(1 for a in t.drefs if image.CODE_LO <= a <= image.CODE_HI))
    print("indirect JMP sites: %s" % ", ".join("$%04X->($%04X)" % (k, v) for k, v in sorted(t.indirect.items())))
    print("decode failures on code paths: %d" % len(t.bad))
