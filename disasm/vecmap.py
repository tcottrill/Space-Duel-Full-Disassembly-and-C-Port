"""Map Atari's own vector/picture labels onto vector-ROM addresses.

The two vector ROMs hold DIFFERENT formats:

  $2800-$2FFF  136006-106, source A2SHIP.MAC
      A 34-entry pointer table at $2800, then 34 ship pictures. Each picture is
      a list of 2-byte records emitted by the TWBYPIC macro as .BYTE YY,XX, so
      each record is a signed (dy, dx) step. This is NOT AVG data - the 6502
      expands it into vectors at run time.

  $3000-$3FFF  136006-107, source AS2ROM.MAC
      Real AVG display lists built from the VGMC.MAC macros (VCTR/SVEC/CNTR/
      JSRL/RTSL/STAT/SCAL/COLOR), so this one decodes as AVG.

Both sources are .ASECT with an explicit origin, so addresses are known outright
and only the VCTR long/short choice needs resolving - which the ROM settles.
"""
import sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
import paths
import macsrc, mapper, rtexpr, image, avg

SHIP_PTRS = 0x2800
SHIP_COUNT = 34

def ship_table(mem):
    """The pointer table at $2800 -> [(name, addr)] using A2SHIP.MAC's names."""
    lines = macsrc.parse_file(paths.archive("A2SHIP.MAC"))
    names = []
    for l in lines:
        if l.kind == "directive" and l.op.upper() == ".WORD" and l.operand.strip():
            t = l.operand.strip()
            if re.match(r"^SHP[AB]\d+$", t):
                names.append(t)
    out = []
    for i in range(SHIP_COUNT):
        a = SHIP_PTRS + i * 2
        tgt = mem[a] | (mem[a + 1] << 8)
        nm = names[i] if i < len(names) else "SHIP_%02d" % i
        out.append((nm, tgt))
    return out

def ship_points(mem, addr, limit=64):
    """Read a picture's (dy, dx) records. Pictures are a fixed 54 bytes here."""
    pts = []
    for i in range(limit):
        a = addr + 2 * i
        if a + 1 > image.VROM_HI:
            break
        dy, dx = mem[a], mem[a + 1]
        pts.append((dy - 256 if dy > 127 else dy, dx - 256 if dx > 127 else dx))
    return pts

# --------------------------------------------------------------- AVG mapping
AVG_MACROS = {"VCTR", "SVEC", "CNTR", "JSRL", "JMPL", "RTSL", "STAT",
              "SCAL", "HALT", "COLOR", "LABS", "VCTRSC", "ALPHA"}

def map_as2rom(mem, org=0x3000, path=None, srcdir=None):
    """Walk AS2ROM.MAC after its .=3000 origin, locking every emitted word
    against the ROM. Shape names come from `HEAD <name>` (which emits nothing -
    it defines the label plus the NAME8/NAME9 JSRL byte pair) and from ordinary
    LABEL: lines.

    .INCLUDE files are walked inline: several of them (VGAN in particular) emit
    vector data, and skipping them desynchronises everything that follows.

    Returns (names {addr: [name]}, at {(file,line): addr}, desyncs)."""
    srcdir = paths.archive_dir(srcdir)
    path = path or paths.archive("AS2ROM.MAC", srcdir)
    syms = mapper.include_symbols(srcdir)
    ev = rtexpr.Expr(dict(syms), radix=16)
    names, at, desyncs = {}, {}, []
    # order[] keeps source order plus a flag: True when an RTSL/HALT ended the
    # previous shape before this name, i.e. this name really starts a new shape
    # rather than being a secondary entry point inside the current one.
    order = []
    state = {"pc": None, "term": True}

    def rom(a):
        return avg.decode(mem, a)

    def walk(lines, fname, depth=0):
        for l in lines:
            if l.kind == "directive" and l.op == ".=":
                try:
                    state["pc"] = ev.eval(l.operand, dot=state["pc"] if state["pc"] is not None else org)
                except Exception:
                    pass
                continue
            if state["pc"] is None:
                continue
            pc = state["pc"]
            at[(fname, l.n)] = pc
            for nm, _g in l.labels:
                names.setdefault(pc, []).append(nm)
                order.append((pc, nm, state["term"]))
                state["term"] = False

            if l.kind == "directive" and l.op.upper() == ".INCLUDE" and depth < 4:
                inc = l.operand.strip().split()[0].strip().upper()
                if not inc.endswith(".MAC"):
                    inc += ".MAC"
                ipath = os.path.join(srcdir, inc)
                if os.path.exists(ipath):
                    walk(macsrc.parse_file(ipath), inc, depth + 1)
                continue

            if l.kind == "macro":
                u = l.op.upper()
                if u == "HEAD":
                    nm = l.operand.strip().split(",")[0].strip()
                    if nm:
                        names.setdefault(pc, []).append(nm)
                        order.append((pc, nm, state["term"]))
                        state["term"] = False
                    continue
                if u in ("VCTR", "VCTRSC"):
                    d = rom(pc)
                    if d and d[0] in ("VCTR", "SVEC"):
                        state["pc"] = pc + d[2]
                    else:
                        desyncs.append((fname, l.n, pc, u, d[0] if d else "?"))
                        state["pc"] = pc + 4
                    continue
                if u in ("JSRL", "JMPL", "RTSL", "CNTR", "SCAL", "STAT", "COLOR", "HALT"):
                    d = rom(pc)
                    got = d[0] if d else "?"
                    ok = (got == u) or (u in ("STAT", "COLOR") and got in ("STAT", "COLOR"))
                    if not ok:
                        desyncs.append((fname, l.n, pc, u, got))
                    if u in ("RTSL", "HALT"):
                        state["term"] = True
                    state["pc"] = pc + 2
                    continue
                if u in ("LBYJSR", "UBYJSR"):
                    state["pc"] = pc + 1
                    continue
                if u == "LABS":
                    d = rom(pc + 2)
                    state["pc"] = pc + 2 + (d[2] if d else 4)
                    continue
                if u == "ALPHA":
                    t = l.operand.strip()
                    if t.startswith("^") and len(t) > 2:
                        dl = t[1]
                        j = t.find(dl, 2)
                        state["pc"] = pc + 2 * (j - 2 if j > 0 else 0)
                    continue
                continue

            if l.kind == "directive":
                u, o = l.op.upper(), l.operand.strip()
                if u == ".WORD":
                    state["pc"] = pc + 2 * mapper.count_args(o)
                elif u == ".BYTE":
                    state["pc"] = pc + mapper.count_args(o)
                elif u == ".BLKB":
                    try: state["pc"] = pc + ev.eval(o, dot=pc)
                    except Exception: pass
    walk(macsrc.parse_file(path), os.path.basename(path))
    return names, at, desyncs, order

if __name__ == "__main__":
    mem = image.load()
    tbl = ship_table(mem)
    print("ship pictures from A2SHIP.MAC pointer table at $2800:")
    for nm, a in tbl[:6]:
        print("   %-8s $%04X" % (nm, a))
    print("   ... %d total, spacing $%02X" % (len(tbl), tbl[1][1] - tbl[0][1]))
    labels, at, ds = map_as2rom(mem)
    inrom = {k: v for k, v in labels.items() if 0x3000 <= v <= 0x3FFF}
    print("\nAS2ROM.MAC labels mapped into $3000-$3FFF: %d  (desyncs %d)"
          % (len(inrom), len(ds)))
    for k, v in sorted(inrom.items(), key=lambda kv: kv[1])[:10]:
        print("   $%04X %s" % (v, k))
