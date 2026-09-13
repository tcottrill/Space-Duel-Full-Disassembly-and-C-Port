/* probe_selftest.c - Space Duel C port: the self-test differential probe.
 *
 * probe_attract.c's harness (the oracle-identical sd_hw_* seam, the
 * recorded-IRQ-schedule replay, the vram+ram byte diff at every VGGO) for
 * the self-test scenarios of tools/oracle.py: the bookkeeping screen, the
 * power-on diagnostics and the CPU restarts between them.  Run from c_src\:
 *
 *     tests\probe_selftest.exe [frames] [refdir]
 *                              (default 440 tests\ref_selftest)
 *
 * Exit 0 = every captured frame byte-identical (vram AND ram).
 *
 * Two things differ from the attract probe:
 *
 *  - Inputs are scripted: <refdir>\scenario.txt (written by oracle.py) is
 *    replayed - every IN0/IN1 change at the VGGO opening the same frame
 *    number, frame-0 changes at RESET.  So the probe sees exactly the
 *    switch state the oracle saw, including the self-test switch itself.
 *
 *  - IRQ replay has a second sync point.  The mainline's per-frame gate
 *    ($4027) is where the attract probe advances to the recorded irq_count;
 *    the self-test loops have no gate.  The bookkeeping loop's only wait is
 *    the VG HALT wait at its top ($8A8C) and the diagnostics' is the 3 kHz
 *    frame timer ($8592) - so while the CPU is parked in a test loop
 *    (sd_cpu_loop() != Start2) those seam waits replay the schedule
 *    instead, and the attract portion keeps the attract probe's behaviour
 *    byte-for-byte.  A CPU restart (sd_hw_reset) is sd_boot() again; the
 *    oracle's frame and IRQ counters run on across it and so do ours.
 *
 * The stack mask and its justification are probe_attract.c's.
 */
#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sd_state.h"
#include "sd_hw.h"
#include "selftest.h"
#include "platform/sd_platform.h"    /* plat_sample_* stubs below */

extern void sd_irq(void);            /* irq.c: Irq $8639                  */
extern void sd_boot(void);           /* mainline.c: Poweron               */
extern void sd_mainline_frame(void); /* mainline.c: one pass              */

/* ------------------------------------------------------------------ */
/* oracle schedule, scenario + reference dumps                         */
/* ------------------------------------------------------------------ */

static const char* refdir = "tests\\ref_selftest";
static unsigned sched[4096];
static int      sched_n;

static int load_sched(void)
{
    char path[512];
    FILE* f;
    snprintf(path, sizeof path, "%s\\vggo_sched.txt", refdir);
    f = fopen(path, "r");
    if (!f) { fprintf(stderr, "PROBE: cannot open %s\n", path); return 1; }
    while (sched_n < (int)(sizeof sched / sizeof sched[0]) &&
           fscanf(f, "%u", &sched[sched_n]) == 1)
        sched_n++;
    fclose(f);
    return sched_n ? 0 : 1;
}

/* the scripted switches: oracle.py's apply_event, replayed */
typedef struct { unsigned frame; int kind; unsigned a, b; } sc_event;
enum { SC_IN0_SET, SC_IN0_CLEAR, SC_IN1 };
static sc_event  events[512];
static int       events_n;
static uint8_t   in0_base = 0x10;        /* the oracle's reset value   */
static uint8_t   in1[8];

static int load_scenario(void)
{
    char path[512], line[256], kind[32];
    FILE* f;
    unsigned fr, a, b;
    snprintf(path, sizeof path, "%s\\scenario.txt", refdir);
    f = fopen(path, "r");
    if (!f) { fprintf(stderr, "PROBE: cannot open %s\n", path); return 1; }
    while (fgets(line, sizeof line, f)) {
        int n;
        if (line[0] == '#') continue;
        n = sscanf(line, "%u %31s %i %i", &fr, kind, &a, &b);
        if (n < 3 || events_n >= (int)(sizeof events / sizeof events[0]))
            continue;
        events[events_n].frame = fr;
        events[events_n].a = a;
        events[events_n].b = (n > 3) ? b : 0;
        if      (!strcmp(kind, "in0_set"))   events[events_n].kind = SC_IN0_SET;
        else if (!strcmp(kind, "in0_clear")) events[events_n].kind = SC_IN0_CLEAR;
        else if (!strcmp(kind, "in1") && n == 4) events[events_n].kind = SC_IN1;
        else continue;
        events_n++;
    }
    fclose(f);
    return 0;
}

static void apply_events(unsigned frame)
{
    int i;
    for (i = 0; i < events_n; i++) {
        if (events[i].frame != frame) continue;
        switch (events[i].kind) {
        case SC_IN0_SET:   in0_base = (uint8_t)(in0_base | events[i].a);  break;
        case SC_IN0_CLEAR: in0_base = (uint8_t)(in0_base & ~events[i].a); break;
        case SC_IN1:       in1[events[i].a & 7] = (uint8_t)events[i].b;   break;
        default: break;
        }
    }
}

static int load_ref(const char* kind, int frame, uint8_t* buf, size_t len)
{
    char path[512];
    FILE* f;
    size_t got;
    snprintf(path, sizeof path, "%s\\frame_%04d.%s", refdir, frame, kind);
    f = fopen(path, "rb");
    if (!f) return -1;                       /* not a captured frame */
    got = fread(buf, 1, len, f);
    fclose(f);
    return got == len ? 0 : 1;
}

/* ------------------------------------------------------------------ */
/* the hardware seam, oracle-identical                                 */
/* ------------------------------------------------------------------ */

static uint32_t lfsr = 0x1FFFF;
static unsigned long rnd_count;
uint8_t sd_hw_pokey_random(int which)
{
    (void)which;                             /* both POKEYs share it */
    for (int k = 0; k < 8; k++) {
        uint32_t bit = ((lfsr >> 16) ^ (lfsr >> 11)) & 1u;
        lfsr = ((lfsr << 1) | bit) & 0x1FFFFu;
    }
    rnd_count++;
    return (uint8_t)lfsr;
}

/* IN0: the scripted base plus d6 (VG HALT) always done - the oracle's HALT
 * window (4000 cycles after a VGGO) is over before any of the self-test's
 * waits polls it, and d6/d7 never reach RAM (every reader masks them). */
uint8_t sd_hw_in0(void)  { return (uint8_t)(in0_base | 0x40); }
uint8_t sd_hw_in1(uint8_t idx) { return in1[idx & 7]; }
uint8_t sd_hw_pokey2_optionsw(void) { return 0x00; }
uint8_t sd_hw_pokey1_diffsw(void)   { return 0x00; }

static unsigned pokey_writes, earom_ctl_writes, earom_data_writes, resets;
void sd_hw_pokey_write(int which, uint8_t reg, uint8_t val)
{ (void)which; (void)reg; (void)val; pokey_writes++; }

void plat_sample_start(int channel, int sample, int loop)
{ (void)channel; (void)sample; (void)loop; }
void plat_sample_stop(int channel) { (void)channel; }
void plat_sample_freq(int channel, float ratio)
{ (void)channel; (void)ratio; }
void sd_hw_out1(uint8_t v) { g.out1 = v; }
void sd_hw_vgreset(void) {}
uint8_t sd_hw_earom_read(void) { return 0x00; }          /* blank part */
void sd_hw_earom_ctl(uint8_t v) { (void)v; earom_ctl_writes++; }
void sd_hw_earom_write(uint8_t off, uint8_t v)
{ (void)off; (void)v; earom_data_writes++; }

/* ---- machine time ------------------------------------------------- */

void sd_hw_idle(void) { sd_irq(); }

static int booted;                           /* set once sd_boot returns  */

/* Mid-pass IRQ sync points (<refdir>\irq_marks.txt, `oracle.py --irq-marks`
 * with the six PCs listed in sd_hw.h): the attract probe's four mainline
 * points, plus the bookkeeping screen's exit (point 4, called from
 * selftest.c) and Poweron (point 5, called from sd_hw_reset below).  Same
 * principle as vggo_sched.txt - replay the machine's own recorded IRQ
 * schedule - sampled inside the pass. */
#define NMARKPT 6
static unsigned marks[NMARKPT][4096];
static int      marks_have;

static void load_marks(void)
{
    char path[512];
    FILE* f;
    char line[256];
    unsigned pt, fr, q;
    snprintf(path, sizeof path, "%s\\irq_marks.txt", refdir);
    f = fopen(path, "r");
    if (!f) return;
    while (fgets(line, sizeof line, f)) {
        if (line[0] == '#') continue;
        if (sscanf(line, "%u %u %u", &pt, &fr, &q) == 3 &&
            pt < NMARKPT && fr < 4096) {
            marks[pt][fr] = q;
            marks_have++;
        }
    }
    fclose(f);
}

void sd_hw_irq_mark(int point)
{
    unsigned f = g.frame_count;
    if (!marks_have || point < 0 || point >= NMARKPT || f >= 4096)
        return;
    if (marks[point][f] == 0) return;            /* no sample: leave be */
    while (g.irq_count < marks[point][f]) sd_irq();
}

/* advance to the recorded irq_count of the coming VGGO */
static void replay_to_next_vggo(void)
{
    int next = (int)g.frame_count;
    if (next < sched_n)
        while (g.irq_count < sched[next]) sd_irq();
}

/* LSR $33 / BCC ($4027): consume one gate bit, ROM dynamics. */
static void consume_gate_bit(void)
{
    for (;;) {
        int c = ZP_33 & 1;
        ZP_33 >>= 1;
        if (c) return;
        if (ZP_33 == 0) sd_irq();            /* out of bits: time passes */
    }
}

void sd_wait_frame_gate(void)
{
    if (booted) replay_to_next_vggo();
    consume_gate_bit();
}

/* The test loops' waits: the schedule sync points while parked there;
 * in the game's Start2 loop the HALT wait stays the attract probe's no-op
 * (its IRQs are taken at the frame gate). */
void sd_wait_vghalt(void)
{
    if (booted && sd_cpu_loop() != SD_LOOP_START2) replay_to_next_vggo();
}

void sd_wait_3khz(uint8_t n)
{
    (void)n;
    if (booted) replay_to_next_vggo();
}

/* The pass's list is complete.  A no-op here: the probe replays the
 * oracle's recorded IRQ schedule and must never spend machine time of its
 * own (app_loop.c charges the 6502's own pass time there). */
void sd_hw_list_done(void) {}

/* The CPU restarts at Poweron; the counters the oracle keeps outside the
 * CPU (frame, irq_count) run on.  The IRQs the oracle serviced between
 * this pass's VGGO and the restart hit RAM the restart then wiped, so they
 * are replayed BEFORE the wipe (point 5), not at the next wait. */
void sd_hw_reset(void)
{
    resets++;
    sd_hw_irq_mark(SD_IRQ_MARK_RESET);
    sd_boot();
}

/* ---- VGGO: the snapshot/compare point ------------------------------ */

static int frames_target = 440;
static int frames_compared, frames_clean, done;
static long total_bad, total_stack;

#define STACK_LO 0x01E1
#define STACK_HI 0x0200

static long diff_report(const char* kind, const uint8_t* got,
                        const uint8_t* want, size_t len, uint16_t base,
                        long* stack_out)
{
    long bad = 0;
    int shown = 0;
    for (size_t i = 0; i < len; i++) {
        if (got[i] != want[i]) {
            unsigned addr = (unsigned)(base + i);
            if (stack_out && addr >= STACK_LO && addr < STACK_HI) {
                (*stack_out)++;                  /* 6502 stack residue */
                continue;
            }
            if (shown < 64) {
                printf("    %s $%04X: C=%02X oracle=%02X\n",
                       kind, addr, got[i], want[i]);
                shown++;
            }
            bad++;
        }
    }
    if (bad > shown) printf("    %s: ... %ld mismatches total\n", kind, bad);
    return bad;
}

static const char* dumpdir;

static void dump_state(int frame)
{
    char path[512];
    FILE* f;
    if (!dumpdir) return;
    snprintf(path, sizeof path, "%s\\frame_%04d.vram", dumpdir, frame);
    f = fopen(path, "wb");
    if (f) { fwrite(g.vram, 1, 2048, f); fclose(f); }
    snprintf(path, sizeof path, "%s\\frame_%04d.ram", dumpdir, frame);
    f = fopen(path, "wb");
    if (f) { fwrite(g.ram, 1, 1024, f); fclose(f); }
}

void sd_hw_vggo(void)
{
    static uint8_t ref[2048];
    int frame;
    long bad = 0;

    g.frame_count++;
    frame = (int)g.frame_count;
    apply_events((unsigned)frame);           /* the oracle applies at VGGO */

    if (frame - 1 < sched_n && g.irq_count != sched[frame - 1])
        printf("  frame %d: irq_count %u vs oracle %u\n",
               frame, g.irq_count, sched[frame - 1]);

    if (load_ref("vram", frame, ref, 2048) == 0) {
        long stack = 0;
        dump_state(frame);
        bad += memcmp(g.vram, ref, 2048)
             ? diff_report("vram", g.vram, ref, 2048, 0x2000, NULL) : 0;
        if (load_ref("ram", frame, ref, 1024) == 0)
            bad += memcmp(g.ram, ref, 1024)
                 ? diff_report("ram", g.ram, ref, 1024, 0x0000, &stack) : 0;
        frames_compared++;
        if (bad == 0) frames_clean++;
        else printf("  frame %d (loop %d): %ld mismatched bytes"
                    " (+%ld 6502-stack-page bytes, masked)\n",
                    frame, sd_cpu_loop(), bad, stack);
        total_bad += bad;
        total_stack += stack;
    }
    if (frame >= frames_target) done = 1;
}

/* ------------------------------------------------------------------ */

int main(int argc, char** argv)
{
    if (argc > 1) frames_target = atoi(argv[1]);
    if (argc > 2) refdir = argv[2];
    dumpdir = getenv("SD_PROBE_DUMP");           /* diagnostic dump dir */
    if (load_sched()) return 2;
    if (load_scenario()) return 2;
    load_marks();
    printf("PROBE: %s: %d VGGO schedule entries, %d scripted input events, "
           "%d mid-pass IRQ landmarks%s\n",
           refdir, sched_n, events_n, marks_have,
           marks_have ? "" : " (irq_marks.txt missing: coarse replay)");

    apply_events(0);                             /* the state at RESET   */
    sd_boot();
    booted = 1;
    while (!done)
        sd_mainline_frame();

    printf("PROBE: %d frames run, %d compared, %d byte-identical, "
           "%ld mismatched bytes\n",
           (int)g.frame_count, frames_compared, frames_clean, total_bad);
    printf("PROBE: masked separately: %ld bytes in the 6502 hardware stack "
           "$01E1-$01FF (see probe_attract.c)\n", total_stack);
    printf("PROBE: pokey writes %u, earom ctl %u, earom data %u, "
           "irq services %u, CPU resets %u, final loop %d\n",
           pokey_writes, earom_ctl_writes, earom_data_writes, g.irq_count,
           resets, sd_cpu_loop());
    printf("PROBE: RANDOM reads %lu\n", rnd_count);
    if (frames_compared && frames_clean == frames_compared) {
        printf("PROBE PASSED\n");
        return 0;
    }
    printf("PROBE FAILED (%d/%d clean)\n", frames_clean, frames_compared);
    return 1;
}
