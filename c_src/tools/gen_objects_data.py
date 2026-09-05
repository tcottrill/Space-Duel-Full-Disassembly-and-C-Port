"""gen_objects_data.py - generate c_src/objects_data.c from the ROM image.

Extracts the const tables used by the object/physics/enemy module
(objects.c, ROM $43B7-$5C7F + $672C-$67AA) from the 64K image
(disasm/build/spacduel_64k.bin, built by disasm/gen_from_roms.py); never
hand-transcribed (CONVENTIONS rule 1c).

Several of these are read through a *base-minus-offset* address that the
6502 forms from a high object index, e.g. `LDA $447A,X` with X = $21..$2F
really reads $449B..$44A9.  The extraction therefore keeps whole
contiguous regions and objects.c indexes them with the ROM's own base
address (see OBJ_DATA_BYTE / the accessor macros in objects.c), so the
odd overlaps the ROM depends on (a size-radius fetch that runs off the
end of one table into the next) are reproduced exactly.

    obj_coll_tab[0x45]      $448B  CollisionDetector_110/_112/_115/_125/_126:
                                   object radii + per-object collision scan
                                   start indices (co-op / competitive).
    obj_owner_tab[0x0F]     $4592  ValueOwnershipNegativeNobody: owner of a
                                   shot/mine object ($4571,X, X = $21..$2F).
    obj_comet_table[0x02]   $472C  CometTable: COMSTART reload per player.
    obj_angleshoot[0x02]    $4B72  AngleShoot: forced super-saucer fire angle.
    obj_saucer_tab[0x12]    $4C5E  StartingValues/StoppingValues (torpedo slot
                                   scan), DifferentSaucerVelocities, Sspos,
                                   Ssminus (saucer entry speeds).
    obj_fire_idx[0x09]      $4D6B  StartingSearchEmptyMine/EndingSearchEmptyMine
                                   /EndingDamaged/L01ZshipZship/Revship - the
                                   ship torpedo-slot windows and ship<->ship
                                   index maps ($4D51,X and $4D69,X reach here).
    obj_clearsaucer[0x02]   $53FB  ClearSaucer_100: saucer object -> saucer #
                                   ($53DC,X, X = $1F/$20).
    obj_entdwarf[0x20]      $5154  EnteringDwarfAmoutns + Entdwtable: comet /
                                   dwarf counts for the onslaught, by level.
    obj_initpos_m1[0x10]    $5967  InitialPositionSpaceDuel, base-1
                                   (`LDA $5967,Y`); [0] = the RTS opcode that
                                   ends L_90 - a CODE byte the base-1 idiom
                                   can reach, taken from the binary as-is.
    obj_wave_tab[0x14]      $5BA5  RockSpeedUpAmount, MinVelocityAddAmount,
                                   DifctyIncreaseBasedDiff, RockSpeedUpEvery,
                                   MimVelocitySpeedUp - per-wave difficulty
                                   ramp, indexed by KLMINC.
    obj_toggles[0x08]       $6CCD  TableInitialValuesToggles + Ttogdrone:
                                   LASTSW / $51 seeds per game type.
    obj_rock_points[0x04]   $6611  SplitRockIntoFragments_110: score value for
                                   the *new* rock size (old size >> 1).  The
                                   listing's .byte run is three bytes; the
                                   fourth ($6614) is the LDA opcode ($A9) of
                                   UpdateHighScoreTable and is reachable only
                                   if an object's size nibble were 6 or 7,
                                   which no spawn path produces (sizes go
                                   4 -> 2 -> 1 -> 0).  Carried from the binary
                                   so the C index can never run out of bounds.
    obj_km_tab[0x36]        $6CD9  SpeedTableGame1/AngleChangeSpeedGame/
                                   SpeedTableSpaceStation/AngleChangeSpeedSpace/
                                   SpeedTableGame0/AngleChangeSpeedGame2 -
                                   killer-mine speed + angle-change ramps.

Every extracted byte that appears on a `.byte` line of the annotated
listing disasm/spaceduel_program_rom.asm (itself byte-verified
against the ROM set) is cross-checked; a mismatch aborts.  Bytes that are
not on a `.byte` line (the base-1 code byte) are reported.

Run from anywhere:  py c_src/tools/gen_objects_data.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))   # project root
CSRC = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(ROOT, "disasm"))
import paths

TABLES = [
    ("obj_coll_tab", 0x448B, 0x45,
     "$448B: CollisionDetector_110/_112/_115/_125/_126 - object radii and "
     "collision-scan start indices"),
    ("obj_owner_tab", 0x4592, 0x0F,
     "ValueOwnershipNegativeNobody ($4592): owner of shot/mine object "
     "$21..$2F ($FF = nobody)"),
    ("obj_comet_table", 0x472C, 0x02,
     "CometTable ($472C): COMSTART reload after 3 hits, per player"),
    ("obj_angleshoot", 0x4B72, 0x02,
     "AngleShoot ($4B72): forced fire angle for a super saucer"),
    ("obj_saucer_tab", 0x4C5E, 0x12,
     "$4C5E: StartingValues(2), StoppingValues(2), "
     "DifferentSaucerVelocities(4), Sspos(5), Ssminus(5)"),
    ("obj_fire_idx", 0x4D6B, 0x09,
     "$4D6B: StartingSearchEmptyMine(2), EndingSearchEmptyMine(2), "
     "EndingDamaged(2), L01ZshipZship(1), Revship(2)"),
    ("obj_clearsaucer", 0x53FB, 0x02,
     "ClearSaucer_100 ($53FB): saucer object $1F/$20 -> saucer number 0/1"),
    ("obj_entdwarf", 0x5154, 0x20,
     "$5154: EnteringDwarfAmoutns(16) + Entdwtable(16) - onslaught comet "
     "and dwarf counts by level"),
    ("obj_initpos_m1", 0x5967, 0x10,
     "InitialPositionSpaceDuel ($5968) base-1: `LDA $5967,Y`; [0] is a code "
     "byte (the RTS ending L_90)"),
    ("obj_wave_tab", 0x5BA5, 0x14,
     "$5BA5: RockSpeedUpAmount(4), MinVelocityAddAmount(4), "
     "DifctyIncreaseBasedDiff(4), RockSpeedUpEvery(4), MimVelocitySpeedUp(4)"),
    ("obj_rock_points", 0x6611, 0x04,
     "SplitRockIntoFragments_110 ($6611): points for the new rock size; [3] "
     "is a code byte (the LDA of UpdateHighScoreTable), unreachable in play"),
    ("obj_toggles", 0x6CCD, 0x08,
     "$6CCD: TableInitialValuesToggles(4) + Ttogdrone(4) - LASTSW and $51 "
     "seeds per game type"),
    ("obj_km_tab", 0x6CD9, 0x36,
     "$6CD9: killer-mine SpeedTableGame1/AngleChangeSpeedGame/"
     "SpeedTableSpaceStation/AngleChangeSpeedSpace/SpeedTableGame0/"
     "AngleChangeSpeedGame2, 9 entries each"),
]


def load_64k():
    return paths.load_image64k()


def listing_bytes():
    """Parse every 'Lxxxx:  .byte ...' line into {addr: value}."""
    path = paths.PROGRAM_ROM
    rx = re.compile(r"^L([0-9A-F]{4}):\s+\.byte\s+(.+?)\s*(?:;.*)?$")
    out = {}
    with open(path, "r") as f:
        for line in f:
            m = rx.match(line)
            if not m:
                continue
            addr = int(m.group(1), 16)
            for i, tok in enumerate(m.group(2).split(",")):
                tok = tok.strip()
                if tok.startswith("$"):
                    out[addr + i] = int(tok[1:], 16)
    return out


def cross_check(img, lst):
    total = 0
    misses = []
    for name, base, size, _ in TABLES:
        for a in range(base, base + size):
            if a not in lst:
                misses.append((name, a))    # code byte reached by base-1 idiom
                continue
            if lst[a] != img[a]:
                raise SystemExit("%s: $%04X listing=$%02X bin=$%02X"
                                 % (name, a, lst[a], img[a]))
            total += 1
    for name, a in misses:
        print("note: %s $%04X not a .byte line (code byte $%02X taken "
              "from binary)" % (name, a, img[a]))
    print("cross-check vs listing .byte lines: %d bytes match, %d code bytes"
          % (total, len(misses)))


def emit(img):
    lines = [
        "/* objects_data.c - Space Duel object/physics/enemy const tables.",
        " * generated by c_src/tools/gen_objects_data.py from the 64K image",
        " * (disasm/build/spacduel_64k.bin), cross-checked byte-for-byte",
        " * against the listing's .byte lines.",
        " * Do not edit - regenerate. Declarations live in objects.h. */",
        "#include <stdint.h>",
        "",
    ]
    for name, base, size, desc in TABLES:
        lines.append("/* %s */" % desc)
        lines.append("const uint8_t %s[0x%02X] = {" % (name, size))
        for off in range(0, size, 16):
            row = ",".join("0x%02X" % b
                           for b in img[base + off:base + min(size, off + 16)])
            lines.append("    /* %04X */ %s," % (base + off, row))
        lines.append("};")
        lines.append("")
    with open(os.path.join(CSRC, "objects_data.c"), "w", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote objects_data.c (%s)" %
          ", ".join("%s[%d] @ $%04X" % (n, s, b) for n, b, s, _ in TABLES))


if __name__ == "__main__":
    image = load_64k()
    cross_check(image, listing_bytes())
    emit(image)
