"""Lock MACRO-65 source lines onto ROM addresses, using the ROM as the oracle.

Walks the absolute (.ASECT / .=) body of a source module. For every instruction
line it checks that the ROM at the current pc decodes to the same mnemonic; the
ROM supplies the real length, so zp-vs-abs ambiguity resolves itself. Directive
and macro lengths are estimated, and any estimation error is corrected by
re-locking on the next run of matching instructions.
"""
import sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
import paths
import m6502, macsrc, image, rtexpr
from m6502 import IMM, REL, ACC, IMP, ABS, IND, IZX, IZY

# macro name -> bytes emitted (from the .MACRO definitions in AS2DEC / VGMC)
MACRO_LEN = {
    "LXL":2, "LXH":2, "LAH":2, "LAL":2, "BADH":1, "BADL":1,
    ".LBYTE":1, ".UBYTE":1, "ADCL":2,
    "LXHJSR":2, "LALJSR":2, "LAHJSR":2, "UBYJSR":1, "LBYJSR":1,
    "DNEGATE":11, "HEAD":0,
    "JSRL":2, "JMPL":2, "RTSL":2, "VCTR":4, "SVEC":2, "CNTR":2,
    "STAT":2, "SCAL":2, "HALT":2, "LABS":6, "VCTRSC":4,
}

# HLL65F.MAC structured-programming macros.
#   IFxx  -> one conditional branch over the block          (2 bytes)
#   ELSE  -> JMP over the else-block (3), or B'COND . (2) when given a condition
#   THEN/ENDIF/ENDC/FND/LOC/BEGIN -> emit nothing, they only patch branch targets
for _c in ("EQ","NE","CS","CC","MI","PL","VS","VC","LT","GE","GT","LE","ZS","ZC"):
    MACRO_LEN["IF" + _c] = 2
for _z in ("ENDIF","ENDC","THEN","FND","LOC","BEGIN","HLL65","CONTINUE","END","DEFIF","IFXX"):
    MACRO_LEN[_z] = 0

# Macros that expand to real instructions. Their length depends on whether the
# operands land in zero page, so the ROM decode supplies the true size rather
# than a fixed byte count.
MACRO_EXPAND = {
    "DNEGATE": ["LDA", "SEC", "SBC", "STA", "LDA", "SBC", "STA"],
    "PHXA": ["TXA", "PHA"], "PHYA": ["TYA", "PHA"],
    "PLXA": ["PLA", "TAX"], "PLYA": ["PLA", "TAY"],
}

# HLL65F: LDAL/LDAH and the LD macro all emit one immediate load.
for _n in ("LDAL", "LDAH", "LD"):
    MACRO_LEN[_n] = 2
for _z in (".BR", ".ASSUME"):
    MACRO_LEN[_z] = 0

# DEFEND-generated block enders close a BEGIN loop (see HLL65F ..END):
#   normally  Bcc <back>                     -> 2 bytes
#   too far   Bcc .+5 / JMP <back>           -> 5 bytes
END_MACRO = re.compile(r"^(CC|CS|EQ|NE|MI|PL|VC|VS)(END|CONT)$")
# .IRP-generated repeat macros: ASLS n,operand -> n copies of ASL operand
REPEAT_MACRO = re.compile(r"^(ASL|ROL|LSR|ROR|INC|DEC|INX|DEX|INY|DEY)S$")

SPLIT_ARGS = re.compile(r",(?![^<]*>)")

def count_args(operand):
    o = operand.strip()
    if not o:
        return 0
    depth, n = 0, 1
    for c in o:
        if c == "<": depth += 1
        elif c == ">": depth -= 1
        elif c == "," and depth == 0: n += 1
    return n

def ascii_len(operand):
    o = operand.strip()
    if not o:
        return 0
    if o[0] == "^" and len(o) > 2:
        d = o[1]; j = o.find(d, 2)
        return (j - 2) if j > 0 else 0
    d = o[0]; j = o.find(d, 1)
    return (j - 1) if j > 0 else 0

class Mapper:
    def __init__(self, mem, lines, start_line, org, extra_syms=None):
        self.mem, self.lines, self.start_line, self.org = mem, lines, start_line, org
        self.addr = {}        # source line number -> address
        self.labels = {}      # label name -> address
        self.locked = 0
        self.desyncs = []
        self.unknown_macros = {}
        self.label_at = {}    # addr -> [(name, is_global, enclosing_global)]
        self._scope = None    # most recent global label, for scoping locals
        self.syms = dict(extra_syms or {})
        self.collect_symbols()
        self.ev = rtexpr.Expr(self.syms, radix=16)
        self.rept = []        # stack of (count, start_pc)
        self.cond = []        # MACRO-11 .IF/.IFF/.IFT/.ENDC state
        self.unresolved = set()

    def collect_symbols(self):
        """Sweep ' NAME = expr ' lines repeatedly so forward references settle."""
        ev = rtexpr.Expr(self.syms, radix=16)
        for _ in range(8):
            before = len(self.syms)
            for l in self.lines:
                if l.kind == "assign" and l.op not in ("", "."):
                    try:
                        self.syms[rtexpr.sym6(l.op)] = ev.eval(l.operand)
                    except Exception:
                        pass
            if len(self.syms) == before:
                break

    def expr(self, text, pc):
        try:
            return self.ev.eval(text, dot=pc)
        except Exception:
            self.unresolved.add(text.strip())
            return None

    def rom_ok(self, pc, mn):
        d = m6502.decode(self.mem, pc)
        return d if (d and d[0] == mn.upper()) else None

    def relock(self, pc, i, window=64, need=4):
        """Search nearby for a pc where the next `need` source instructions all match."""
        cand = []
        for delta in range(-window, window + 1):
            p = pc + delta
            if not (image.CODE_LO <= p <= image.CODE_HI):
                continue
            q, k, ok = p, i, 0
            while k < len(self.lines) and ok < need:
                l = self.lines[k]
                if l.kind == "insn":
                    d = self.rom_ok(q, l.op)
                    if not d:
                        break
                    q += d[3]; ok += 1
                elif l.kind in ("directive", "macro", "assign"):
                    break
                k += 1
            if ok >= need:
                cand.append((abs(delta), p))
        return min(cand)[1] if cand else None

    def run(self):
        pc = self.org
        i = self.start_line
        n = len(self.lines)
        while i < n:
            l = self.lines[i]
            if l.kind == "directive" and l.op.upper() in self.COND_DIRECTIVES:
                if l.op.upper() == ".IIF":
                    parts = l.operand.split(",", 2)
                    if len(parts) == 3 and self.eval_cond(parts[0], parts[1], pc) is False:
                        i += 1
                        continue
                else:
                    self.handle_cond(l, pc)
                    i += 1
                    continue
            if not self.cond_active():
                i += 1
                continue
            for name, _g in l.labels:
                self.labels.setdefault(name, pc)
                # Local labels ("10$") repeat in every routine, so they are only
                # meaningful together with their address and enclosing scope.
                is_local = bool(re.match(r"^\d+\$$", name))
                if not is_local:
                    self._scope = name
                self.label_at.setdefault(pc, []).append(
                    (name, not is_local, self._scope, l.n))
            if l.kind == "insn":
                d = self.rom_ok(pc, l.op)
                if d is None:
                    p = self.relock(pc, i)
                    if p is None:
                        self.desyncs.append((l.n, pc, l.op, "lost"))
                        i += 1
                        continue
                    self.desyncs.append((l.n, pc, l.op, "relock %+d" % (p - pc)))
                    pc = p
                    d = self.rom_ok(pc, l.op)
                    if d is None:
                        i += 1
                        continue
                self.addr[l.n] = pc
                self.locked += 1
                pc += d[3]
            elif l.kind == "directive":
                self.addr[l.n] = pc
                if l.op.upper() == ".REPT" and self.expr(l.operand, pc) == 0:
                    i = self.skip_rept(i)
                    continue
                pc = self.directive(l, pc)
                if pc is None:
                    return self
            elif l.kind == "macro":
                self.addr[l.n] = pc
                name = l.op.upper()
                if END_MACRO.match(name):
                    pc += self.end_macro_len(pc)
                elif REPEAT_MACRO.match(name):
                    base = REPEAT_MACRO.match(name).group(1)
                    cnt = self.expr(l.operand.split(",")[0], pc) or 1
                    for _ in range(cnt):
                        d = self.rom_ok(pc, base)
                        if d is None:
                            break
                        pc += d[3]
                elif name in MACRO_EXPAND:
                    for mn in MACRO_EXPAND[name]:
                        d = self.rom_ok(pc, mn)
                        if d is None:
                            break
                        pc += d[3]
                elif name == "ELSE":
                    pc += 2 if l.operand.strip() else 3
                elif name in MACRO_LEN:
                    pc += MACRO_LEN[name]
                else:
                    self.unknown_macros[name] = self.unknown_macros.get(name, 0) + 1
            i += 1
        return self

    # ---------------------------------------------------- conditional assembly
    COND_DIRECTIVES = (".IF", ".IFF", ".IFT", ".IFTF", ".ENDC", ".IIF")

    def cond_active(self):
        return all(f["active"] for f in self.cond)

    def eval_cond(self, cond, arg, pc):
        """MACRO-11 condition test. Returns True/False, or None if untestable."""
        c = cond.upper().lstrip(".")
        a = (arg or "").strip()
        if c in ("B", "NB"):
            blank = (a.strip("<>").strip() == "")
            return blank if c == "B" else not blank
        if c in ("DF", "NDF"):
            import rtexpr as _r
            defined = a in self.syms or _r.sym6(a) in self.syms
            return defined if c == "DF" else not defined
        if c in ("IDN", "DIF"):
            parts = [x.strip().strip("<>").upper() for x in a.split(",", 1)]
            same = len(parts) == 2 and parts[0] == parts[1]
            return same if c == "IDN" else not same
        v = self.expr(a, pc)
        if v is None:
            return None
        sv = v - 0x10000 if v & 0x8000 else v          # signed 16-bit
        return {"EQ": sv == 0, "NE": sv != 0, "GT": sv > 0,
                "GE": sv >= 0, "LT": sv < 0, "LE": sv <= 0}.get(c)

    def handle_cond(self, l, pc):
        d = l.op.upper()
        o = l.operand.strip()
        if d == ".IF":
            parts = o.split(",", 1)
            cond = parts[0].strip()
            arg = parts[1] if len(parts) > 1 else ""
            r = self.eval_cond(cond, arg, pc)
            # an untestable condition assembles its true branch, matching the
            # common case and keeping the walk moving
            taken = True if r is None else r
            self.cond.append({"taken": taken, "active": taken and self.cond_active()})
        elif d == ".IFF":
            if self.cond:
                f = self.cond[-1]
                f["active"] = (not f["taken"]) and all(x["active"] for x in self.cond[:-1])
        elif d == ".IFT":
            if self.cond:
                f = self.cond[-1]
                f["active"] = f["taken"] and all(x["active"] for x in self.cond[:-1])
        elif d == ".IFTF":
            if self.cond:
                self.cond[-1]["active"] = all(x["active"] for x in self.cond[:-1])
        elif d == ".ENDC":
            if self.cond:
                self.cond.pop()
        return pc

    def skip_rept(self, i):
        """Advance past a .REPT/.ENDR body, honouring nesting."""
        depth = 0
        n = len(self.lines)
        while i < n:
            l = self.lines[i]
            if l.kind == "directive":
                u = l.op.upper()
                if u == ".REPT":
                    depth += 1
                elif u == ".ENDR":
                    depth -= 1
                    if depth == 0:
                        return i + 1
            i += 1
        return i

    def end_macro_len(self, pc):
        """2 for a plain backward branch, 5 for the branch-over-JMP long form."""
        d = m6502.decode(self.mem, pc)
        if d and d[0] in m6502.BRANCHES:
            if d[2] == pc + 5 and (m6502.decode(self.mem, pc + 2) or ("",))[0] == "JMP":
                return 5
            return 2
        return 2

    def directive(self, l, pc):
        d = l.op.upper()
        o = l.operand.strip()
        if d == ".BYTE":
            return pc + count_args(o)
        if d == ".WORD":
            return pc + 2 * count_args(o)
        if d in (".ASCII", ".ASCIZ"):
            return pc + ascii_len(o) + (1 if d == ".ASCIZ" else 0)
        if d in (".BLKB", ".BLKW"):
            v = self.expr(o, pc)
            return pc if v is None else pc + v * (2 if d == ".BLKW" else 1)
        if d == ".EVEN":
            return pc + (pc & 1)
        if d == ".=":
            v = self.expr(o, pc)
            return pc if v is None else v
        if d in (".CSECT", ".PSECT"):
            # a relocatable section restarts at the base the linker gave it
            return self.org
        if d == ".REPT":
            v = self.expr(o, pc)
            self.rept.append((1 if v is None else v, pc))
            return pc
        if d == ".ENDR":
            if self.rept:
                cnt, start = self.rept.pop()
                return start + cnt * (pc - start)
            return pc
        if d == ".END":
            return None
        return pc

INCLUDES = ["AS2DEC.MAC", "VGMC.MAC", "HLL65F.MAC"]

def include_symbols(srcdir=None):
    """Symbols defined by the files the main module .INCLUDEs."""
    srcdir = paths.archive_dir(srcdir)
    syms = {}
    ev = rtexpr.Expr(syms, radix=16)
    for _ in range(8):
        before = len(syms)
        for fn in INCLUDES:
            for l in macsrc.parse_file(os.path.join(srcdir, fn)):
                if l.kind == "assign" and l.op not in ("", "."):
                    try:
                        syms[rtexpr.sym6(l.op)] = ev.eval(l.operand)
                    except Exception:
                        pass
        if len(syms) == before:
            break
    return syms

if __name__ == "__main__":
    mem = image.load()
    lines = macsrc.parse_file(paths.archive("ASTRD2.MAC"))
    # line 709 is ".=4000" (1-based); start on the line after it
    m = Mapper(mem, lines, 709, 0x4000, extra_syms=include_symbols()).run()
    total = sum(1 for l in lines[709:] if l.kind == "insn")
    print("instruction lines after .=4000 : %d" % total)
    print("locked to ROM addresses        : %d  (%.1f%%)" % (m.locked, 100.0*m.locked/total))
    print("labels resolved                : %d" % len(m.labels))
    print("desync events                  : %d" % len(m.desyncs))
    for e in m.desyncs[:15]:
        print("    line %-5d pc=$%04X %-5s %s" % e)
    if m.unknown_macros:
        print("unknown macros: %s" % ", ".join("%s x%d" % kv for kv in sorted(m.unknown_macros.items(), key=lambda x:-x[1])[:12]))
