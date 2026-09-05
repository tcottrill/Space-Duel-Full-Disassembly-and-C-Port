#!/usr/bin/env python3
"""Build the Space Duel CPU address space from a ROM set and regenerate
everything derived from it.

ROMs are matched by part number and SHA-1, not by file name, so a MAME
`spacduel.zip`, a directory of loose files (`136006.201`, `136006-201.r1`
...) or a directory of romset zips all work.  Loose files are indexed
before zip members, and when several files share a part number the one
whose length and SHA-1 match is the one used.

    136006-106  R7    $2800-$2FFF  vector ROM (ship pictures)
    136006-107  N/P7  $3000-$3FFF  vector ROM (AVG display lists)
    136006-201  R1    $4000-$4FFF  program, rev 2 (136006-101 in rev 1)
    136006-102  N/P1  $5000-$5FFF
    136006-103  M1    $6000-$6FFF
    136006-104  K/L1  $7000-$7FFF
    136006-105  J1    $8000-$8FFF  mirrored to $FFFF; supplies the vectors

Usage:
    python gen_from_roms.py <rom-directory-or-zip> [--listings] [--check] [--cc65 DIR]

With no flag it writes build/spacduel_64k.bin and reports which tracked
files changed (none, for that alone).  --listings runs the whole chain:
the program listing and the defines (need Atari's archive at
../space-duel-main; skipped with a message when absent), verify, the
vector ROM listing and the shape names (also need the archive), then the
C port's generated files.  --check translates the program listing to
ca65 syntax, assembles and links it, and compares the result with the
ROM.  It ends by listing any tracked file the run changed.
"""
import argparse
import hashlib
import os
import re
import subprocess
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths

# The MAME spacduel set's SHA-1s, keyed by Atari file name.  The sockets,
# load addresses and lengths live in paths.ROMS, so the ROM table has one
# authority; ROM_SET is the two joined.
SHA1 = {
    "136006.106": "f53be76a49dba319050ca7767de3441521910e83",
    "136006.107": "58060b20b2511d30d2ec06479d21840bdd0b53c6",
    "136006.201": "9bacb64d257edd31f53db878477604f50681d78f",
    "136006.102": "c05c52bb08acccb60950a15f05c960c3bc163d3e",
    "136006.103": "d36d62cdf7fe76ee9cdbfc2e76ac5d90f22986ba",
    "136006.104": "9e8773e78d65d74db824cfd7108e7038f26757db",
    "136006.105": "b15891d22a47ac3448d2ced40c04d0ab80606c7d",
}

# (Atari file name, load address, length, sha1) - the MAME spacduel set.
ROM_SET = [(fn, base, size, SHA1[fn]) for _sock, fn, base, size in paths.ROMS]

# `136006.201`, `136006-201.r1`, `136006-201` all reduce to (part, number);
# the trailing (?!\d) keeps a longer number from being cut down to three.
ROM_NAME_RE = re.compile(r"^(\d{6})[.\-_](\d{3})(?!\d)")

PORT_GENERATORS = [
    "gen_state.py", "gen_vecrom.py", "gen_progrom.py", "gen_display_data.py",
    "gen_earom_data.py", "gen_lowones_data.py", "gen_mainline_data.py",
    "gen_msgs_data.py", "gen_objects_data.py", "gen_score_data.py",
    "gen_selftest_data.py", "gen_sound_data.py",
]


def _key(name):
    m = ROM_NAME_RE.match(os.path.basename(name))
    return (m.group(1), m.group(2)) if m else None


def index_roms(romdir):
    """(part, number) -> [(label, loader), ...] for every ROM reachable
    from romdir: loose files first, then members of any zip.  Every
    candidate is kept, so build_image can pick the one that hashes right."""
    found = {}

    def add(key, label, loader):
        if key is not None:
            found.setdefault(key, []).append((label, loader))

    targets = [romdir] if os.path.isfile(romdir) else []
    if not targets:
        for root, _dirs, files in os.walk(romdir):
            _dirs.sort()
            targets.extend(os.path.join(root, n) for n in sorted(files))
    for p in targets:
        if not p.lower().endswith(".zip"):
            add(_key(p), p, lambda p=p: open(p, "rb").read())
    for p in targets:
        if p.lower().endswith(".zip"):
            try:
                zf = zipfile.ZipFile(p)
            except (zipfile.BadZipFile, OSError) as exc:
                print("  note: cannot read %s (%s); skipped" % (p, exc))
                continue
            for m in sorted(zf.namelist()):
                if not m.endswith("/"):
                    add(_key(m), "%s:%s" % (os.path.basename(p), m),
                        lambda m=m, z=zf: z.read(m))
    return found


def find_rom(romdir, fn):
    """Bytes of the ROM whose Atari name is fn, wherever it is in romdir.
    The first candidate wins; build_image is the one that checks SHA-1."""
    cands = index_roms(romdir).get(_key(fn))
    if not cands:
        sys.exit("ROM %s not found under %s" % (fn, romdir))
    return cands[0][1]()


def build_image(romdir):
    index = index_roms(romdir)
    img = bytearray(0x10000)
    missing, bad = [], []
    for fn, addr, length, want in ROM_SET:
        cands = index.get(_key(fn))
        if not cands:
            missing.append(fn)
            continue
        chosen, tried = None, []
        for label, loader in cands:
            data = loader()
            got = hashlib.sha1(data).hexdigest()
            tried.append((label, len(data), got))
            if len(data) == length and got == want:
                chosen = (label, data, got)
                break
        if chosen is None:       # no candidate for this part number is right
            for label, n, got in tried:
                if n != length:
                    bad.append("%s: expected %d bytes, got %d" % (label, length, n))
                else:
                    bad.append("%s: sha1 %s, expected %s" % (label, got, want))
            continue
        label, data, got = chosen
        img[addr:addr + length] = data
        print("  %-28s -> $%04X-$%04X  %s" % (os.path.basename(label), addr,
                                              addr + length - 1, got[:12]))
    if missing:
        sys.exit("missing ROMs: " + ", ".join(missing))
    if bad:
        sys.exit("bad ROMs:\n  " + "\n  ".join(bad))
    for mirror in range(0x9000, 0x10000, 0x1000):
        img[mirror:mirror + 0x1000] = img[0x8000:0x9000]
    os.makedirs(paths.BUILD, exist_ok=True)
    with open(paths.IMAGE64K, "wb") as f:
        f.write(img)
    print("wrote", os.path.relpath(paths.IMAGE64K, paths.ROOT))
    return bytes(img)


def run(script, *args):
    """Run one tool as a subprocess so its own __main__ does the work.
    Returns True on success; a failing step is reported, not fatal, so the
    rest of the chain still runs and the summary at the end is complete."""
    cmd = [sys.executable, script] + list(args)
    print("\n== " + os.path.relpath(script, paths.ROOT) + " " + " ".join(args))
    sys.stdout.flush()          # the child writes to the same fd
    r = subprocess.run(cmd, cwd=paths.DISASM)
    if r.returncode != 0:
        print("!! %s failed (exit %d)" % (os.path.relpath(script, paths.ROOT), r.returncode))
    return r.returncode == 0


def listings(romdir):
    roms = ["--roms", romdir]
    d = paths.DISASM
    ok = True
    if paths.have_archive():
        ok &= run(os.path.join(d, "emit.py"), *roms)
        ok &= run(os.path.join(d, "emit_defines.py"), *roms)
    else:
        print("\n(Atari's source archive is not at %s: the program listing and the"
              "\n defines are kept as checked in)" % paths.ARCHIVE)
    ok &= run(os.path.join(d, "verify.py"), *roms)
    if paths.have_archive():
        ok &= run(os.path.join(d, "emit_vrom.py"), *roms)
        ok &= run(os.path.join(d, "emit_shapes.py"), *roms)
    else:
        print("(the vector ROM listing and shape names also need the archive)")
    t = os.path.join(paths.CSRC, "tools")
    for g in PORT_GENERATORS:
        ok &= run(os.path.join(t, g), *roms)
    return ok


def check(romdir, cc65):
    if not run(os.path.join(paths.DISASM, "emit_ca65.py"), "--roms", romdir):
        return False
    ca65 = os.path.join(cc65, "ca65") if cc65 else "ca65"
    ld65 = os.path.join(cc65, "ld65") if cc65 else "ld65"
    b = paths.BUILD
    try:
        subprocess.run([ca65, "--cpu", "6502", "-o", os.path.join(b, "program.o"),
                        os.path.join(b, "program_ca65.s")], check=True)
        subprocess.run([ld65, "-C", os.path.join(paths.DISASM, "flat.cfg"),
                        "-o", os.path.join(b, "program.bin"), os.path.join(b, "program.o")],
                       check=True)
    except (OSError, subprocess.CalledProcessError) as exc:
        print("!! ca65/ld65 failed: %s (install cc65 or pass --cc65 DIR)" % exc)
        return False
    out = open(os.path.join(b, "program.bin"), "rb").read()
    ref = open(paths.IMAGE64K, "rb").read()[0x4000:0x9000]
    bad = sum(1 for x, y in zip(out, ref) if x != y)
    print("ca65 round trip: %d bytes, %d mismatches" % (len(out), bad))
    if len(out) != len(ref) or bad:
        print("!! the plain listing does not reassemble to the ROM")
        return False
    return True


def tracked_status():
    """(lines, error): `git status --short` over the tracked files under
    disasm/ and c_src/, or the reason git could not be asked."""
    try:
        r = subprocess.run(["git", "status", "--short", "--untracked-files=no",
                            "--", "disasm", "c_src"],
                           capture_output=True, text=True, cwd=paths.ROOT)
    except OSError as exc:
        return [], str(exc)
    if r.returncode != 0:
        return [], "git status exited %d%s" % (
            r.returncode, (": " + r.stderr.strip()) if r.stderr.strip() else "")
    return r.stdout.splitlines(), None


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("romdir", help="directory of ROM files or romset zips, or one zip")
    ap.add_argument("--listings", action="store_true", help="regenerate every derived file")
    ap.add_argument("--check", action="store_true",
                    help="ca65/ld65 round trip of the program listing")
    ap.add_argument("--cc65", default=None, help="directory holding ca65 and ld65 (else PATH)")
    a = ap.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(line_buffering=True)
    romdir = os.path.abspath(a.romdir)
    if not os.path.exists(romdir):
        sys.exit("ROM directory %s does not exist" % romdir)
    before, before_err = tracked_status()
    build_image(romdir)
    ok = True
    if a.listings:
        ok &= listings(romdir)
    if a.check:
        ok &= check(romdir, a.cc65)
    after, after_err = tracked_status()
    err = before_err or after_err
    print("\nchecked-in files changed by this run:")
    if err:
        print("  (could not query git: %s)" % err)
    else:
        seen = set(before)
        print("\n".join([l for l in after if l not in seen]) or "  (none)")
    if not ok:
        sys.exit("some steps failed; see the !! lines above")


if __name__ == "__main__":
    main()
