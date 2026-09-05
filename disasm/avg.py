"""Atari Analog Vector Generator (AVG) decoder for the Space Duel vector ROM.

Semantics verified against the real interpreter in
AAE_publish_new_vector_test/aae/aae/vidhrdwr/aae_avg.cpp (and the state-machine
model in mame_late_avgdvg.cpp):

    opcode = word >> 13:
      0 VCTR (2 words)  y=tc13(w1), x=tc13(w2), z=top 3 bits of w2
      1 HALT
      2 SVEC            x=tc5(w)<<1, y=tc5(w>>8)<<1, z=(w>>4)&0xE
      3 STAT, or SCAL when bit 12 is set
      4 CNTR
      5 JSRL  target=(w&0x1FFF)<<1 in vector space  (= CPU $2000 + that)
      6 RTSL
      7 JMPL
    deltas are TWO'S COMPLEMENT (twos_comp_val in aae_avg.cpp) - NOT the
    sign-magnitude convention of the older DVG.
    SCAL: bshift=((w>>8)&7), linear=(~w)&0xFF, scale = (255-lin? no: ~w&0xFF)
          -> scale factor = ((~w)&0xFF)/256 / 2^bshift  (so $7000 ~= full size)
    z==1 in the source's 0-7 encoding means 'use the STAT/COLOR intensity'.
"""
VG_BASE = 0x2000

def s13(v):
    """13-bit TWO'S COMPLEMENT delta, per VGMC.MAC's own VCTR macro
    (.WORD DY&^H1FFF): -510 is stored as $1E02. The AVG is not the DVG -
    sign-magnitude decoding (the Asteroids convention) yields garbage here."""
    v &= 0x1FFF
    return v - 0x2000 if v & 0x1000 else v

def s5(v):
    """5-bit two's complement half-delta used by the short vector."""
    v &= 0x1F
    return v - 0x20 if v & 0x10 else v

def decode(mem, a):
    """Decode one AVG instruction at address a -> (mnemonic, operand, length)."""
    if a + 1 not in mem:
        return None
    w = mem[a] | (mem[a + 1] << 8)
    top = (w >> 12) & 0xF
    if top in (0x0, 0x1):
        if a + 3 not in mem:
            return None
        w2 = mem[a + 2] | (mem[a + 3] << 8)
        dy, dx, z = s13(w), s13(w2), (w2 >> 13) & 7
        return "VCTR", "%d, %d, %d" % (dx, dy, z), 4
    if top == 0x2:
        return "HALT", "", 2
    if top in (0x4, 0x5):
        dx = s5(w & 0x1F) * 2
        dy = s5((w >> 8) & 0x1F) * 2
        z = (w >> 5) & 7
        return "SVEC", "%d, %d, %d" % (dx, dy, z), 2
    if top == 0x6:
        # on the colour hardware the high byte is $64 and the low byte is
        # (luminance<<4)|colour
        if (w >> 8) == 0x64:
            return "COLOR", "$%X, %d" % (w & 0x0F, (w >> 4) & 0x0F), 2
        return "STAT", "$%04X" % w, 2
    if top == 0x7:
        return "SCAL", "%d, $%02X" % ((w >> 8) & 0x0F, w & 0xFF), 2
    if top == 0x8:
        return ("CNTR", "", 2) if w == 0x8040 else ("CNTR", "$%04X" % w, 2)
    if top in (0xA, 0xB):
        return "JSRL", "$%04X" % (VG_BASE + ((w & 0x1FFF) * 2)), 2
    if top in (0xC, 0xD):
        return "RTSL", "", 2
    if top in (0xE, 0xF):
        return "JMPL", "$%04X" % (VG_BASE + ((w & 0x1FFF) * 2)), 2
    return "WORD", "$%04X" % w, 2

def targets(mem, lo, hi):
    """All JSRL/JMPL destinations inside the vector ROM."""
    out, a = set(), lo
    while a <= hi:
        d = decode(mem, a)
        if not d:
            break
        if d[0] in ("JSRL", "JMPL"):
            t = int(d[1][1:], 16)
            if lo <= t <= hi:
                out.add(t)
        a += d[2]
    return out

if __name__ == "__main__":
    import sys, os
    sys.path.insert(0, os.path.dirname(__file__))
    import image
    mem = image.load()
    counts = {}
    a = 0x2800
    while a <= 0x3FFF:
        d = decode(mem, a)
        if not d:
            break
        counts[d[0]] = counts.get(d[0], 0) + 1
        a += d[2]
    print("AVG opcode census over $2800-$3FFF:")
    for k, v in sorted(counts.items(), key=lambda x: -x[1]):
        print("   %-6s %5d" % (k, v))
    print("JSRL/JMPL targets inside vector ROM: %d" % len(targets(mem, 0x2800, 0x3FFF)))
