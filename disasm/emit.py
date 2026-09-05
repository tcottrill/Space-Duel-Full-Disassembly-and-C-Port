"""Emit the annotated Space Duel program ROM in Ophis syntax.

Every line is byte-verified: an instruction is written from the source mapping
only when re-encoding it reproduces the ROM bytes exactly. Anything unproven
falls back to a plain traced disassembly, and anything not code becomes data.
"""
import sys, os, re, collections
sys.path.insert(0, os.path.dirname(__file__))
import paths
import m6502, image, trace, encode, macsrc, mapper, build_map, rammap, naming
from m6502 import (IMP,ACC,IMM,ZP,ZPX,ZPY,ABS,ABX,ABY,IND,IZX,IZY,REL)

BAD_SYM = re.compile(r"^\.|\$$|^\.\.|^\$")

def clean_symbols(vars_):
    """Drop macro temporaries and pick one preferred name per address."""
    by_addr = {}
    for name, a in vars_.items():
        if BAD_SYM.match(name) or name.startswith("..") or "$" in name:
            continue
        if not re.match(r"^[A-Za-z][A-Za-z0-9_]*$", name):
            continue
        cur = by_addr.get(a)
        if cur is None or (len(name), name) < (len(cur), cur):
            by_addr[a] = name
    # Names must be unique: the verifier inverts this map, and two addresses
    # sharing a name would collapse into one.
    seen = {}
    for a in sorted(by_addr):
        n = by_addr[a]
        if n in seen:
            by_addr[a] = "%s_%04X" % (n, a)
        seen[by_addr[a]] = a
    return by_addr

def render_operand(mn, mode, val, labels, syms):
    def sym(a, hexw=4):
        if a in labels:
            return labels[a]
        if a in syms:
            return syms[a]
        return ("$%02X" if hexw == 2 else "$%04X") % a
    if mode in (IMP, ACC):
        return ""
    if mode == IMM:
        return "#$%02X" % val
    if mode == REL:
        return labels.get(val, "$%04X" % val)
    if mode == ABS:
        return sym(val)
    if mode == ZP:
        return sym(val, 2)
    if mode == ZPX:
        return sym(val, 2) + ",X"
    if mode == ZPY:
        return sym(val, 2) + ",Y"
    if mode == ABX:
        return sym(val) + ",X"
    if mode == ABY:
        return sym(val) + ",Y"
    if mode == IND:
        return "(" + sym(val) + ")"
    if mode == IZX:
        return "(" + sym(val, 2) + ",X)"
    if mode == IZY:
        return "(" + sym(val, 2) + "),Y"
    return "$%04X" % val


def collect(srcdir=None):
    """Assemble everything the emitter needs: ROM, trace, source map, symbols."""
    srcdir = paths.archive_dir(srcdir)
    mem, src, out, info = build_map.build(srcdir)
    t = trace.default_trace(mem)

    # line -> source line object, plus address -> (module, line)
    at_addr = {}
    for fn, amap in out.items():
        for n, a in amap.items():
            at_addr.setdefault(a, []).append((fn, n))

    vars_, syms = rammap.build(srcdir)
    symtab = clean_symbols(vars_)
    desc = naming.build(srcdir)
    return mem, src, out, info, t, at_addr, symtab, desc


def verified_insn(mem, src, at_addr, a):
    """If a mapped source line claims address a and its bytes check out,
    return (module, line, decoded). Otherwise None."""
    for fn, n in at_addr.get(a, []):
        l = src[fn][n - 1]
        if l.kind != "insn":
            continue
        d = m6502.decode(mem, a)
        if d and d[0] == l.op.upper() and encode.verify(mem, a, d[0], d[1], d[2]):
            return fn, n, d
    return None


def build_labels(mem, t, src, out, info, desc):
    """Name every address that is branched to, called, or labelled in the source.

    Globals are named first so that a local label ("10$") can be scoped to the
    routine that contains it, e.g. DestructionDuringCollision_10.
    """
    targets = set(t.xrefs) | {v for v in image.vectors(mem).values()}
    targets = {a for a in targets if image.CODE_LO <= a <= image.CODE_HI}

    # addr -> (module, name, is_global, scope, line); first definition wins
    at = {}
    for fn in info:
        for a, lst in (info[fn].get("label_at") or {}).items():
            if not (image.CODE_LO <= a <= image.CODE_HI):
                continue
            for rec in lst:
                name, isg, scope, line = rec
                if a not in at or (isg and not at[a][2]):
                    at[a] = (fn, name, isg, scope, line)

    labels, used, scope_name = {}, {}, {}
    # pass 1: global labels
    for a in sorted(at):
        fn, name, isg, scope, line = at[a]
        if not isg:
            continue
        prose = naming.harvest(src[fn], line)
        labels[a] = naming.name_for(name, True, None, desc, prose, used)
        scope_name[(fn, name)] = labels[a]
    # pass 2: local labels, scoped to their enclosing routine
    for a in sorted(at):
        fn, name, isg, scope, line = at[a]
        if isg:
            continue
        labels[a] = naming.name_for(name, False, scope_name.get((fn, scope)), desc, None, used)
    # pass 3: anything only the tracer found
    for a in sorted(targets):
        labels.setdefault(a, "L%04X" % a)

    seen = {}
    for a in sorted(labels):
        n = labels[a]
        if n in seen:
            labels[a] = "%s_%04X" % (n, a)
        seen[labels[a]] = a
    return labels, at


def source_comment(l):
    c = (l.comment or "").strip()
    return c


def emit_program(path=None, srcdir=None):
    path = path or paths.PROGRAM_ROM
    mem, src, out, info, t, at_addr, symtab, desc = collect(srcdir)
    labels, atari_at = build_labels(mem, t, src, out, info, desc)

    lo, hi = image.CODE_LO, image.CODE_HI
    body, a = [], lo
    stats = collections.Counter()
    pending = []

    def flush_data():
        if not pending:
            return
        start = pending[0][0]
        vals = [v for _, v in pending]
        for i in range(0, len(vals), 8):
            chunk = vals[i:i+8]
            addr = start + i
            body.append("L%04X:  .byte %s" % (addr, ", ".join("$%02X" % v for v in chunk)))
        pending.clear()

    while a <= hi:
        v = verified_insn(mem, src, at_addr, a)
        d = t.instr.get(a) or (m6502.decode(mem, a) if v else None)
        if v:
            fn, n, d = v
            stats["from_source"] += 1
        elif a in t.starts:
            d = t.instr[a]
            fn = n = None
            stats["from_trace"] += 1
        else:
            # A label can point into a data table; it must be defined there or
            # operands referring to it will not resolve.
            if a in labels and labels[a] != "L%04X" % a:
                flush_data()
                body.append("")
                body.append("%s:" % labels[a])
            pending.append((a, mem[a]))
            stats["data"] += 1
            a += 1
            continue

        flush_data()
        if a in labels and labels[a] != "L%04X" % a:
            body.append("")
            body.append("%s:" % labels[a])
        mn, mode, val, ln = d
        oper = render_operand(mn, mode, val, labels, symtab)
        cmt = source_comment(src[fn][n-1]) if fn else ""
        zp_equiv = {ABS: ZP, ABX: ZPX, ABY: ZPY}.get(mode)
        if zp_equiv is not None and val < 0x100 and zp_equiv in m6502.TAB[mn]:
            # The ROM uses the 3-byte absolute form for an address that would
            # fit in zero page. This is NOT interchangeable: zp,X wraps inside
            # page zero whereas abs,X does not. Assemblers pick the short form,
            # so emit the bytes directly to keep the encoding exact.
            raw = ", ".join("$%02X" % mem[a + i] for i in range(ln))
            note = "%s %s (forced absolute)" % (mn, oper)
            body.append("L%04X:  .byte %-16s ;%s%s"
                        % (a, raw, note, " - " + cmt if cmt else ""))
            stats["forced_abs"] += 1
            a += ln
            continue
        text = "L%04X:  %-4s %-22s" % (a, mn, oper)
        body.append((text + (" ;" + cmt if cmt else "")).rstrip())
        a += ln
    flush_data()

    hdr = [
        ";Space Duel (Atari, 1982) - annotated disassembly of the program ROMs.",
        ";Reconstructed against the MAME 'spacduel' set (rev 2) and cross-checked line",
        ";by line against Atari's own source archive (project 'ASTERIODS 2').",
        ";Every instruction below was re-encoded and byte-compared with the ROM.",
        ";Assembles with Ophis; disasm/gen_from_roms.py --check round-trips it with ca65.",
        "",
        ".org $%04X" % lo,
        "",
        '.include "spaceduel_defines.asm"',
        "",
    ]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(hdr + body) + "\n")
    return stats, len(body), labels


if __name__ == "__main__":
    stats, nlines, labels = emit_program()
    print("wrote", os.path.relpath(paths.PROGRAM_ROM, paths.ROOT))
    print("  instructions from Atari source : %d" % stats["from_source"])
    print("  instructions from trace only   : %d" % stats["from_trace"])
    print("  data bytes                     : %d" % stats["data"])
    print("  labels                         : %d" % len(labels))
    print("  output lines                   : %d" % nlines)
