#!/usr/bin/env python3
"""prof_fit.py - one line per Start2 pass: STATE, DSTATE, the display-list
bytes the pass built, and the mainline work cycles it spent (excluding the
two hardware waits and the IRQ handler), split PRE/POST at the pass's first
hardware wait.  Then the least-squares fit those lines feed:
app_loop.c's cpu_fits[] table.

Pure OBSERVER over oracle.Oracle - nothing in the hardware model changes,
and no reference bytes are written (--outdir is scratch space the oracle
insists on).  Ported 1:1 from the Gravitar port's tools/prof_fit.py plus its
2026-09-13 pre/post-split variant; the PC constants below are Space Duel's.

    py c_src\\tools\\prof_fit.py <scratch-outdir> <frames> <scenario> [--rows]

The pass boundary is LIST_DONE = $4110, the instruction after
`L410D JSR AddHaltToVector` returns - the point at which the display list
this pass built is complete and VGLIST/EAC2 says how long it is.  That is
Space Duel's Namony: the seam hook sd_hw_list_done() sits there.

Two spins, both real hardware waits in the C port:
    $401F BIT HALT / $4022 BVC     - wait for the AVG (sd_wait_vghalt)
    $4027 LSR SYNC / $4029 BCC     - the frame gate  (sd_wait_frame_gate)
PRE is the mainline work from LIST_DONE to the FIRST instruction of the
first of those (Start2's Gtoptn and the self-test test); POST is everything
after, Start2_8's tail and the whole list build.  app_loop.c charges PRE
before the AVG wait and POST at sd_hw_list_done().
"""
import sys, os, argparse, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import oracle as O

LIST_DONE  = 0x4110                 # after JSR AddHaltToVector: list complete
HALT_SPIN  = (0x401F, 0x4023)       # BIT HALT / BVC Start2_6
GATE_SPIN  = (0x4027, 0x402A)       # LSR SYNC / BCC Start2_8
A_STATE    = 0x35                   # ATRACT: 0 = attract, $80 = playing
A_DSTATE   = 0xDC                   # ATSTG:  the attract-stage flag
A_VGLIST   = 0x01                   # VGLIST / EAC2: the list write pointer
SETTLE     = 16                     # ignore passes before this frame


def in_spin(pc):
    return HALT_SPIN[0] <= pc <= HALT_SPIN[1] or GATE_SPIN[0] <= pc <= GATE_SPIN[1]


class Prof(O.Oracle):
    """Rows of (frame, irqs, state, dstate, listbytes, work, pre, spin, irq,
    total) - one per completed pass."""

    def __init__(s, *a):
        super().__init__(*a)
        s.rows = []
        s.on = False
        s.in_irq = False

    def step(s):
        pc = s.pc
        c0 = s.cyc
        q0 = s.irq_count
        ent = O.OPCODES.get(s.mem[pc])       # PC is always in ROM ($2800+)
        mn = ent[0] if ent else None
        super().step()
        if s.irq_count != q0:               # the service sequence just ran
            s.in_irq = True
            return
        d = s.cyc - c0
        irq0 = s.in_irq
        if mn == "RTI":
            s.in_irq = False                # the handler's only exit
        if not s.on:
            if pc == LIST_DONE and not irq0 and s.frame > SETTLE:
                s.on = True
                s._restart()
            return
        if irq0:
            s.irqc += d
        elif in_spin(pc):
            s.spin += d
            s.inpre = False
        elif s.inpre:
            s.pre += d
        if pc == LIST_DONE and not irq0:
            tot = s.cyc - s.t0
            work = tot - s.spin - s.irqc
            lb = (((s.ram[A_VGLIST + 1] << 8) | s.ram[A_VGLIST]) & 0x3FF) - 2
            s.rows.append((s.frame, s.irq_count - s.i0, s.ram[A_STATE],
                           s.ram[A_DSTATE], lb, work, s.pre, s.spin, s.irqc, tot))
            s._restart()

    def _restart(s):
        s.t0 = s.cyc
        s.i0 = s.irq_count
        s.spin = s.irqc = s.pre = 0
        s.inpre = True


def fit(rows):
    """Least squares work = base + per_byte * listbytes, and the per-state
    mean (per_byte 0) beside it, so the caller can pick the honest one."""
    n = len(rows)
    xs = [float(r[4]) for r in rows]
    ys = [float(r[5]) for r in rows]
    mx = sum(xs) / n
    my = sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    slope = (sxy / sxx) if sxx > 0.0 else 0.0
    base = my - slope * mx
    sd_fit = (sum((y - (base + slope * x)) ** 2 for x, y in zip(xs, ys)) / n) ** 0.5
    sd_mean = (sum((y - my) ** 2 for y in ys) / n) ** 0.5
    pre = sum(r[6] for r in rows) / n
    irqs = sum(r[1] for r in rows)
    handler = (sum(r[8] for r in rows) / irqs) if irqs else 0.0
    return dict(passes=n, base=base, per_byte=slope, sd=sd_fit,
                mean=my, sd_mean=sd_mean, pre=pre, handler=handler,
                lb_min=min(xs), lb_max=max(xs), irqs=irqs / float(n))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("outdir")
    ap.add_argument("frames", type=int)
    ap.add_argument("scenario", choices=sorted(O.SCENARIOS))
    ap.add_argument("--rows", action="store_true", help="print every pass")
    a = ap.parse_args()
    os.makedirs(a.outdir, exist_ok=True)
    args = argparse.Namespace(scenario=a.scenario, frames=a.frames,
        outdir=a.outdir, vg_draw_cycles=4000, dip1008=0, dip1408=0, roms=None,
        trace_write=None, trace_pc=None, irq_marks=None, capture_range=None,
        capture_every=0, trace_random=False, trace_max=200, trace_out=None)

    sim = Prof(O.load_image(None), args, O.SCENARIOS[a.scenario]())
    try:
        sim.run()
    except O.OracleError as e:
        print("oracle stopped:", e)

    if a.rows:
        print("frame irqs STATE DSTATE listbytes work pre spin irq total")
        for r in sim.rows:
            print("%5d %3d %02X %02X %5d %6d %6d %6d %6d %6d"
                  % (r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]))

    groups = collections.OrderedDict()
    for r in sim.rows:
        groups.setdefault((r[2], r[3]), []).append(r)
    print("\nscenario %s: %d passes over %d frames"
          % (a.scenario, len(sim.rows), sim.frame))
    print("%-13s %6s %9s %9s %7s %9s %8s %8s %7s %s"
          % ("STATE DSTATE", "passes", "base", "per_byte", "sd",
             "mean(sd)", "pre", "handler", "IRQ/ps", "listbytes"))
    for k in sorted(groups):
        f = fit(groups[k])
        print("%02X    %02X      %6d %9.0f %9.2f %7.0f %9.0f(%.0f) %8.0f %8.0f %7.2f %d-%d"
              % (k[0], k[1], f["passes"], f["base"], f["per_byte"], f["sd"],
                 f["mean"], f["sd_mean"], f["pre"], f["handler"], f["irqs"],
                 f["lb_min"], f["lb_max"]))


if __name__ == "__main__":
    main()
