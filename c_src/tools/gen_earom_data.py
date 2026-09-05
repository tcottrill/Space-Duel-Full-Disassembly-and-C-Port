#!/usr/bin/env python3
"""gen_earom_data.py - verify the A2EARO const tables inlined in earom.c.

The EAROM module's tables are tiny (14 bytes total), so per CONVENTIONS 1c
they are inlined in earom.c rather than generated into a sd_earom_data.c.
This script is the required byte-check: it reads the same bytes out of the
proven 64K image (disasm/build/spacduel_64k.bin, built by
disasm/gen_from_roms.py; CPU address == file offset) and
compares them with the values earom.c carries. Exit 0 = match.

Run:  py c_src/tools/gen_earom_data.py   (from the project root)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))   # project root
sys.path.insert(0, os.path.join(ROOT, "disasm"))
import paths

# (name in earom.c, ROM address, expected bytes as inlined)
TABLES = [
    ("tab_8747",                 0x8747, bytes([0x02, 0x1D, 0x1E, 0x3E])),
    ("earom_offset_lowest_byte", 0x874B, bytes([0x64, 0x01, 0x92, 0x01])),
    ("subnum",                   0x8926, bytes([0x00, 0x05, 0x00])),
    ("subl",                     0x893B, bytes([0x0C, 0x0B, 0x0E])),
]


def main() -> int:
    data = paths.load_image64k()
    bad = 0
    for name, addr, expect in TABLES:
        rom = data[addr:addr + len(expect)]
        ok = rom == expect
        bad += not ok
        print(f"{name:26s} ${addr:04X} rom={rom.hex(' ')} "
              f"{'OK' if ok else 'MISMATCH vs ' + expect.hex(' ')}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
