"""Resolve every Space Duel vector-ROM shape to a name, with provenance.

Three independent naming sources, strongest first:

1. Ship pictures ($2800-$2FFF) - the 34-entry pointer table at $2800 gives each
   picture's address outright; names come from A2SHIP.MAC (SHPA0..SHPB16).
2. Character glyphs - the game holds two 38-entry JSRL tables ($324A and $3458)
   with identical structure (normal and cocktail-flipped sets). ASCVG.MAC fixes
   the encoding: index 0 = blank, 1..10 = '0'..'9', 11..36 = 'A'..'Z'.
3. Everything else - names from the AS2ROM.MAC source walk, snapped onto real
   block boundaries.

Anything still unnamed is emitted as SHAPE_xxxx rather than given a guessed name.
"""
import sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
import image, avg, vecmap, vshapes

GLYPH_TABLES = [(0x324A, "CHR"), (0x3458, "CHRF")]   # char JSRLs: normal, flipped
SHIP_PTRS, SHIP_COUNT = 0x2800, 34

def glyph_name(prefix, idx):
    """ASCVG.MAC encoding, now VERIFIED by rendering: with the correct two's-
    complement AVG decode the referenced shapes draw as their characters
    (A,B,C,D,E,O and digits confirmed visually). Slot 0 = blank, 1..10 =
    '0'..'9', 11..36 = 'A'..'Z'. These names were withdrawn once when a
    sign-magnitude decoding bug made the glyphs render as garbage - the fault
    was the renderer, not the table."""
    if idx == 0:
        return "%s_SPACE" % prefix
    if 1 <= idx <= 10:
        return "%s_%d" % (prefix, idx - 1)
    if 11 <= idx <= 36:
        return "%s_%s" % (prefix, chr(ord('A') + idx - 11))
    return "%s_X%02d" % (prefix, idx)

def jsrl_target(w):
    if (w >> 13) != 5:
        return None
    t = 0x2000 + ((w & 0x1FFF) * 2)
    return t if 0x2800 <= t <= 0x3FFF else None

def glyph_names(mem):
    out = {}
    for base, prefix in GLYPH_TABLES:
        for i in range(38):
            a = base + i * 2
            t = jsrl_target(mem[a] | (mem[a + 1] << 8))
            if t:
                out.setdefault(t, []).append(glyph_name(prefix, i))
    return out

def ship_pictures(mem):
    """[(name, addr, npoints)] for the 34 ship pictures."""
    tbl = vecmap.ship_table(mem)
    out = []
    for i, (nm, a) in enumerate(tbl):
        nxt = tbl[i + 1][1] if i + 1 < len(tbl) else a + 54
        n = max(0, min((nxt - a) // 2, 27))
        out.append((nm, a, n))
    return out

def xrefs(mem):
    """{shape addr: [source addresses that JSRL/JMPL to it]} across all ROMs."""
    refs = {}
    # Only scan regions that can legitimately contain JSRL/JMPL words: the AVG
    # display lists and the 6502 ROM. $2800-$2FFF is ship picture data, where a
    # matching bit pattern is coincidence, not a reference.
    scan = list(range(0x3000, 0x3FFE)) + list(range(0x4000, 0x8FFE))
    for a in scan:
        if a + 1 not in mem:
            continue
        word = mem[a] | (mem[a + 1] << 8)
        op = word >> 13
        if op not in (5, 7):                       # JSRL ($Axxx/$Bxxx), JMPL ($Exxx/$Fxxx)
            continue
        t = 0x2000 + ((word & 0x1FFF) * 2)
        if 0x2800 <= t <= 0x3FFF:
            refs.setdefault(t, []).append(a)
    return refs

def resolve(mem):
    """Shape names, most-trusted source wins:
       1. glyph tables ($324A/$3458)          - exact, render-verified
       2. program-ROM immediates + RSOURC     - bytes read at verified addresses
       3. AS2ROM source-walk order            - drifts; suffixed '?' (it named
          $3848 'SAUCRC' where the ROM proves PENT01, so it cannot be trusted)
    """
    import rom_names, build_map
    blks, assigned, secondary = vshapes.snap(mem)
    gly = glyph_names(mem)

    _m, src, out, _info = build_map.build()
    n1, _raw = rom_names.pass1(mem, src, out)
    n2, _hits = rom_names.pass2(mem)

    names, desc = {}, {}
    for st, nms in assigned.items():                     # weakest first
        names.setdefault(st, []).extend(n + "?" for n in nms)
    for a, nms in n1.items():
        names[a] = list(nms)
    for a, entries in n2.items():
        names[a] = [nm for nm, _d in entries]
        desc[a] = "; ".join(sorted({d for _n, d in entries}))
    # pass 3: shapes reached only via JSRL word tables the 6502 copies into
    # vector RAM (SAUCRC/SAUC*, PLTLIV/RHTSHP/LFTSHP), structurally verified
    n3 = rom_names.pass3(mem, n1)
    for a, (nm, why) in n3.items():
        names[a] = [nm]
        desc[a] = why
    for a, nms in gly.items():
        # The glyph table gives a slot number; where the ROM also yields a real
        # Atari name (HALF for slot 37), that name leads and the slot follows.
        prior = [n for n in names.get(a, []) if not n.endswith("?")]
        real = [n for n in prior if not n.startswith(("CHR_", "CHRF_"))]
        names[a] = real + nms if real else nms
        secondary.pop(a, None)

    # A source-order name ('?') that duplicates a name the ROM already proved
    # elsewhere is drift, not a second copy - the same failure that put SAUCRC
    # at $3848 where the ROM proves PENT01. Drop it: an honest SHAPE_xxxx beats
    # a confident-looking duplicate.
    proven = {n for nl in names.values() for n in nl if not n.endswith("?")}
    for a in list(names):
        keep = [n for n in names[a]
                if not (n.endswith("?") and n.rstrip("?") in proven)]
        if keep:
            names[a] = keep
        else:
            del names[a]

    # the ROM tail is zero fill up to the CKUM1 checksum byte, not a shape:
    # $0000 words decode as VCTR, so a linear sweep invents a phantom block
    fill, cksum = rom_names.rom_tail(mem)
    blks = [b for b in blks if b[0] < fill]
    return blks, names, secondary, gly, desc, (fill, cksum)

if __name__ == "__main__":
    mem = image.load()
    blks, names, secondary, gly, desc, tail = resolve(mem)
    refs = xrefs(mem)
    named = sum(1 for b in blks if b[0] in names)
    print("ship pictures ($2800-$2FFF) : %d" % len(ship_pictures(mem)))
    print("AVG blocks ($3000-$3FFF)    : %d" % len(blks))
    print("  named                     : %d (%.0f%%)" % (named, 100.0*named/len(blks)))
    print("  named by glyph table      : %d (exact)" % len(gly))
    print("shapes with inbound refs    : %d" % len(refs))
    print("\nsample glyph resolution:")
    for a in sorted(gly)[:6]:
        print("   $%04X  %-16s refs=%d" % (a, ",".join(gly[a]), len(refs.get(a, []))))
