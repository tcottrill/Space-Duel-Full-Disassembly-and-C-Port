"""gen_selftest_data.py - generate c_src/selftest_data.c from the ROM image.

Extracts the const tables of the self-test module (AS2TST: power-on
diagnostics $8110-$8636, bookkeeping screen $89B1-$8C61, message
placement $8CEF-$8D32, signature analysis $8DC0-$8E41) from the 64K
image (disasm/build/spacduel_64k.bin, built by disasm/gen_from_roms.py);
never hand-transcribed (CONVENTIONS rule 1c).

    selftest_sftjsr[12]     $861A  Sftjsr - RTS jump table of the six diagnostic
                                   screens (lo/hi pairs, target = word+1);
                                   the listing disassembles these bytes as
                                   instructions, so they are bin-only
    selftest_sndsel[18]     $83B8  the byte before SoundTableLo (Stest8 reads
                                   $83B8,X = the PREVIOUS channel's offset) +
                                   SoundTableLo(9) + Sndfrq(8), contiguous:
                                   [x] = previous, [1+x] = offset, [10+x] = freq
    selftest_dollar[4]      $8409  DollarMechMultipliers
    selftest_posbars[7]     $840D  PositionBars (color-bar X positions)
    selftest_position[7]    $8414  Position (color-bar Y positions)
    selftest_badnws[4]      $841B  Badnws - glyph offsets R/P/P/E for ERPLC
    selftest_hlpos[8]       $846F  Hlpos - crosshatch horizontal lines
    selftest_vlpos[12]      $8477  Vlpos - crosshatch vertical lines
    selftest_avgidx[4]      $89B1  CalculateAverageGameTime - $01A6 offsets
    selftest_timix[4]       $89B5  Timix - EACS offsets, per game
    selftest_dosel[8]       $8C9E  DoSelfTest - OptionSelected's RTS table
    selftest_bonus_disp[8]  $8C38  BonusAddresTableDisplay
    selftest_fs_ypos[6]     $8C40  PositionsFightersSpaceStation(3) + Y2pos(3)
    selftest_tipos[8]       $8C46  Tiposx(4) + Tiposy(4)
    selftest_gmpos[8]       $8C4E  Gmposx(4) + Gmposy(4)
    selftest_avpos[8]       $8C56  Avposx(4) + Avposy(4)
    selftest_langlt[4]      $8C5E  Langlt - language letter glyph index
    selftest_msg_x[17]      $8CEF  L0Normal0fMedium - message X positions
    selftest_msg_y[17]      $8D00  Y3pos - message Y positions
    selftest_msg_color[17]  $8D11  MessageColor
    selftest_msg_num[17]    $8D22  MessageNumberRealMessage

Every strict byte is cross-checked against the .byte lines of the annotated
listing disasm/spaceduel_program_rom.asm (itself byte-verified
against the ROM set); any disagreement aborts.  The signature-analysis
tables ($8DC0/$8DC8/$8DD0) are NOT extracted: the ROM indexes them with a
value that can overrun the table, so selftest.c reads them through the
full program image (sd_progrom.c) instead.

Run from anywhere:  py c_src/tools/gen_selftest_data.py
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
    ("selftest_sftjsr", 0x861A, 12, False,
     "Sftjsr ($861A): RTS jump table of the diagnostic screens, X = the screen number at $A0"
     " (code bytes in the listing: bin-only)"),
    ("selftest_sndsel", 0x83B8, 18, True,
     "$83B8 (previous-channel byte) + SoundTableLo $83B9 (9) + Sndfrq $83C2 (8)"),
    ("selftest_dollar", 0x8409, 4, True,
     "DollarMechMultipliers ($8409)"),
    ("selftest_posbars", 0x840D, 7, True,
     "PositionBars ($840D): color-bar X"),
    ("selftest_position", 0x8414, 7, True,
     "Position ($8414): color-bar Y"),
    ("selftest_badnws", 0x841B, 4, True,
     "Badnws ($841B): error-letter glyph offsets, X = ERPLC index"),
    ("selftest_hlpos", 0x846F, 8, True,
     "Hlpos ($846F): crosshatch horizontal line Y"),
    ("selftest_vlpos", 0x8477, 12, True,
     "Vlpos ($8477): crosshatch vertical line X"),
    ("selftest_avgidx", 0x89B1, 4, True,
     "CalculateAverageGameTime ($89B1): $01A6 offsets per game"),
    ("selftest_timix", 0x89B5, 4, True,
     "Timix ($89B5): EACS offsets per game"),
    ("selftest_dosel", 0x8C9E, 8, True,
     "DoSelfTest ($8C9E): OptionSelected's RTS table (target = word+1)"),
    ("selftest_bonus_disp", 0x8C38, 8, True,
     "BonusAddresTableDisplay ($8C38)"),
    ("selftest_fs_ypos", 0x8C40, 6, True,
     "PositionsFightersSpaceStation ($8C40, 3) + Y2pos ($8C43, 3)"),
    ("selftest_tipos", 0x8C46, 8, True,
     "Tiposx ($8C46, 4) + Tiposy ($8C4A, 4)"),
    ("selftest_gmpos", 0x8C4E, 8, True,
     "Gmposx ($8C4E, 4) + Gmposy ($8C52, 4)"),
    ("selftest_avpos", 0x8C56, 8, True,
     "Avposx ($8C56, 4) + Avposy ($8C5A, 4)"),
    ("selftest_langlt", 0x8C5E, 4, True,
     "Langlt ($8C5E): language letter glyph index"),
    ("selftest_msg_x", 0x8CEF, 17, True,
     "L0Normal0fMedium ($8CEF): message X, index = CorrectMessageAndColor Y"),
    ("selftest_msg_y", 0x8D00, 17, True,
     "Y3pos ($8D00): message Y"),
    ("selftest_msg_color", 0x8D11, 17, True,
     "MessageColor ($8D11)"),
    ("selftest_msg_num", 0x8D22, 17, True,
     "MessageNumberRealMessage ($8D22): AS2MSG message number"),
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
    # the RTS table's targets, as documentation of what OBJ selects
    t = img[0x861A:0x861A + 12]
    names = ["Stest5", "Cocktail", "Stest7", "Stest8", "SetScale1", "Stst10"]
    for i in range(6):
        tgt = (t[2 * i] | (t[2 * i + 1] << 8)) + 1
        print("  Sftjsr screen $A0=$%02X -> $%04X %s" % (2 * i, tgt, names[i]))


def emit(img):
    lines = [
        "/* selftest_data.c - Space Duel self-test (AS2TST) const tables.",
        " * generated by c_src/tools/gen_selftest_data.py from the 64K image",
        " * (disasm/build/spacduel_64k.bin), cross-checked against the",
        " * listing's .byte lines. Do not edit - regenerate. Declarations",
        " * in selftest.h. */",
        "#include <stdint.h>",
        "",
    ]
    for name, base, size, _, desc in TABLES:
        lines.append("/* %s */" % desc)
        lines.append("const uint8_t %s[0x%02X] = {" % (name, size))
        for off in range(0, size, 16):
            row = ",".join("0x%02X" % b for b in img[base + off:base + min(size, off + 16)])
            lines.append("    /* %04X */ %s," % (base + off, row))
        lines.append("};")
        lines.append("")
    with open(os.path.join(CSRC, "selftest_data.c"), "w", newline="\n") as f:
        f.write("\n".join(lines))
    print("wrote selftest_data.c (%s)" %
          ", ".join("%s[%d] @ $%04X" % (n, s, b)
                    for n, b, s, _, _ in TABLES))


if __name__ == "__main__":
    img = load_64k()
    cross_check(img, listing_bytes())
    emit(img)
