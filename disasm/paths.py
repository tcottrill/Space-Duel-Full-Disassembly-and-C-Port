"""Where everything lives, resolved from this file so every tool runs from
any directory.

ROM images and Atari's source archive are not distributed (see README.md):
ROMs are looked for in <root>/roms, overridden by --roms DIR on any tool's
command line or the SD_ROMS environment variable; the archive is expected
at <root>/space-duel-main, the name GitHub gives the download.
"""
import os
import sys

DISASM   = os.path.dirname(os.path.abspath(__file__))
if DISASM not in sys.path:
    sys.path.insert(0, DISASM)
ROOT     = os.path.normpath(os.path.join(DISASM, ".."))
CSRC     = os.path.join(ROOT, "c_src")
ARCHIVE  = os.path.join(ROOT, "space-duel-main")
BUILD    = os.path.join(DISASM, "build")          # gitignored scratch
IMAGE64K = os.path.join(BUILD, "spacduel_64k.bin")

PROGRAM_ROM = os.path.join(DISASM, "spaceduel_program_rom.asm")
VECTOR_ROM  = os.path.join(DISASM, "spaceduel_vector_rom.asm")
DEFINES     = os.path.join(DISASM, "spaceduel_defines.asm")
VEC_NAMES   = os.path.join(DISASM, "vec_names.py")
SHAPES_HTML = os.path.join(DISASM, "shapes_preview.html")

# socket -> (file, cpu base, size).  Rev 2 set: 136006-201 replaces -101 at $4000.
ROMS = [
    ("R7",   "136006.106", 0x2800, 0x0800),   # vector ROM
    ("N/P7", "136006.107", 0x3000, 0x1000),   # vector ROM
    ("R1",   "136006.201", 0x4000, 0x1000),   # program (rev 2)
    ("N/P1", "136006.102", 0x5000, 0x1000),
    ("M1",   "136006.103", 0x6000, 0x1000),
    ("K/L1", "136006.104", 0x7000, 0x1000),
    ("J1",   "136006.105", 0x8000, 0x1000),   # mirrored $9000-$FFFF, supplies vectors
]

CODE_LO, CODE_HI = 0x4000, 0x8FFF     # 6502 program space
VROM_LO, VROM_HI = 0x2800, 0x3FFF     # AVG vector ROM (data, not 6502)


def roms_dir(explicit=None):
    """The ROM directory: an explicit argument, else --roms on the command
    line, else $SD_ROMS, else <root>/roms."""
    if explicit:
        return explicit
    argv = sys.argv
    for i, a in enumerate(argv):
        if a == "--roms":
            if i + 1 < len(argv):
                return argv[i + 1]
            raise SystemExit("--roms needs a directory")
        if a.startswith("--roms="):
            return a.split("=", 1)[1]
    return os.environ.get("SD_ROMS") or os.path.join(ROOT, "roms")


def roms_dir_is_explicit():
    """True when the ROM directory was set by --roms or $SD_ROMS, in which
    case a cached image built from some other set must not be trusted."""
    return any(a == "--roms" or a.startswith("--roms=") for a in sys.argv) \
        or bool(os.environ.get("SD_ROMS"))


def strip_roms_arg(argv):
    """argv without --roms DIR / --roms=DIR, for tools that parse the rest."""
    out, skip = [], False
    for a in argv:
        if skip:
            skip = False
            continue
        if a == "--roms":
            skip = True
            continue
        if a.startswith("--roms="):
            continue
        out.append(a)
    return out


def have_archive():
    return os.path.isdir(ARCHIVE)


def archive_dir(explicit=None):
    """Atari's source archive directory: the explicit argument, else
    ARCHIVE; a clear error when it is absent."""
    d = explicit or ARCHIVE
    if not os.path.isdir(d):
        raise SystemExit("Atari's source archive is not present at %s\n"
                         "(github.com/historicalsource/space-duel, unzipped "
                         "beside disasm/); this step needs it." % d)
    return d


def archive(fn, srcdir=None):
    """Path of one file in Atari's archive; a clear error when it is absent."""
    return os.path.join(archive_dir(srcdir), fn)


def rom_bytes(romdir, fn, size):
    """One ROM by its Atari file name, loose in romdir or inside a zip there.
    gen_from_roms.py does the strict part-number/SHA-1 match; this is the
    lightweight loader the older tools use."""
    if not (os.path.isdir(romdir) or os.path.isfile(romdir)):
        raise SystemExit("ROM directory %s does not exist (set --roms DIR or $SD_ROMS; see README.md)" % romdir)
    path = os.path.join(romdir, fn)
    if os.path.isfile(path):
        d = open(path, "rb").read()
    else:
        try:
            import gen_from_roms
        except ImportError:
            raise SystemExit("%s is not a loose file in %s and gen_from_roms.py "
                             "(the zip reader) could not be imported" % (fn, romdir))
        d = gen_from_roms.find_rom(romdir, fn)
    if len(d) != size:
        raise SystemExit("%s: expected %d bytes, got %d" % (fn, size, len(d)))
    return d


def load_roms(romdir=None):
    """{addr: byte} for $2800-$8FFF."""
    romdir = roms_dir(romdir)
    mem = {}
    for _sock, fn, base, size in ROMS:
        for i, b in enumerate(rom_bytes(romdir, fn, size)):
            mem[base + i] = b
    return mem


def image64k(romdir=None, write=True):
    """The 65536-byte CPU image: the ROMs at their bases, $8000-$8FFF
    mirrored through $FFFF (J1 answers the vector fetch).  Written to
    BUILD/spacduel_64k.bin for the C port's generators when write is set."""
    romdir = roms_dir(romdir)
    img = bytearray(0x10000)
    for _sock, fn, base, size in ROMS:
        img[base:base + size] = rom_bytes(romdir, fn, size)
    for mirror in range(0x9000, 0x10000, 0x1000):
        img[mirror:mirror + 0x1000] = img[0x8000:0x9000]
    if write:
        os.makedirs(BUILD, exist_ok=True)
        with open(IMAGE64K, "wb") as f:
            f.write(img)
    return bytes(img)


def load_image64k():
    """The 64K image for tools that only read it: BUILD/spacduel_64k.bin if
    present, else built from the ROM directory.

    Callers that may have changed the ROM set must call image64k() first.
    With --roms or $SD_ROMS set the cache is bypassed and the image is
    built from that set."""
    if roms_dir_is_explicit():
        return image64k(write=False)
    if os.path.isfile(IMAGE64K):
        d = open(IMAGE64K, "rb").read()
        if len(d) == 0x10000:
            return d
    return image64k()
