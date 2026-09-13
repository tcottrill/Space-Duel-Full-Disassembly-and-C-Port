#!/usr/bin/env python3
"""prof_pass.py - per-pass cycle profile of the Start2 mainline: cycles by
named routine between the VG-HALT wait entry ($401F) and the point at which
the pass's display list is complete ($4110, after JSR AddHaltToVector), with
the IRQ handler's cycles split out.

Pure OBSERVER over oracle.Oracle; nothing in the hardware model changes.
Ported 1:1 from the Gravitar port's tools/prof_pass.py; the PCs are Space
Duel's.  Use it to see WHERE a pass's cycles go when prof_fit.py says a
state's work does not follow its list length.

    py c_src\\tools\\prof_pass.py <scratch-outdir> <frames> <npasses> [scenario]
"""
import sys, os, argparse, bisect, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oracle as O

SPIN_ENTRY = 0x401F                 # BIT HALT - the pass's first hardware wait
LIST_DONE  = 0x4110                 # after JSR AddHaltToVector: list complete
HALT_SPIN  = (0x401F, 0x4023)       # BIT HALT / BVC Start2_6  (sd_wait_vghalt)
GATE_SPIN  = (0x4027, 0x402A)       # LSR SYNC / BCC Start2_8  (frame gate)
SETTLE     = 16                     # ignore passes before this frame


def in_spin(pc):
    return HALT_SPIN[0] <= pc <= HALT_SPIN[1] or GATE_SPIN[0] <= pc <= GATE_SPIN[1]

out = sys.argv[1]
frames = int(sys.argv[2])
NPASS = int(sys.argv[3])
scen = sys.argv[4] if len(sys.argv) > 4 else "attract"
os.makedirs(out, exist_ok=True)
args = argparse.Namespace(scenario=scen, frames=frames, outdir=out,
    vg_draw_cycles=4000, dip1008=0, dip1408=0, roms=None, trace_write=None,
    trace_pc=None, irq_marks=None, capture_range=None, capture_every=0,
    trace_random=False, trace_max=200, trace_out=None)

addr_set, named, _ = O.parse_listing()
starts = [a for a, _ in named]
names = [n for _, n in named]


def routine(pc):
    p = O.norm_pc(pc)
    i = bisect.bisect_right(starts, p) - 1
    return names[i] if i >= 0 else "?%04X" % p


class P(O.Oracle):
    def __init__(s, *a):
        super().__init__(*a)
        s.prof = None
        s.npass = 0
        s.in_irq = False

    def step(s):
        pc = s.pc
        c0 = s.cyc
        q0 = s.irq_count
        f0 = s.frame
        ent = O.OPCODES.get(s.mem[pc])
        mn = ent[0] if ent else None
        super().step()
        if s.irq_count != q0:
            s.in_irq = True
            return
        d = s.cyc - c0
        irq0 = s.in_irq
        if mn == "RTI":
            s.in_irq = False
        if pc == SPIN_ENTRY and not irq0 and s.frame > SETTLE and s.prof is None:
            s.prof = collections.Counter()
            s.t0 = c0
            s.irq_at_spin = q0
            s.f_spin = f0
            s.strobe_cyc = None
            s.spin = 0
        if s.prof is not None:
            if not irq0 and in_spin(pc):
                s.spin += d
            if s.strobe_cyc is None and s.frame != f0:   # the VGGO happened
                s.strobe_cyc = s.cyc
            key = ("IRQ:" + routine(pc)) if irq0 else routine(pc)
            s.prof[key] += d
            if pc == LIST_DONE and not irq0:
                tot = s.cyc - s.t0
                irqc = sum(v for k, v in s.prof.items() if k.startswith("IRQ:"))
                spin = s.spin
                print("\n== pass %d: frame %d irq %d -> list done frame %d irq %d"
                      " : %d cycles = %.2f IRQ periods"
                      % (s.npass, s.f_spin, s.irq_at_spin, s.frame, s.irq_count,
                         tot, tot / 6144.0))
                print("   IRQ handler %d (%.1f%%)   waits ($401F/$4027) %d   "
                      "strobe->list done %s cycles   list %d bytes"
                      % (irqc, 100.0 * irqc / tot, spin,
                         (s.cyc - s.strobe_cyc) if s.strobe_cyc else "n/a",
                         (((s.ram[2] << 8) | s.ram[1]) & 0x3FF) - 2))
                for k, v in s.prof.most_common(14):
                    print("   %8d %5.1f%%  %s" % (v, 100.0 * v / tot, k))
                s.prof = None
                s.npass += 1
                if s.npass >= NPASS:
                    s.done = True


sim = P(O.load_image(None), args, O.SCENARIOS[scen]())
try:
    sim.run()
except O.OracleError as e:
    print("oracle stopped:", e)
