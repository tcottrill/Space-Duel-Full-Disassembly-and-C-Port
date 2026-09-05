"""Line-level parser for the Atari MACRO-65 (DEC RT-11) Space Duel sources."""
import re, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import m6502
from m6502 import IMP,ACC,IMM,ZP,ZPX,ZPY,ABS,ABX,ABY,IND,IZX,IZY,REL

MNEMONICS = set(m6502.TAB)

DIRECTIVE = re.compile(r"^\.[A-Z0-9_]+$", re.I)
LABEL_RE  = re.compile(r"^([A-Z_$.][A-Z0-9_$.]*|\d+\$)(::?)\s*(.*)$", re.I)
ASSIGN_RE = re.compile(r"^([A-Z_$.][A-Z0-9_$.]*)\s*(==?)\s*(.*)$", re.I)

class Line:
    __slots__ = ("n","raw","labels","op","operand","comment","kind")
    def __init__(self, n, raw):
        self.n, self.raw = n, raw
        self.labels, self.op, self.operand, self.comment, self.kind = [], None, "", "", "blank"
    def __repr__(self):
        return "<%d %s %s %r>" % (self.n, self.kind, self.op, self.operand)

def split_comment(s):
    """Split off a trailing ; comment, respecting ^/.../ and /.../ string forms."""
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if c == ";":
            return s[:i], s[i+1:]
        if c == "^" and i + 1 < n:            # ^/text/  delimited string
            d = s[i+1]
            j = s.find(d, i+2)
            i = n if j < 0 else j + 1
            continue
        i += 1
    return s, ""

def parse_line(n, raw):
    ln = Line(n, raw.rstrip("\r\n"))
    body, ln.comment = split_comment(ln.raw.replace("\f", ""))
    body = body.rstrip()
    if not body.strip():
        ln.kind = "comment" if ln.comment else "blank"
        return ln
    # leading labels (possibly several)
    while True:
        m = LABEL_RE.match(body.strip()) if not body[:1].isspace() or body.strip() else None
        s = body.strip()
        m = LABEL_RE.match(s)
        if m and (m.group(2) or "").startswith(":"):
            ln.labels.append((m.group(1), len(m.group(2)) == 2))
            body = m.group(3)
            continue
        break
    s = body.strip()
    if not s:
        ln.kind = "label"
        return ln
    if s.startswith(":"):          # stray ':' typo before a mnemonic (line 5011)
        s = s[1:].strip()
    if s.startswith(".="):         # location-counter assignment
        ln.kind, ln.op, ln.operand = "directive", ".=", s[2:].strip()
        return ln
    m = ASSIGN_RE.match(s)
    if m and not s.split()[0].upper() in MNEMONICS:
        ln.kind, ln.op, ln.operand = "assign", m.group(1), m.group(3).strip()
        ln.comment = (m.group(2) == "==") and ln.comment or ln.comment
        return ln
    parts = s.split(None, 1)
    if not parts:
        ln.kind = "blank"
        return ln
    ln.op = parts[0]
    ln.operand = parts[1].strip() if len(parts) > 1 else ""
    up = ln.op.upper()
    if up in MNEMONICS:
        ln.kind = "insn"
    elif ln.op.startswith("."):
        ln.kind = "directive"
    else:
        ln.kind = "macro"
    return ln

def parse_file(path):
    """Split on LF only (after folding CRLF) so line numbers match wc/awk.
    A lone CR inside a line must NOT start a new record, which is what
    Python universal-newline mode would wrongly do."""
    with open(path, "rb") as f:
        text = f.read().decode("latin-1").replace(chr(13) + chr(10), chr(10))
    return [parse_line(i + 1, l) for i, l in enumerate(text.split(chr(10)))]

# ---------------------------------------------------------------- operand mode
IDX_RE = re.compile(r"^([IXYAZ])\s*,\s*(.*)$", re.I)

def operand_mode(mn, operand):
    """Map DEC-style operand text to a 6502 addressing mode.
    Returns (mode, expr_text). Zero-page vs absolute is resolved later."""
    mn = mn.upper()
    o = operand.strip()
    modes = m6502.TAB[mn]
    if mn in m6502.BRANCHES:
        return REL, o
    if not o:
        return (ACC if ACC in modes else IMP), ""
    if o.upper() == "A" and ACC in modes:
        return ACC, ""
    m = IDX_RE.match(o)
    if m:
        pfx, rest = m.group(1).upper(), m.group(2).strip()
        if pfx == "I":
            return IMM, rest
        if pfx == "X":
            return ("zx", rest)              # zp,x or abs,x - size decided later
        if pfx == "Y":
            return ("zy", rest)              # zp,y or abs,y
        if pfx == "A":
            return ABS, rest                 # forced absolute
        if pfx == "Z":
            return ZP, rest                  # forced zero page
    if o.startswith("#"):
        return IMM, o[1:].strip()
    if o.startswith("(") :
        inner = o[1:]
        if inner.upper().endswith(")Y") or ")," in o.upper():
            pass
        if o.upper().replace(" ", "").endswith(",X)"):
            return IZX, o[1:o.rfind(",")]
        if o.upper().replace(" ", "").endswith(")Y") or o.upper().replace(" ","").endswith("),Y"):
            return IZY, o[1:o.rfind(")")]
        if o.endswith(")"):
            return IND, o[1:-1]
    return ("za", o)                          # zp or abs, size decided later

if __name__ == "__main__":
    lines = parse_file(sys.argv[1])
    kinds = {}
    for l in lines:
        kinds[l.kind] = kinds.get(l.kind, 0) + 1
    print(os.path.basename(sys.argv[1]), "lines=%d" % len(lines))
    for k, v in sorted(kinds.items(), key=lambda x: -x[1]):
        print("   %-10s %5d" % (k, v))
