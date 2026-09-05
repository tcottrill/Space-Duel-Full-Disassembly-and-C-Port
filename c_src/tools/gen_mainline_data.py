"""gen_mainline_data.py - generate c_src/mainline_data.c from the ROM image.

Extracts the const tables of the mainline/boot module from the 64K image
(disasm/build/spacduel_64k.bin, built by disasm/gen_from_roms.py); never
hand-transcribed (CONVENTIONS rule 1c).  The tables:

    mainline_game_order[4]   $43B3  TableGameOrder - Nxtstep's next-game map
    mainline_evkm[6]         $6A9B  EndingValueKillerMine (5 bytes) PLUS the
                             byte at $6AA0: Frame0FrameOff's loop runs X=5..0
                             over 6 killer-mine slots, so the CMP
                             EndingValueKillerMine,X at $69A2 reads one byte
                             past the table (= Kchend[0]) when X=5.
    mainline_kchend[6]       $6AA0  Kchend (5 bytes) PLUS the byte at $6AA5:
                             same X=5 overflow at $69AF; $6AA5 is the LDX
                             opcode ($A2) of SinceCannotGetMust - a CODE
                             byte, so it is bin-only (no .byte cross-check).
    mainline_comentable[2]   $6ACF  Comentable - InitializeComet/Inco10's
                             lowest object slot to scan, per player (0/1).
    mainline_comet_ramp[12]  $6D0F  NewCometAngleChange(4) + NewCometTopSpeed(4)
                             + FirstCometSTop(4), contiguous; SinceCannotGetMust
                             indexes all three with Y = KLMINC (0-3), so they
                             are carried as one region addressed by ROM base.
    mainline_ttplayr[4]      $6CD5  Ttplayr - credits required per game
    mainline_bonus_optn[4]   $7724  BonusOptionSwitchesAssumed - bonus level
    mainline_fighters[8]     $7728  Fighters (4) + SpaceStation (4): Gtoptn
                             indexes the pair as one 8-entry table (X 0-7,
                             +4 when the game-select bit says space station)
    mainline_ininitls[15]    $802D  Ininitls - default high-score initials
                             codes (SetUpInitialsHigh reads X = 0-$0E)

Every strict byte is cross-checked against the .byte lines of the annotated
listing disasm/spaceduel_program_rom.asm (itself byte-verified
against the ROM set); any disagreement aborts.

Run from anywhere:  py c_src/tools/gen_mainline_data.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))   # project root
CSRC = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(ROOT, "disasm"))
import paths

# (name, base, size, strict, comment)
TABLES = [
    ("mainline_game_order", 0x43B3, 4, True,
     "TableGameOrder ($43B3): Nxtstep's game-select rotation"),
    ("mainline_evkm", 0x6A9B, 6, True,
     "EndingValueKillerMine ($6A9B) + $6AA0 overflow byte (X=5 read)"),
    ("mainline_kchend", 0x6AA0, 6, False,
     "Kchend ($6AA0) + $6AA5 overflow byte (X=5 read; $6AA5 is code)"),
    ("mainline_comentable", 0x6ACF, 2, True,
     "Comentable ($6ACF): Inco10's lowest comet slot to scan, per player"),
    ("mainline_ttplayr", 0x6CD5, 4, True,
     "Ttplayr ($6CD5): credits required per game type"),
    ("mainline_comet_ramp", 0x6D0F, 12, True,
     "$6D0F: NewCometAngleChange(4) + NewCometTopSpeed(4) + FirstCometSTop(4)"
     " - SinceCannotGetMust's per-difficulty ramp, indexed by KLMINC"),
    ("mainline_bonus_optn", 0x7724, 4, True,
     "BonusOptionSwitchesAssumed ($7724): bonus-life level per DIP pair"),
    ("mainline_fighters", 0x7728, 8, True,
     "Fighters ($7728) + SpaceStation ($772C): Gtoptn difficulty, X=0-7"),
    ("mainline_ininitls", 0x802D, 15, True,
     "Ininitls ($802D): default high-score initials, X=0-$0E"),
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
    total = checked = 0
    for name, base, size, strict, _ in TABLES:
        for a in range(base, base + size):
            total += 1
            if a not in lst:
                if strict:
                    raise SystemExit("%s: $%04X is not a .byte line in the "
                                     "listing" % (name, a))
                continue                      # code byte: bin is the truth
            if lst[a] != img[a]:
                raise SystemExit("%s: $%04X listing=$%02X bin=$%02X"
                                 % (name, a, lst[a], img[a]))
            checked += 1
    print("cross-check vs listing .byte lines: %d/%d bytes match"
          % (checked, total))


def emit(img):
    lines = [
        "/* mainline_data.c - Space Duel mainline/boot const tables.",
        " * generated by c_src/tools/gen_mainline_data.py from the 64K image",
        " * (disasm/build/spacduel_64k.bin), cross-checked against the",
        " * listing's .byte lines. Do not edit - regenerate. Declarations",
        " * in mainline.h. */",
        "#include <stdint.h>",
        "",
    ]
    for name, base, size, _, desc in TABLES:
        lines.append("/* %s */" % desc)
        row = ",".join("0x%02X" % b for b in img[base:base + size])
        lines.append("const uint8_t %s[0x%02X] = {" % (name, size))
        lines.append("    /* %04X */ %s," % (base, row))
        lines.append("};")
        lines.append("")
    with open(os.path.join(CSRC, "mainline_data.c"), "w", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote mainline_data.c (%s)" %
          ", ".join("%s[%d] @ $%04X" % (n, s, b)
                    for n, b, s, _, _ in TABLES))


if __name__ == "__main__":
    img = load_64k()
    cross_check(img, listing_bytes())
    emit(img)
