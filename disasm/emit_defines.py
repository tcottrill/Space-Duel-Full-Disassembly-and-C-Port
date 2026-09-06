"""Emit spaceduel_defines.asm - hardware map and RAM variables, Ophis .alias form."""
import sys, os, re
sys.path.insert(0, os.path.dirname(__file__))
import paths
import rammap, emit as emitmod, var_docs

HARDWARE = [
    ("Memory map", [
        ("ZeroPageRam",  0x0000, "Through $00FF."),
        ("StackRam",     0x0100, "Through $01FF. The stack lives here."),
        ("GameRam",      0x0200, "Through $03FF. 1K of MCU RAM in total."),
        ("VectorRam",    0x2000, "Through $27FF. 2K of vector RAM."),
        ("VectorRom",    0x2800, "Through $3FFF. 6K of vector ROM."),
        ("ProgramRom",   0x4000, "Through $8FFF, mirrored to $FFFF."),
    ]),
    ("Inputs", [
        ("In0",          0x0800, "d7 3kHz clock, d6 VG HALT, d5 diag step,"),
        ("SelfTestSw",   0x0800, "  d4 self-test (0=on), d3 slam, d2-d0 coins."),
        ("VgHalt",       0x0800, "d6 = 1 when the AVG has finished its list."),
        ("ThreeKhz",     0x0800, "d7 = 3kHz frame timebase."),
        ("In1",          0x0900, "Through $0907. Controls, one switch per address."),
        ("EaromRead",    0x0A00, "EAROM data read."),
    ]),
    ("Outputs", [
        ("CoinCtrLamps", 0x0C00, "Coin counters, start lamps, cabinet flip."),
        ("VgGo",         0x0C80, "Write starts the AVG on the display list."),
        ("WdClear",      0x0D00, "Write kicks the watchdog."),
        ("VgReset",      0x0D80, "Write holds the AVG in reset."),
        ("IrqAck",       0x0E00, "Write acknowledges the IRQ."),
        ("EaromControl", 0x0E80, "EAROM control latch."),
        ("EaromWrite",   0x0F00, "Through $0F3F. EAROM write."),
        ("Pokey1",       0x1000, "POKEY 1 - sound and pot inputs."),
        ("Pokey2",       0x1400, "POKEY 2 - sound and option switches."),
    ]),
]

def emit(path=None):
    path = path or paths.DEFINES
    vars_, syms = rammap.build()
    symtab = emitmod.clean_symbols(vars_)      # addr -> unique name

    out = [
        ";Space Duel (Atari, 1982) - hardware map and RAM variables.",
        ";Names in the 'Hardware' sections are descriptive; the RAM variable names",
        ";below are Atari's own identifiers, recovered from the .BLKB declarations",
        ";in ASTRD2.MAC and the equates in AS2DEC.MAC (Atari's source archive).",
        ";Note DEC MACRO-65 symbols are significant to 6 characters only, so a few",
        ";arrive truncated: CMSBSE is CMSBSET, PL0ARE is PL0AREA.",
        ";",
        ";Descriptions come from Atari's own comments on those declarations, plus",
        ";the sound channel arrays in AS2POK.MAC and the coin variables shared with",
        ";COIN65.MAC; see var_docs.py, which is where they are edited.",
        ";",
        ";An address is named after whichever symbol resolves to it, and Atari's",
        ";sources define constants whose value happens to equal a low RAM address.",
        ";Where such a constant outranks the variable that really lives there, the",
        ";comment opens with the cell's true identity, as in 'VGLIST+1 - ...'.",
        "",
    ]
    reserved = {n for _t, rws in HARDWARE for n, _a, _c in rws}
    emitted = []                                # (name, documented) per RAM alias
    for title, rows in HARDWARE:
        out.append(";%s" % ("-" * 34) + "[ %s ]" % title + "-" * 34)
        for name, addr, note in rows:
            out.append(".alias %-16s $%04X    ;%s" % (name, addr, note))
        out.append("")

    # Every symbol the disassembly can reference must be defined here, or an
    # assembler will (rightly) reject the file. Cover the whole address space
    # below the program ROM, not just the RAM ranges.
    groups = [("Zero page variables",   0x0000, 0x00FF),
              ("Stack page",            0x0100, 0x01FF),
              ("Game RAM",              0x0200, 0x03FF),
              ("Hardware registers",    0x0400, 0x1FFF),
              ("Vector RAM",            0x2000, 0x27FF),
              ("Vector ROM",            0x2800, 0x3FFF)]
    for title, lo, hi in groups:
        rows = [(a, n) for a, n in sorted(symtab.items()) if lo <= a <= hi
                and n not in reserved]
        if not rows:
            continue
        reserved.update(n for _, n in rows)
        out.append(";%s" % ("-" * 34) + "[ %s ]" % title + "-" * 34)
        for a, n in rows:
            w = 2 if a < 0x100 else 4
            text, _collides = var_docs.lookup(n, a)
            emitted.append((n, bool(text)))
            line = ".alias %-16s $%0*X" % (n, w, a)
            if text:
                line = "%-32s ;%s" % (line, text)
            out.append(line)
        out.append("")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write("\n".join(out) + "\n")
    n = sum(1 for l in out if l.startswith(".alias"))
    return n, sum(1 for _nm, ok in emitted if ok), len(emitted)

if __name__ == "__main__":
    n, have, total = emit()
    print("wrote %s  (%d aliases, %d of %d RAM/vector names documented)"
          % (os.path.relpath(paths.DEFINES, paths.ROOT), n, have, total))
