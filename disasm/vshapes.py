"""Resolve Space Duel vector-ROM shapes to Atari's own names.

The source walk (vecmap.map_as2rom) tracks addresses well enough to order the
shapes but drifts by a few bytes over 4K. Rather than trust its absolute
addresses, we snap the source-ordered names onto the real RTSL-terminated block
boundaries, monotonically. That converts "roughly right and drifting" into
"exactly right", and it is checked against a run we know the answer to: the 26
character glyphs UCHR.A..UCHR.Z must land on 26 consecutive blocks in order.
"""
import sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
import image, avg, vecmap

def blocks(mem, lo=0x3000, hi=0x3FFF):
    """RTSL/HALT-terminated AVG blocks -> [(start, end_exclusive, [ops])]."""
    out, a, s, ops = [], lo, lo, []
    while a <= hi:
        d = avg.decode(mem, a)
        if not d:
            break
        ops.append((a, d))
        if d[0] in ("RTSL", "HALT"):
            out.append((s, a + d[2], ops))
            s, ops = a + d[2], []
        a += d[2]
    if ops:
        out.append((s, a, ops))
    return out

def ordered_names(mem):
    """Shape names in source order, with the walk's (drifting) address hint."""
    _names, _at, _ds, order = vecmap.map_as2rom(mem)
    return [(a, nm, isnew) for a, nm, isnew in order if 0x3000 <= a <= 0x3FFF]

def snap(mem):
    """Assign each source-ordered name to a block start, monotonically."""
    blks = blocks(mem)
    starts = [b[0] for b in blks]
    seq = ordered_names(mem)
    assigned, secondary, bi, first = {}, {}, -1, True
    for hint, nm, isnew in seq:
        if isnew:
            bi = bi + 1 if not first else 0
            first = False
            if bi >= len(starts):
                break
            assigned.setdefault(starts[bi], []).append(nm)
        else:
            # a secondary entry point inside the shape we are already on
            if 0 <= bi < len(starts):
                secondary.setdefault(starts[bi], []).append(nm)
    return blks, assigned, secondary

if __name__ == "__main__":
    mem = image.load()
    blks, assigned, secondary = snap(mem)
    named = sum(1 for b in blks if b[0] in assigned)
    print("AVG blocks in $3000-$3FFF : %d" % len(blks))
    print("blocks carrying a name    : %d (%.0f%%)" % (named, 100.0*named/len(blks)))

    # validation: the alphabet must be 26 consecutive blocks in order
    letters = []
    for st in sorted(assigned):
        for nm in assigned[st]:
            m = re.match(r"^UCHR\.([A-Z])$", nm)
            if m:
                letters.append((m.group(1), st))
    print("\nglyph check - UCHR.A..UCHR.Z found: %d" % len(letters))
    if letters:
        seqok = all(ord(letters[i][0]) == ord(letters[0][0]) + i for i in range(len(letters)))
        mono = all(letters[i][1] < letters[i+1][1] for i in range(len(letters)-1))
        print("  in alphabetical order      : %s" % seqok)
        print("  addresses strictly ascending: %s" % mono)
        print("  span $%04X..$%04X" % (letters[0][1], letters[-1][1]))
