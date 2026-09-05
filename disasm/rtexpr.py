"""RT-11 / MACRO-65 expression evaluator.

MACRO-11 semantics: operators have NO precedence and evaluate strictly left to
right; <...> forces grouping.  Default radix is set by .RADIX (16 in this
source).  ^H/^D/^O/^B override per-term; a trailing '.' means decimal.
Arithmetic is 16-bit unsigned.
"""
import re

TERM = re.compile(r"""
    \s*(?:
      (?P<up>\^[HhDdOoBb])\s*(?P<upv>[0-9A-Za-z]+)
    | (?P<num>[0-9][0-9A-Za-z]*\.?)
    | (?P<chr>'.)
    | (?P<sym>[A-Za-z_$.][A-Za-z0-9_$.]*\$?|\.)
    )""", re.X)

OPS = set("+-*/&!")

def sym6(name):
    """DEC symbol significance: first 6 characters."""
    return name[:6]

class Expr:
    def __init__(self, symbols, radix=16, dot=0):
        self.sym, self.radix, self.dot = symbols, radix, dot

    def value(self, name):
        if name == ".":
            return self.dot
        if name in self.sym:
            return self.sym[name]
        # DEC MACRO-11/65 symbols are significant to 6 characters only, so e.g.
        # NMCOMETS and NMCOMET are one and the same symbol.
        k = sym6(name)
        if k in self.sym:
            return self.sym[k]
        raise KeyError(name)

    def number(self, t):
        if t.endswith("."):
            return int(t[:-1] or "0", 10)
        return int(t, self.radix)

    def eval(self, s, dot=None):
        if dot is not None:
            self.dot = dot
        v, _ = self._eval(s.strip(), 0)
        return v & 0xFFFF

    def _eval(self, s, i):
        acc, op = None, "+"
        while i < len(s):
            c = s[i]
            if c.isspace():
                i += 1
                continue
            if c == ">":
                break
            if c in OPS and acc is not None:
                op, i = c, i + 1
                continue
            if c == "-" and acc is None:
                op, i = "-", i + 1
                acc = 0
                continue
            if c == "<":
                val, i = self._eval(s, i + 1)
                if i < len(s) and s[i] == ">":
                    i += 1
            else:
                m = TERM.match(s, i)
                if not m:
                    break
                i = m.end()
                if m.group("up"):
                    base = {"H":16, "D":10, "O":8, "B":2}[m.group("up")[1].upper()]
                    val = int(m.group("upv"), base)
                elif m.group("num"):
                    val = self.number(m.group("num"))
                elif m.group("chr"):
                    val = ord(m.group("chr")[1])
                else:
                    val = self.value(m.group("sym"))
            acc = val if acc is None else self.apply(acc, op, val)
        return (acc or 0), i

    @staticmethod
    def apply(a, op, b):
        if op == "+": return (a + b) & 0xFFFF
        if op == "-": return (a - b) & 0xFFFF
        if op == "*": return (a * b) & 0xFFFF
        if op == "/": return (a // b) if b else 0
        if op == "&": return a & b
        if op == "!": return a | b
        return b

if __name__ == "__main__":
    e = Expr({"VECRAM":0x2000, "COLBIT":0x40, "ZSHIP":4}, radix=16)
    for t, want in [("100",0x100), ("12.",12), ("^H1F",0x1F), ("0FF-COLBIT",0xBF),
                    ("VECRAM/100",0x20), ("VECRAM&0FF+2",2), ("<ZSHIP+1>*2",10)]:
        got = e.eval(t)
        print("  %-16s = $%04X  %s" % (t, got, "ok" if got == want else "EXPECTED $%04X" % want))
