"""Translate the emitted Ophis disassembly into ca65 syntax.

This exists so the disassembly can be checked with a real third-party
assembler (cc65's ca65 + ld65), independently of my own encoder. Only the
syntax differs; the instruction text is passed through untouched.
"""
import sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
import paths

def convert(src, dst, org=0x4000):
    out = [".setcpu \"6502\"", ".segment \"CODE\"", ""]
    for ln in open(src):
        s = ln.rstrip("\n")
        t = s.strip()
        if t.startswith(";") or not t:
            out.append(s)
            continue
        if t.startswith(".org"):
            continue                      # ld65 places the segment instead
        if t.startswith(".include"):
            continue                      # equates are inlined below
        if t.startswith(".alias"):
            m = re.match(r"\.alias\s+(\S+)\s+(\S+)", t)
            if m:
                out.append("%s = %s" % (m.group(1), m.group(2)))
            continue
        out.append(s)
    open(dst, "w").write("\n".join(out) + "\n")
    return len(out)

def defines_to_ca65(src, dst):
    out = []
    for ln in open(src):
        t = ln.strip()
        m = re.match(r"\.alias\s+(\S+)\s+(\S+)", t)
        if m:
            out.append("%s = %s" % (m.group(1), m.group(2)))
        elif t.startswith(";"):
            out.append(t)
    open(dst, "w").write("\n".join(out) + "\n")
    return len(out)

if __name__ == "__main__":
    os.makedirs(paths.BUILD, exist_ok=True)
    defines_inc = os.path.join(paths.BUILD, "defines_ca65.inc")
    program_s = os.path.join(paths.BUILD, "program_ca65.s")
    n1 = defines_to_ca65(paths.DEFINES, defines_inc)
    n2 = convert(paths.PROGRAM_ROM, program_s)
    # prepend the equates so ca65 sees them first
    body = open(program_s).read()
    eq = open(defines_inc).read()
    head = body.split("\n")
    open(program_s, "w").write(
        "\n".join(head[:3]) + "\n" + eq + "\n" + "\n".join(head[3:]))
    print("defines lines: %d, program lines: %d" % (n1, n2))
