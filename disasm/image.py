"""Authoritative Space Duel memory image, built from the ROM set (paths.py)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths

ROMS = paths.ROMS
CODE_LO, CODE_HI = paths.CODE_LO, paths.CODE_HI
VROM_LO, VROM_HI = paths.VROM_LO, paths.VROM_HI

def load():
    """Return {addr: byte} for $2800-$8FFF."""
    return paths.load_roms()

def lda(path):
    """Parse an RT-11 absolute loader (.LDA) image -> {addr: byte}."""
    with open(path, "rb") as f:
        d = f.read()
    mem, i = {}, 0
    while i < len(d) - 1:
        if d[i] != 1 or d[i + 1] != 0:
            i += 1
            continue
        if i + 6 > len(d):
            break
        ln = d[i + 2] | (d[i + 3] << 8)
        addr = d[i + 4] | (d[i + 5] << 8)
        if ln < 6 or i + ln + 1 > len(d):
            i += 1
            continue
        for k, b in enumerate(d[i + 6:i + 6 + ln - 6]):
            mem[addr + k] = b
        i += ln + 1
    return mem

def vectors(mem):
    return {"NMI":   mem[0x8FFA] | (mem[0x8FFB] << 8),
            "RESET": mem[0x8FFC] | (mem[0x8FFD] << 8),
            "IRQ":   mem[0x8FFE] | (mem[0x8FFF] << 8)}

if __name__ == "__main__":
    m = load()
    print("bytes loaded: %d  ($%04X-$%04X)" % (len(m), min(m), max(m)))
    for k, v in vectors(m).items():
        print("  %-5s = $%04X" % (k, v))
