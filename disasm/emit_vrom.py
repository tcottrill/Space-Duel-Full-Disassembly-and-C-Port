"""Emit the byte-exact vector ROM listing, correctly split by data format.

  $2800-$2FFF  136006-106  ship PICTURE data (NOT AVG): a 34-entry pointer
               table, then pictures of 2-byte signed (dy,dx) records that
               SHPDISPLAYS expands into vectors at run time.
  $3000-$3FFF  136006-107  real AVG display lists, then zero fill and the
               CKUM1 checksum byte at $3FFF.

Every AVG instruction is re-encoded and byte-compared; anything that will not
round-trip exactly is emitted as raw .word so the file stays byte-faithful.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import paths
import image, avg, vecmap, shippix, rom_names, shapes as shp

def sm13(v):
    """13-bit two's complement, matching VGMC.MAC's .WORD DY&^H1FFF."""
    return v & 0x1FFF

def sm5(v):
    return v & 0x1F

def encode(mn, oper):
    def ints(s):
        return [int(x.strip().replace("$", ""), 16) if "$" in x else int(x)
                for x in s.split(",")] if s else []
    if mn == "HALT":  return [0x2000]
    if mn == "RTSL":  return [0xC000]
    if mn == "CNTR":  return [0x8040] if not oper else None
    if mn == "VCTR":
        dx, dy, z = ints(oper)
        return [sm13(dy), ((z << 13) | sm13(dx)) & 0xFFFF]
    if mn == "SVEC":
        dx, dy, z = ints(oper)
        return [0x4000 | ((z & 7) << 5) | sm5(dx >> 1) | (sm5(dy >> 1) << 8)]
    if mn == "SCAL":
        s, ls = ints(oper)
        return [0x7000 | ((s & 0xF) << 8) | (ls & 0xFF)]
    if mn == "COLOR":
        col, lum = ints(oper)
        return [0x6400 | ((lum & 0xF) << 4) | (col & 0xF)]
    if mn in ("JSRL", "JMPL"):
        t = int(oper.replace("$", ""), 16)
        base = 0xA000 if mn == "JSRL" else 0xE000
        return [base | (((t - avg.VG_BASE) // 2) & 0x1FFF)]
    return None

def emit(path=None):
    path = path or paths.VECTOR_ROM
    mem = image.load()
    L = [
        ";Space Duel (Atari, 1982) - vector ROMs, byte-exact listing.",
        ";",
        ";  $2800-$2FFF  136006-106  ship PICTURE data - NOT AVG. A 34-entry",
        ";               pointer table, then pictures built from 2-byte signed",
        ";               (dy,dx) records (A2SHIP.MAC TWBYPIC -> .BYTE YY,XX)",
        ";               which SHPDISPLAYS expands into vectors at run time.",
        ";  $3000-$3FFF  136006-107  real AVG display lists (AS2ROM.MAC), then",
        ";               zero fill and the CKUM1 checksum byte at $3FFF.",
        ";",
        ";AVG deltas are 13-bit TWO'S COMPLEMENT (see aae_avg.cpp twos_comp_val",
        ";and VGMC.MAC's .WORD DY&^H1FFF) - not the sign-magnitude of the DVG.",
        ";Space Duel is the colour XY board, so COLOR replaces STAT.",
        ";Every line below was re-encoded and byte-compared with the ROM.",
        ";Shapes are labelled with Atari's own names; see vec_names.py for the",
        ";name table and shapes_preview.html for rendered previews.",
        "",
        ".org $2800",
        "",
        ";------------------------[ ship picture pointer table ]------------------------",
    ]
    tbl = vecmap.ship_table(mem)
    for i, (nm, a) in enumerate(tbl):
        L.append("V%04X:  .word $%04X              ;[%2d] -> %s" % (0x2800 + i*2, a, i, nm))
    L.append("")
    L.append(";----------------------------[ ship pictures ]----------------------------")
    covered = set(range(0x2800, 0x2800 + len(tbl)*2))
    for nm, addr, t, recs in shippix.pictures(mem):
        L.append("")
        L.append("%s:  ;type %s: %d ship records + %d thrust-flame, 2 bytes each"
                 % (nm, "AB"[t], shippix.WHOLE[t], shippix.THRUST[t] - shippix.WHOLE[t]))
        whole = shippix.WHOLE[t]
        for i, (dx, dy) in enumerate(recs):
            p = addr + 2*i
            covered.update((p, p+1))
            if i == 0:
                part = "move (blanked by SHPDI8 epilogue)"
            elif i == whole - 1:
                part = "move (blanked: return leg / flame bridge)"
            elif i < whole:
                part = "ship"
            else:
                part = "thrust flame (white)"
            L.append("V%04X:  .byte $%02X, $%02X          ;dy=%-5d dx=%-5d %s" %
                     (p, mem[p], mem[p+1], dy, dx, part))
    gaps = [a for a in range(0x2800, 0x3000) if a not in covered]
    if gaps:
        L.append("")
        L.append(";---- inter-picture padding (CRPAGE keeps pictures off page breaks) ----")
        runs, s = [], None
        for a in range(0x2800, 0x3001):
            if a in covered or a >= 0x3000:
                if s is not None:
                    runs.append((s, a-1)); s = None
            elif s is None:
                s = a
        for lo, hi in runs:
            for a in range(lo, hi+1, 8):
                row = [mem[x] for x in range(a, min(a+8, hi+1))]
                L.append("V%04X:  .byte %s" % (a, ", ".join("$%02X" % v for v in row)))

    L.append("")
    L.append(";--------------------------[ AVG display lists ]--------------------------")
    L.append(";Shape names come from vec_names.py, resolved by shapes.py (see")
    L.append(";README.md): glyph tables, program-ROM immediates, the RSOURC")
    L.append(";table, and the JSRL word tables. A name carrying a '?' in")
    L.append(";vec_names.py comes only from AS2ROM source order, which drifts;")
    L.append(";the '?' is not part of the label - such entry points are marked")
    L.append(";UNVERIFIED on their label line instead.")
    blks, names, secondary, gly, desc, tail = shp.resolve(mem)
    refs = shp.xrefs(mem)

    def ref_note(a, limit=6):
        rs = refs.get(a, [])
        out = []
        for r in rs[:limit]:
            where = "vector ROM" if 0x2800 <= r <= 0x3FFF else "main ROM"
            out.append(";  refs: %s $%04X" % (where, r))
        if len(rs) > limit:
            out.append(";  refs: ... and %d more" % (len(rs) - limit))
        return out

    # one label per address, and the reverse map for symbolic JSRL/JMPL operands
    label_at = {}
    for addr, nms in names.items():
        if nms:
            label_at[addr] = nms[0]
    for addr, nms in secondary.items():
        if nms and addr not in label_at:
            label_at[addr] = nms[0]
    def sym(t):
        n = label_at.get(t)
        return n.replace("?", "") if n else "$%04X" % t

    fill, cksum = rom_names.rom_tail(mem)
    a, exact, raw = 0x3000, 0, 0
    while a < fill:
        d = avg.decode(mem, a)
        if not d:
            break
        mn, oper, ln = d
        if a in label_at:
            nm = label_at[a]
            L.append("")
            L.append("%s:%s ;JSRL operand $%03X%s"
                     % (nm.replace("?", ""), "" if len(nm) > 14 else " " * (15 - len(nm)),
                        (a - 0x2000) // 2,
                        "  -- name from AS2ROM source order only, UNVERIFIED"
                        if nm.endswith("?") else ""))
            if desc.get(a):
                L.append(";  %s" % desc[a])
            if secondary.get(a):
                L.append(";  secondary entry points: %s" % ", ".join(secondary[a]))
            lit = False
            p2 = a
            while p2 <= 0x3FFF:
                dd = avg.decode(mem, p2)
                if not dd:
                    break
                if dd[0] in ("VCTR", "SVEC") and dd[1].split(",")[-1].strip() != "0":
                    lit = True
                if dd[0] in ("RTSL", "HALT"):
                    break
                p2 += dd[2]
            if not lit:
                L.append(";  no lit vectors - beam positioning / clip / advance list,")
                L.append(";  not a drawable shape; renders blank by design")
            # a run of nothing but JSRL words is a TABLE the 6502 indexes into,
            # not a list meant to run start-to-finish
            if rom_names.jsrl_word_run(mem, a) >= 2:
                n_ent = rom_names.jsrl_word_run(mem, a)
                L.append(";  JSRL word table (%d entries) - the 6502 copies one entry"
                         % n_ent)
                L.append(";  into vector RAM; executing it start-to-finish would draw")
                L.append(";  every frame stacked on top of one another")
            L += ref_note(a)
        words = encode(mn, oper)
        ok = words is not None and len(words)*2 == ln and all(
            mem[a + 2*i] == (w & 0xFF) and mem[a + 2*i + 1] == (w >> 8)
            for i, w in enumerate(words))
        shown = oper
        if ok and mn in ("JSRL", "JMPL"):
            shown = sym(int(oper.replace("$", ""), 16))
        if ok:
            exact += 1
            raw_hex = " ".join("%04X" % (mem[a+2*i] | (mem[a+2*i+1] << 8))
                               for i in range(ln // 2))
            L.append("V%04X:  %-6s %-22s ;%s" % (a, mn, shown, raw_hex))
        else:
            raw += 1
            ws = ", ".join("$%02X%02X" % (mem[a+2*i+1], mem[a+2*i]) for i in range(ln//2))
            L.append("V%04X:  .word %-18s ;%s %s" % (a, ws, mn, oper))
        a += ln
    L += [
        "",
        ";------------------------------[ ROM tail ]------------------------------",
        ";AS2ROM.MAC pads with `.REPT R / .BYTE 0` up to `.=3FFF`, then CKUM1.",
        ";A linear AVG sweep would decode the $0000 fill as VCTR - it is not code.",
    ]
    for p in range(fill, cksum, 16):
        row = [mem[x] for x in range(p, min(p+16, cksum))]
        L.append("V%04X:  .byte %s" % (p, ", ".join("$%02X" % v for v in row)))
    L.append("CKUM1:")
    L.append("V%04X:  .byte $%02X                    ;ROM checksum" % (cksum, mem[cksum]))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write("\n".join(L) + "\n")
    return exact, raw, len(tbl)

if __name__ == "__main__":
    e, r, n = emit()
    print("wrote", os.path.relpath(paths.VECTOR_ROM, paths.ROOT))
    print("  ship pictures        : %d (pointer table + picture data)" % n)
    print("  AVG round-trip exact : %d" % e)
    print("  AVG emitted as .word : %d" % r)
    print("  shape labels emitted : see file")
