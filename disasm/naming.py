"""Turn Atari's 6-character labels into descriptive Asteroids-style names.

The source documents most routines with `.SBTTL NAME-DESCRIPTION`, so the
description supplies the readable name; anything without one falls back to a
tidied form of the original identifier.
"""
import sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
import paths
import macsrc

STOP = {"A","AN","THE","OF","TO","FOR","AND","OR","IF","IN","ON","IS","IT","THIS","X","Y"}

ABBREV = {
    "VG":"Vector", "VGO":"VectorGo", "AVG":"Avg", "SFX":"Sfx", "EAROM":"Earom",
    "POKEY":"Pokey", "IRQ":"Irq", "NMI":"Nmi", "RAM":"Ram", "ROM":"Rom",
    "INIT":"Init", "CALC":"Calc", "DISP":"Display", "MSG":"Message",
    "PTR":"Ptr", "TBL":"Table", "TMP":"Temp", "CNT":"Count", "NUM":"Num",
    "POS":"Pos", "VEL":"Velocity", "ANG":"Angle", "EXP":"Explosion",
    "SHP":"Ship", "SAU":"Saucer", "AST":"Asteroid", "SCR":"Score",
    "COL":"Color", "CHR":"Char", "SND":"Sound", "SW":"Switch",
}

def camel(text):
    words = [w for w in re.split(r"[^A-Za-z0-9]+", text) if w]
    out = []
    for w in words:
        u = w.upper()
        if u in ABBREV:
            out.append(ABBREV[u])
        elif w.isdigit():
            out.append(w)
        else:
            out.append(w[:1].upper() + w[1:].lower())
    return "".join(out)

def sbttl_names(lines):
    """{ATARI_LABEL: 'Descriptive Text'} harvested from .SBTTL NAME-DESCRIPTION."""
    out = {}
    for l in lines:
        if l.kind == "directive" and l.op.upper() == ".SBTTL":
            t = l.operand.strip()
            m = re.match(r"^([A-Z0-9_$]{2,})\s*[-:]\s*(.+)$", t, re.I)
            if m:
                out.setdefault(m.group(1).upper(), m.group(2).strip())
    return out

def descriptive(label, desc_map, used):
    """Pick a readable, unique name for one Atari label."""
    key = label.upper()
    if key in desc_map:
        base = camel(desc_map[key])
        # trim leading filler and cap the length so lines stay readable
        base = re.sub(r"^(Do|Go|The)(?=[A-Z])", "", base)
        words = re.findall(r"[A-Z][a-z0-9]*|[0-9]+", base)
        base = trim_filler("".join(words[:4])) or camel(label)
    else:
        base = camel(label)
    if not base or base[0].isdigit():
        base = "L" + base
    name, i = base, 2
    while name in used and used[name] != label:
        name, i = "%s%d" % (base, i), i + 1
    used[name] = label
    return name

def build(srcdir=None, files=None):
    srcdir = paths.archive_dir(srcdir)
    files = files or ["ASTRD2.MAC","AST2RT.MAC","AS2SAC.MAC","AS2POK.MAC","COIN65.MAC",
                      "A2NAME.MAC","AS2MSG.MAC","AS2TST.MAC","A2IRQ.MAC","A2EARO.MAC",
                      "VGUTR2.MAC","A2GOOF.MAC"]
    desc = {}
    for fn in files:
        p = os.path.join(srcdir, fn)
        if os.path.exists(p):
            desc.update(sbttl_names(macsrc.parse_file(p)))
    return desc

if __name__ == "__main__":
    d = build()
    print("routines documented by .SBTTL: %d\n" % len(d))
    used = {}
    for k in sorted(d)[:20]:
        print("   %-10s -> %-26s  (%s)" % (k, descriptive(k, d, used), d[k][:38]))


# --------------------------------------------------------------- descriptions
NOISE = re.compile(r"^[\s*=<>-]*$")

def harvest(lines, n):
    """Best available prose for the label defined on source line n.

    Prefers the inline comment on the label's own line; failing that, the block
    of full-line comments immediately above it.
    """
    if not (1 <= n <= len(lines)):
        return None
    l = lines[n - 1]
    c = (l.comment or "").strip()
    if c and not NOISE.match(c) and len(c) > 2:
        return c
    block = []
    i = n - 2
    while i >= 0 and len(block) < 3:
        p = lines[i]
        if p.kind == "comment":
            t = (p.comment or "").strip()
            if t and not NOISE.match(t):
                block.append(t)
            elif block:
                break
        elif p.kind == "blank":
            if block:
                break
        else:
            break
        i -= 1
    if block:
        return " ".join(reversed(block))
    return None


def name_for(label, is_global, scope_name, desc_map, prose, used):
    """Pick a readable name for one label definition."""
    if not is_global:
        # 10$ inside DSTRCT becomes DestructionDuringCollision_10
        num = label.rstrip("$")
        base = "%s_%s" % (scope_name or "L", num)
        return _unique(base, label, used)
    key = label.upper()
    if key in desc_map:
        return descriptive(label, desc_map, used)
    if prose:
        words = re.findall(r"[A-Za-z0-9]+", prose)
        words = [w for w in words if w.upper() not in STOP][:4]
        if words:
            return _unique(trim_filler(camel(" ".join(words))), label, used)
    exp = expand_identifier(label)
    return _unique(exp or camel(label), label, used)


def _unique(base, label, used):
    if not base or base[0].isdigit():
        base = "L" + base
    name, i = base, 2
    while name in used and used[name] != label:
        name, i = "%s%d" % (base, i), i + 1
    used[name] = label
    return name


# ------------------------------------------------------- identifier expansion
# Morphemes that recur throughout this codebase. Applied longest-first when
# segmenting a terse Atari identifier such as DIFTBL or UPDIF.
MORPHEMES = [
    ("HISCORE","HighScore"),("HSCORE","HighScore"),("HSC","HighScore"),
    ("DIFFIC","Difficulty"),("DIF","Difficulty"),("DIG","Digit"),
    ("TABLE","Table"),("TBL","Table"),("TAB","Table"),("TB","Table"),
    ("COMET","Comet"),("COM","Comet"),("MINE","Mine"),("MIN","Min"),("MAX","Max"),
    ("SAUCER","Saucer"),("SAU","Saucer"),("SHIELD","Shield"),("SHLD","Shield"),
    ("SHIP","Ship"),("SHP","Ship"),("ROCK","Rock"),("PAIR","Pair"),
    ("EXPLOS","Explosion"),("EXP","Explosion"),("XPL","Explosion"),
    ("SCORE","Score"),("SCR","Score"),("STAT","Status"),("STRT","Start"),
    ("UPDATE","Update"),("UPD","Update"),("UP","Up"),
    ("VECTOR","Vector"),("VEC","Vector"),("VG","Vector"),
    ("ANGLE","Angle"),("ANG","Angle"),("VEL","Velocity"),("INC","Inc"),
    ("COLOR","Color"),("COL","Color"),("CHAR","Char"),("MSG","Message"),
    ("SOUND","Sound"),("SND","Sound"),("POKEY","Pokey"),("EAROM","Earom"),
    ("PLAYER","Player"),("PLYR","Player"),("PL","Player"),
    ("TIMER","Timer"),("TIM","Timer"),("CNT","Count"),("NUM","Num"),
    ("FLAG","Flag"),("PTR","Ptr"),("TEMP","Temp"),("TMP","Temp"),
    ("START","Start"),("INIT","Init"),("RESET","Reset"),("TEST","Test"),
    ("GAME","Game"),("COIN","Coin"),("LIVES","Lives"),("LIV","Lives"),
    ("BONUS","Bonus"),("SPARK","Spark"),("STATION","Station"),
    ("LO","Lo"),("HI","Hi"),("L","Lo"),("H","Hi"),
]
_MORPH = sorted(MORPHEMES, key=lambda kv: -len(kv[0]))

# words that read as dangling when a comment gets truncated
TRAILING_FILLER = {"When","Assume","And","To","For","If","The","Is","Of","With",
                   "That","This","Then","But","So","As","At","On","In","By","From"}

def trim_filler(name):
    words = re.findall(r"[A-Z][a-z0-9]*|[0-9]+", name)
    while len(words) > 1 and words[-1] in TRAILING_FILLER:
        words.pop()
    return "".join(words) or name

def expand_identifier(name):
    """Expand a terse identifier ONLY when it decomposes completely into known
    morphemes (plus an optional trailing Lo/Hi letter and digits). A partial
    match would invent a misleading name, so those are rejected outright and
    the caller keeps Atari's original identifier."""
    s = name.upper()
    trailing = ""
    m = re.match(r"^(.*?)(\d+)$", s)
    if m:
        s, trailing = m.group(1), m.group(2)
    suffix = ""
    if len(s) > 2 and s[-1] in "LH":
        head = s[:-1]
        if any(head.endswith(k) for k, _ in _MORPH if len(k) >= 2):
            suffix = "Lo" if s[-1] == "L" else "Hi"
            s = head
    out, i = [], 0
    while i < len(s):
        for k, v in _MORPH:
            if len(k) > 1 and s.startswith(k, i):
                out.append(v)
                i += len(k)
                break
        else:
            return None          # leftover characters -> refuse to guess
    if not out:
        return None
    return "".join(out) + suffix + trailing
