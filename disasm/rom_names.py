"""Name vector-ROM shapes from the program ROM itself - no source-walk drift.

Two extraction passes, both reading actual bytes at verified addresses:

Pass 1 - immediate pairs. The game loads shape JSRL words as immediates via
  the LALJSR/LXHJSR/UBYJSR/LBYJSR macros (operand = the shape's label) and via
  LAL/LXH of HEAD-generated NAME8/NAME9 globals. Every such source line is
  mapped to a verified ROM address, so the byte at addr+1 is ground truth.

Pass 2 - the RSOURC table. ROCKDAT holds 32 consecutive JMPL words: 4 rotation
  frames x 8 obstacle types in .IRPC order ROCK1,ROCK2,PYRM,CUBE,STAR,PENT,
  PLN,HEXA. The run is located by signature scan (32 back-to-back $Exxx words
  into $3000-$3FFF), and ROCPIC's comments translate the type names:
  ROCK=spinner, PYRM=octahedron, CUBE=cube, STAR=stargon, PENT=hat box,
  PLN=book, HEXA=hexaraheadon.
"""
import sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
import image, build_map, rtexpr, avg

PAIR_MACROS = {"LALJSR": ("lo", 1), "LBYJSR": ("lo", 0),
               "LAHJSR": ("hi", 1), "LXHJSR": ("hi", 1), "UBYJSR": ("hi", 0)}

ROCK_TYPES = [("ROCK%d1", "spinner"), ("ROCK%d2", "spinner, opposite spin"),
              ("PYRM%d1", "octahedron"), ("CUBE%d1", "cube"),
              ("STAR%d1", "stargon"), ("PENT%d1", "hat box"),
              ("PLN%d1", "book"), ("HEXA%d1", "hexaraheadon")]

def target(word):
    if (word >> 13) not in (5, 7):          # JSRL / JMPL
        return None
    t = 0x2000 + ((word & 0x1FFF) * 2)
    return t if 0x2800 <= t <= 0x3FFF else None

def pass1(mem, src, out):
    """{base_name: {'hi': byte, 'lo': byte, 'at': [addr]}} from immediates."""
    got = {}
    for fn, amap in out.items():
        for n, a in amap.items():
            l = src[fn][n - 1]
            name = half = off = None
            if l.kind == "macro" and l.op.upper() in PAIR_MACROS:
                half, off = PAIR_MACROS[l.op.upper()]
                name = l.operand.strip().split(",")[0].strip()
            elif l.kind == "macro" and l.op.upper() in ("LAL", "LAH", "LXL", "LXH"):
                t = l.operand.strip()
                m = re.match(r"^([A-Z][A-Z0-9$.]*?)([89])$", t)
                if m:
                    name, half, off = m.group(1), ("hi" if m.group(2) == "8" else "lo"), 1
            if not name or not re.match(r"^[A-Z][A-Z0-9]*$", name):
                continue
            base = rtexpr.sym6(name.rstrip("89")) if half else None
            rec = got.setdefault(name if l.op.upper() in PAIR_MACROS else base,
                                 {"at": []})
            rec[half] = mem[a + off]
            rec["at"].append(a)
    names = {}
    for name, rec in got.items():
        if "hi" in rec and "lo" in rec:
            t = target((rec["hi"] << 8) | rec["lo"])
            if t is not None:
                names.setdefault(t, []).append(name)
    return names, got

def pass2(mem):
    """Locate the 32-word RSOURC JMPL table by signature and name its targets."""
    hits = []
    for a in range(0x4000, 0x8FFF - 64):
        ok = True
        for k in range(32):
            w = mem[a + 2*k] | (mem[a + 2*k + 1] << 8)
            if (w >> 13) != 7 or target(w) is None:
                ok = False
                break
        if ok:
            hits.append(a)
    if len(hits) != 1:
        return {}, hits
    base = hits[0]
    names = {}
    for frame in range(4):
        for i, (fmt, desc) in enumerate(ROCK_TYPES):
            k = frame * 8 + i
            w = mem[base + 2*k] | (mem[base + 2*k + 1] << 8)
            names.setdefault(target(w), []).append((fmt % frame, desc))
    return names, hits

if __name__ == "__main__":
    mem = image.load()
    _m, src, out, _info = build_map.build()
    n1, raw = pass1(mem, src, out)
    print("pass 1 - immediate pairs: %d shapes named" % len(n1))
    for t in sorted(n1):
        print("   $%04X  %s" % (t, ", ".join(n1[t])))
    n2, hits = pass2(mem)
    print("\npass 2 - RSOURC table found at: %s" % ", ".join("$%04X" % h for h in hits))
    for t in sorted(n2):
        print("   $%04X  %s" % (t, ", ".join("%s (%s)" % x for x in n2[t])))


# --------------------------------------------------------------- pass 3
# Shapes reached only through JSRL word TABLES that the 6502 copies into
# vector RAM, plus the ROM tail. Each is confirmed against ROM structure
# before its name is applied - nothing here is a bare hardcoded address.
#
# Source structure (AS2ROM.MAC 1013-1056, 1099-1120):
#   SAUCRC:: .IRPC X,<0123> / JSRL SAUC'X / .ENDR   then SAUCER:
#   PLTLIV:  SCAL / JSRL RHTSHP / VCTR / JSRL LFTSHP / VCTR / RTSL   then SHIELD:
#   FLARE .. RTSL, then .REPT R .BYTE 0 up to .=3FFF, CKUM1:: .BYTE 25

def jsrl_word_run(mem, a, limit=8):
    """Length of the run of consecutive JSRL words starting at a."""
    n = 0
    while n < limit:
        w = mem[a + 2*n] | (mem[a + 2*n + 1] << 8)
        if (w >> 13) != 5 or target(w) is None:
            break
        n += 1
    return n

def pass3(mem, named):
    """{addr: (name, why)} for table-reached shapes and the ROM tail."""
    out = {}
    addr_of = {}
    for a, nms in named.items():
        for n in nms:
            addr_of.setdefault(n, a)

    # SAUCRC: the JSRL-word table immediately preceding SAUCER
    saucer = addr_of.get("SAUCER")
    if saucer:
        # walk back to the FIRST word of the run, not merely the first position
        # that happens to parse - stopping early split a 4-entry table into 2
        t = saucer
        while t - 2 >= 0x3000:
            w = mem[t - 2] | (mem[t - 1] << 8)
            if (w >> 13) != 5 or target(w) is None:
                break
            t -= 2
        for back in [saucer - t]:
            n = jsrl_word_run(mem, t)
            if n * 2 == back and n >= 2:
                out[t] = ("SAUCRC", "JSRL table of %d saucer frames, immediately "
                                    "before SAUCER" % n)
                for i in range(n):
                    w = mem[t + 2*i] | (mem[t + 2*i + 1] << 8)
                    out[target(w)] = ("SAUC%d" % i,
                                      "saucer frame %d, entry %d of the SAUCRC table "
                                      "(shape data from A2SAUC.DAT)" % (i, i))
                break

    # PLTLIV: SCAL / JSRL / VCTR / JSRL / VCTR / RTSL just before SHIELD
    shield = addr_of.get("SHIELD")
    if shield:
        for back in range(6, 24, 2):
            t = shield - back
            seq, p, js = [], t, []
            while p < shield:
                d = avg.decode(mem, p)
                if not d:
                    break
                seq.append(d[0])
                if d[0] == "JSRL":
                    js.append(int(d[1].replace("$", ""), 16))
                p += d[2]
            if p == shield and seq[:2] == ["SCAL", "JSRL"] and len(js) == 2 \
               and seq[-1] == "RTSL":
                out[t] = ("PLTLIV", "plot-lives list: JSRLs the two lives ships")
                out[js[0]] = ("RHTSHP", "right-facing lives ship (JSRL'd by PLTLIV)")
                out[js[1]] = ("LFTSHP", "left-facing lives ship (JSRL'd by PLTLIV)")
                break
    return out

def rom_tail(mem, lo=0x3000, hi=0x3FFF):
    """(fill_start, checksum_addr) for the zero fill + CKUM1 at the ROM end."""
    a = hi
    while a > lo and mem[a - 1] == 0:
        a -= 1
    return a, hi
