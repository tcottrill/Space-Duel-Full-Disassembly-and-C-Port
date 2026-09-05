"""Ship pictures ($2800-$2FFF) drawn exactly as the hardware draws them.

Authority: SHPDISPLAYS in ASTRD2.MAC (lines 6109-6190) and its tables:
    SHADOF:     .BYTE 0,34.     ; type B pictures start at table entry 17
    SHPD1TAB:   .BYTE 5B,53     ; output-buffer offset of picture end
                                ;   ($5B+1)/4 = 23 records, ($53+1)/4 = 21
    SHPD2TABLE: .BYTE 16,14     ; whole-ship record count - 1  (22 -> 23, 20 -> 21)
    SHPD3TABLE: .BYTE 1A,18     ; with-thrust record count - 1 (26 -> 27, 24 -> 25)
    SHPD4TABLE: .BYTE 7,6       ; damage spot: COLOR black inserted here when hit
    SHPLUM=020                  ; z=1 on every emitted vector -> statz intensity

Every record is emitted as a lit VCTR (z=1); the caller sets COLOR (lum $D)
first, so the whole picture draws in the ship's colour. Records past the
whole-ship count up to the thrust count are the flame, drawn WHITE (CLRTHR
inserts COLOR $F7 when TEMPA wraps to $FE) and only while thrusting.

The BB (brightness) and EE (end) arguments of the source's TWBYPIC records are
VESTIGIAL: the active macro is plain `.BYTE YY,XX` and discards both, and the
runtime uses the fixed counts above. An earlier version of this tool treated
BB=0 as pen-up and stopped at EE - both wrong: it first overdrew (reading the
54-byte pointer stride into padding), then underdrew (stopping at record 16).
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import image

SHIP_PTRS, SHIP_COUNT = 0x2800, 34
TYPE_SPLIT = 17            # SHADOF: entries 0-16 = type A (SHPA*), 17-33 = type B
WHOLE = {0: 23, 1: 21}     # SHPD2TABLE + 1
THRUST = {0: 27, 1: 25}    # SHPD3TABLE + 1
DAMAGE_SPOT = {0: 7, 1: 6} # SHPD4TABLE

def s8(v):
    return v - 256 if v > 127 else v

def pictures(mem):
    """[(name, addr, type, [(dx,dy)]*thrust_count)] straight from the ROM."""
    import vecmap
    out = []
    for i, (name, addr) in enumerate(vecmap.ship_table(mem)):
        t = 0 if i < TYPE_SPLIT else 1
        recs = []
        for k in range(THRUST[t]):
            a = addr + 2 * k
            recs.append((s8(mem[a + 1]), s8(mem[a])))      # .BYTE YY,XX
        out.append((name, addr, t, recs))
    return out

def shapes_with_brightness(mem):
    """Whole-ship records with the blanking the SHPDI8 epilogue applies:
    after the emit loop writes every record lit, the 'codicil' (ASTRD2.MAC
    6229-6257) ANDs #$1F over the z bits of the FIRST record (the centre-to-
    hull offset - 'BLANK OUT THE FIRST VECTOR') and of the LAST emitted
    record (the return leg). With thrust on it also blanks the two bridge
    records before the flame (SHPD1TAB gives their output offsets)."""
    out = []
    for name, addr, t, recs in pictures(mem):
        n = WHOLE[t]
        pts = [(dx, dy, 0 < i < n - 1) for i, (dx, dy) in enumerate(recs[:n])]
        out.append((name, addr, pts, True))
    return out

if __name__ == "__main__":
    mem = image.load()
    pics = pictures(mem)
    print("pictures: %d  (type A: %d x 23+4 records, type B: %d x 21+4)"
          % (len(pics), TYPE_SPLIT, len(pics) - TYPE_SPLIT))
    for name, addr, t, recs in pics[:2] + pics[17:19]:
        whole = recs[:WHOLE[t]]
        closed = (sum(r[0] for r in whole[1:]), sum(r[1] for r in whole[1:]))
        print("  %-8s $%04X type %s  whole=%d thrust+%d  outline closure=%s"
              % (name, addr, "AB"[t], WHOLE[t], THRUST[t]-WHOLE[t], closed))
