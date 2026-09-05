"""Emit the Space Duel vector-object listing, name table, and shape preview."""
import sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
import paths
import image, avg, shapes, vecmap, shippix

def word(mem, a):
    return mem[a] | (mem[a + 1] << 8)

def jsrl_operand(a):
    return (a - 0x2000) // 2

def ref_note(refs, a, limit=6):
    out = []
    for r in refs.get(a, [])[:limit]:
        where = ("vector ROM" if 0x2800 <= r <= 0x3FFF else "main ROM")
        out.append("; refs: %s $%04X" % (where, r))
    extra = len(refs.get(a, [])) - limit
    if extra > 0:
        out.append("; refs: ... and %d more" % extra)
    return out

def emit_listing(mem, blks, names, secondary, refs, path, tail=(0x3F2A, 0x3FFF)):
    L = []
    L += [
        "; Space Duel vector ROMs - vector objects.",
        ";",
        "; $2800-$2FFF  136006-106  ship pictures. NOT AVG data: a 34-entry",
        ";              pointer table at $2800, then 34 pictures of 2-byte",
        ";              records emitted by A2SHIP.MAC's TWBYPIC macro as",
        ";              .BYTE YY,XX - each record is a signed (dy,dx) step",
        ";              that the 6502 expands into vectors at run time",
        ";              (SHPDISPLAYS). Draw counts are FIXED per ship type:",
        ";              type A (SHPA*) 23 ship + 4 flame records, type B",
        ";              (SHPB*) 21 + 4. Every record draws lit; the TWBYPIC",
        ";              BB/EE columns in the source are vestigial.",
        ";",
        "; $3000-$3FFF  136006-107  real AVG display lists (AS2ROM.MAC),",
        ";              built from the VGMC.MAC macros. Space Duel is the",
        ";              colour XY board, so COLOR replaces the STAT opcode.",
        ";",
        "; CHR_* / CHRF_* glyphs are named from the game's own 38-entry character",
        "; JSRL tables at $324A (normal) and $3458 (flipped), using the ASCVG.MAC",
        "; encoding: slot 0 = blank, 1..10 = '0'..'9', 11..36 = 'A'..'Z'.",
        "; VERIFIED by rendering with the correct two's-complement AVG decode",
        "; (see aae_avg.cpp): the shapes draw as their letters.",
        "; CHRF_* draw upside down BY DESIGN - it is the flipped character set,",
        "; used for text facing the second player.",
        "; 'addr/word' is the byte address and the JSRL operand ((addr-$2000)/2).",
        "",
        "; ======================================================================",
        "; SHIP PICTURES  $2800-$2FFF",
        "; ======================================================================",
        "",
        "SHIP_PTR_TABLE:  ; 34 words, indexed by ship shape number",
    ]
    tbl = vecmap.ship_table(mem)
    for i, (nm, a) in enumerate(tbl):
        L.append("2800+%02X:  .word $%04X            ; -> %s" % (i * 2, a, nm))
    L.append("")
    for nm, addr, t, recs in shippix.pictures(mem):
        whole, thrust = shippix.WHOLE[t], shippix.THRUST[t]
        L.append("%s: (type %s picture: %d ship records + %d thrust-flame)"
                 % (nm, "AB"[t], whole, thrust - whole))
        L.append("; records emit lit (z=1), then the SHPDI8 codicil blanks the")
        L.append("; first and last (and the flame bridge when thrusting);")
        L.append("; damage: COLOR black inserted %d records before the end (SHPD4TABLE)"
                 % shippix.DAMAGE_SPOT[t])
        L += ref_note(refs, addr)
        for i, (dx, dy) in enumerate(recs):
            a = addr + 2 * i
            if i == 0:
                part = "move (blanked by SHPDI8 epilogue)"
            elif i == whole - 1:
                part = "move (blanked: return leg / flame bridge)"
            elif i < whole:
                part = "ship"
            else:
                part = "thrust flame (white)"
            L.append("%04X:  %02X %02X    dy=%-5d dx=%-5d %s"
                     % (a, mem[a], mem[a + 1], dy, dx, part))
        L.append("")

    L += [
        "; ======================================================================",
        "; AVG DISPLAY LISTS  $3000-$3FFF",
        "; ======================================================================",
        "",
    ]
    for st, end, ops in blks:
        nm = names.get(st)
        label = nm[0] if nm else "SHAPE_%04X" % st
        alias = ("  (also %s)" % ", ".join(nm[1:])) if nm and len(nm) > 1 else ""
        L.append("%s: (JSRL operand $%03X)%s" % (label, jsrl_operand(st), alias))
        lit = any(d[0] in ("VCTR", "SVEC") and d[1].split(",")[-1].strip() != "0"
                  for _a, d in ops)
        if not lit:
            L.append("; no lit vectors - beam positioning / clip / advance list,")
            L.append("; not a drawable shape; renders blank by design")
        if st in desc:
            L.append("; %s - named from the RSOURC JMPL table in program ROM" % desc[st])
        elif nm and nm[0].endswith("?"):
            L.append("; name from AS2ROM source order only - UNVERIFIED (hence the ?)")
        if st in secondary:
            L.append("; secondary entry points: %s" % ", ".join(secondary[st]))
        L += ref_note(refs, st)
        for a, d in ops:
            if a != st and a in names:
                # glyph (or other) entry point in the middle of the block
                L.append("%s: (JSRL operand $%03X, entry inside block)"
                         % (names[a][0], jsrl_operand(a)))
            mn, oper, ln = d
            raw = " ".join("%04X" % word(mem, a + 2 * k) for k in range(ln // 2))
            L.append("%04X/%03X:  %-10s %-6s %s" % (a, jsrl_operand(a), raw, mn, oper))
        L.append("")
    open(path, "w").write("\n".join(L) + "\n")
    return len(L)

def emit_names(mem, blks, names, refs, path):
    L = ["# generated by disasm/emit_shapes.py - Space Duel vector object names",
         "VEC_NAMES = {"]
    for nm, addr, t, recs in shippix.pictures(mem):
        L.append("    0x%04X: '%s',  # ship picture type %s, %d+%d records, refs=%d"
                 % (addr, nm, "AB"[t], shippix.WHOLE[t],
                    shippix.THRUST[t] - shippix.WHOLE[t], len(refs.get(addr, []))))
    for st, end, ops in blks:
        nm = names.get(st)
        label = nm[0] if nm else "SHAPE_%04X" % st
        vec = sum(1 for _a, d in ops if d[0] in ("VCTR", "SVEC"))
        L.append("    0x%04X: '%s',  # vec=%d refs=%d" % (st, label, vec, len(refs.get(st, []))))
    L.append("}")
    open(path, "w").write("\n".join(L) + "\n")
    return len(L) - 3


def ship_segments(mem, name):
    """Ship picture -> [(x0,y0,x1,y1,draw)] using verified per-point brightness.
    A BB=0 record repositions the beam without drawing; rendering it as a line
    would show a stroke the hardware never draws."""
    for nm, addr, pts, ok in shippix.shapes_with_brightness(mem):
        if nm != name:
            continue
        segs, x, y = [], 0, 0
        for dx, dy, draw in pts:
            nx, ny = x + dx, y + dy
            segs.append((x, y, nx, ny, draw))
            x, y = nx, ny
        return segs
    return []

def scal_factor(b, lin):
    """aae_avg.cpp: b=((w>>8)&7)+8; l=(~w)&0xff; scale=(l<<16)>>b
    -> factor = ((~lin)&0xFF)/256 / 2^b   (the linear part is complemented)."""
    return ((~lin) & 0xFF) / 256.0 / (1 << (b & 7))

def avg_segments(ops, mem=None, depth=0, state=None):
    """AVG block -> [(x0,y0,x1,y1,draw)].

    Follows JSRL/JMPL: Space Duel composes many shapes out of called sub-lists,
    so rendering only a block's own VCTRs yields disconnected fragments. SCAL is
    applied as its binary power-of-two divisor, which is what governs relative
    size inside a shape.
    """
    if state is None:
        # A shape that draws before setting SCAL inherits the caller's scale.
        # The ambient text scale is SCAL 1,$00: HALF restores exactly that on
        # exit ($32E6) and SHOT sets it on entry, so it is the resting value.
        # Defaulting to 1.0 drew such strokes at twice their true size - the
        # slash of the 1/2 glyph towered over its digits.
        state = {"x": 0.0, "y": 0.0, "scale": scal_factor(1, 0)}
    segs = []
    for _a, d in ops:
        mn, oper, _ln = d
        if mn in ("VCTR", "SVEC"):
            try:
                dx, dy, z = [int(v) for v in oper.split(",")]
            except Exception:
                continue
            nx = state["x"] + dx * state["scale"]
            ny = state["y"] + dy * state["scale"]
            segs.append((state["x"], state["y"], nx, ny, z > 0))
            state["x"], state["y"] = nx, ny
        elif mn == "CNTR":
            state["x"], state["y"] = 0, 0
        elif mn == "SCAL":
            # aae_avg.cpp: b=((w>>8)&7)+8; l=(~w)&0xff; scale=(l<<16)>>b
            # i.e. factor = ((~w)&0xFF)/256 / 2^((w>>8)&7); SCAL $7000 ~ full size
            try:
                parts = [int(v.replace("$",""),16) if "$" in v else int(v)
                         for v in oper.split(",")]
                b = parts[0] & 7
                lin = (parts[1] & 0xFF) if len(parts) > 1 else 0
                state["scale"] = scal_factor(b, lin)
            except Exception:
                pass
        elif mn in ("JSRL", "JMPL") and mem is not None and depth < 6:
            try:
                t = int(oper.replace("$", ""), 16)
            except Exception:
                continue
            if not (0x3000 <= t <= 0x3FFF):
                continue
            sub, a = [], t
            while a <= 0x3FFF and len(sub) < 400:
                sd = avg.decode(mem, a)
                if not sd:
                    break
                sub.append((a, sd))
                if sd[0] in ("RTSL", "HALT"):
                    break
                a += sd[2]
            segs += avg_segments(sub, mem, depth + 1, state)
            if mn == "JMPL":
                break
    return segs

def emit_preview(mem, blks, names, refs, path):
    entries = []
    def add(key, label, segs, addr):
        if not segs:
            return
        entries.append((addr, key, label, segs))

    def all_dark(segs):
        """True when nothing is lit: a positioning / clip / advance list, not a
        drawable shape (LIVEPAR, CHR_SPACE, WNDSE ...). Rendering blank is
        correct for these, so label them rather than let them look broken."""
        return not any(e and (a, b) != (c, d) for a, b, c, d, e in segs)

    for nm, addr, pts, ok in shippix.shapes_with_brightness(mem):
        segs, x, y = [], 0, 0
        for dx, dy, draw in pts:
            segs.append((x, y, x + dx, y + dy, draw))
            x, y = x + dx, y + dy
        add("P%04X" % addr, nm, segs, addr)
    block_starts = {b[0] for b in blks}
    for st, end, ops in blks:
        nm = names.get(st)
        label = nm[0] if nm else "SHAPE_%04X" % st
        add("V%04X" % st, label, avg_segments(ops, mem), st)
    # glyphs (and any other named entries) that live INSIDE a block: render
    # from the entry address to the terminating RTSL so every one is visible
    for a in sorted(names):
        if a in block_starts or not (0x3000 <= a <= 0x3FFF):
            continue
        sub, p = [], a
        while p <= 0x3FFF:
            d = avg.decode(mem, p)
            if not d:
                break
            sub.append((p, d))
            if d[0] in ("RTSL", "HALT"):
                break
            p += d[2]
        add("V%04X" % a, names[a][0], avg_segments(sub, mem), a)

    def fmt(v):
        return "%g" % round(float(v), 3)

    cards, data = [], []
    for addr, key, label, segs in sorted(entries):
        note = "<br><span class='d'>no lit vectors</span>" if all_dark(segs) else ""
        cards.append("<div class='s'><canvas id='c%s' width='104' height='104'></canvas>"
                     "<br>%s<br>%04X%s</div>" % (key, label, addr, note))
        # Coordinates are fractional once SCAL is applied (SHOT scales its
        # +/-2 deltas to +/-0.996). Truncating with int() collapsed such
        # shapes to zero-length segments and they rendered blank.
        rows = ",".join("[%s,%s,%s,%s,%d]" % (fmt(a), fmt(b), fmt(c), fmt(d),
                                              1 if e else 0)
                        for a, b, c, d, e in segs)
        data.append("S['%s']=[%s];" % (key, rows))

    html = """<!doctype html><meta charset='utf-8'><title>Space Duel vector objects</title>
<style>body{background:#000;color:#0f0;font:12px monospace}
.s{display:inline-block;margin:4px;text-align:center;width:110px;vertical-align:top}
canvas{border:1px solid #333;background:#000}h3{color:#6f6}.d{color:#666;font-size:10px}</style>
<h3>Space Duel vector objects &mdash; %d ship pictures ($2800-$2FFF) + %d AVG shapes ($3000-$3FFF)</h3>
%s
<script>
var S={};
%s
for(var k in S){
  var cv=document.getElementById('c'+k); if(!cv) continue;
  var g=cv.getContext('2d'), sg=S[k];
  var xs=[],ys=[];
  for(var i=0;i<sg.length;i++){ if(!sg[i][4]) continue;
    xs.push(sg[i][0],sg[i][2]);ys.push(sg[i][1],sg[i][3]);}
  if(!xs.length) continue;
  var x0=Math.min.apply(null,xs),x1=Math.max.apply(null,xs);
  var y0=Math.min.apply(null,ys),y1=Math.max.apply(null,ys);
  var w=Math.max(1,x1-x0), h=Math.max(1,y1-y0);
  var sc=Math.min(92/w,92/h);
  g.strokeStyle='#0f0'; g.lineWidth=1; g.beginPath();
  for(var i=0;i<sg.length;i++){
    if(!sg[i][4]) continue;
    var ax=6+(sg[i][0]-x0)*sc, ay=98-(sg[i][1]-y0)*sc;
    var bx=6+(sg[i][2]-x0)*sc, by=98-(sg[i][3]-y0)*sc;
    g.moveTo(ax,ay); g.lineTo(bx,by);
  }
  g.stroke();
}
</script>
""" % (len(shapes.ship_pictures(mem)), len(blks), "\n".join(cards), "\n".join(data))
    open(path, "w").write(html)
    return len(cards)

if __name__ == "__main__":
    mem = image.load()
    blks, names, secondary, gly, desc, tail = shapes.resolve(mem)
    refs = shapes.xrefs(mem)
    # The object listing lives in spaceduel_vector_rom.asm; only the
    # name table and the preview are written here.
    n1 = 0
    n2 = emit_names(mem, blks, names, refs, paths.VEC_NAMES)
    n3 = emit_preview(mem, blks, names, refs, paths.SHAPES_HTML)
    print("(object listing merged into spaceduel_vector_rom.asm)")
    print("vec_names.py          : %d shapes" % n2)
    print("shapes_preview.html   : %d shape canvases" % n3)
