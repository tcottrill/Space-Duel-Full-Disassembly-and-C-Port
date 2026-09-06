/* probe_attract.c - Space Duel C port: the attract-mode differential probe.
 *
 * Implements the sd_hw_* seam exactly as tools/oracle.py modeled the
 * hardware (see NOTES_oracle.md - the oracle is the contract), boots the C
 * port, runs attract frames on the oracle's recorded IRQ schedule, and
 * byte-diffs g.vram / g.ram against tests/ref/frame_NNNN.{vram,ram} at
 * every VGGO. Run from c_src\:
 *
 *     tests\probe_attract.exe [frames] [refdir]     (default 600 tests\ref)
 *
 * Exit 0 = every captured frame byte-identical (vram AND ram).
 *
 * IRQ replay: the mainline's frame gate runs IRQ services up to the
 * recorded irq_count for the coming VGGO (tests/ref/vggo_sched.txt), then
 * consumes the $33 bit with the ROM's exact LSR dynamics. Boot-time gate
 * waits (before frame 1's schedule entry applies) run naturally: IRQs
 * until a $33 bit appears. Because the real machine spreads a pass's IRQs
 * THROUGH the pass, the replay also honours four recorded mid-pass sync
 * points (tests/sched/irq_marks.txt, see sd_hw_irq_mark in sd_hw.h) so
 * routines that read per-IRQ cells mid-build see what the ROM's did. What
 * that still cannot express is an IRQ landing INSIDE a routine - e.g.
 * between Fire3's two ANGLE,X reads - so a handful of angle-derived cells
 * can differ. Those are reported, never masked. The ONE masked region is
 * the 6502 stack $01E1-$01FF, counted and printed separately;
 * NOTES_integration.md carries the justification.
 */
#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sd_state.h"
#include "sd_hw.h"
#include "platform/sd_platform.h"    /* plat_sample_* stubs below */

extern void sd_irq(void);            /* irq.c: Irq $8639                  */
extern void sd_boot(void);           /* mainline.c: Poweron game path     */
extern void sd_mainline_frame(void); /* mainline.c: one Start2 pass       */

/* ------------------------------------------------------------------ */
/* oracle schedule + reference dumps                                   */
/* ------------------------------------------------------------------ */

static const char* refdir = "tests\\ref";
static unsigned sched[4096];
static int      sched_n;

/* Mid-pass IRQ sync-point schedule (tests/sched/irq_marks.txt, written by
 * `oracle.py --irq-marks`): the oracle's irq_count at each numbered
 * mainline sync point, per pass.  Same principle as vggo_sched.txt - replay
 * the machine's own recorded IRQ schedule - sampled inside the pass instead
 * of only at the VGGO.  See sd_hw_irq_mark() in sd_hw.h.  Absent file =
 * fall back to the coarse gate-only replay (and say so at startup). */
#define NMARKPT 4
static unsigned marks[NMARKPT][4096];
static int      marks_have;

static void load_marks(void)
{
    FILE* f = fopen("tests\\sched\\irq_marks.txt", "r");
    char line[256];
    unsigned pt, fr, q;
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

/* POKEY RANDOM: the oracle's shared 17-bit LFSR, 8 shifts per read.
 * The read $007F is the port's instruction-path checksum (NOTES_oracle.md
 * section 1), so it is counted and, with SD_PROBE_RND=<file>, logged. */
static uint32_t lfsr = 0x1FFFF;
static unsigned long rnd_count;
static FILE* rnd_log;
uint8_t sd_hw_pokey_random(int which)
{
    (void)which;                             /* both POKEYs share it */
    for (int k = 0; k < 8; k++) {
        uint32_t bit = ((lfsr >> 16) ^ (lfsr >> 11)) & 1u;
        lfsr = ((lfsr << 1) | bit) & 0x1FFFFu;
    }
    rnd_count++;
    if (rnd_log)
        fprintf(rnd_log, "%5u %6lu $%02X\n",
                g.frame_count, rnd_count, (unsigned)(lfsr & 0xFF));
    return (uint8_t)lfsr;
}

uint8_t sd_hw_in0(void)  { return 0x50; }    /* HALT done, self-test off  */
uint8_t sd_hw_in1(uint8_t idx) { (void)idx; return 0x00; }
uint8_t sd_hw_pokey2_optionsw(void) { return 0x00; }
uint8_t sd_hw_pokey1_diffsw(void)   { return 0x00; }

static unsigned pokey_writes, earom_ctl_writes, earom_data_writes;
void sd_hw_pokey_write(int which, uint8_t reg, uint8_t val)
{ (void)which; (void)reg; (void)val; pokey_writes++; }

/* samples.c (linked via sound.c's sd_sample_* hooks) wants the sample
 * seam; the probe has no audio. */
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
void sd_wait_vghalt(void) {}                 /* oracle: never blocks */
/* self-test seam calls: attract holds the self-test switch off, so the
 * loops that use these never run here (probe_selftest.c implements them) */
void sd_wait_3khz(uint8_t n) { (void)n; }
void sd_hw_reset(void) { fprintf(stderr, "PROBE: unexpected CPU reset\n"); exit(3); }

/* Mid-pass sync point: advance to the oracle's recorded irq_count at this
 * exact ROM location, so routines that read per-IRQ cells mid-pass see the
 * same values the ROM's did.  Never runs an IRQ the recorded schedule did
 * not - it only moves some of a pass's IRQs from the frame gate to where
 * the real machine actually took them. */
void sd_hw_irq_mark(int point)
{
    unsigned f = g.frame_count;
    if (!marks_have || point < 0 || point >= NMARKPT || f >= 4096)
        return;
    if (marks[point][f] == 0) return;            /* no sample: leave be */
    while (g.irq_count < marks[point][f]) sd_irq();
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

static int booted;                           /* set once sd_boot returns  */

void sd_wait_frame_gate(void)
{
    /* Boot-time waits (StartThingsRunning's $61-tick EAROM warm-up) run
     * naturally so the IRQ-driven EAROM machine keeps its cadence; the
     * mainline's per-frame gate replays the recorded schedule. */
    if (booted) {
        int next = (int)g.frame_count;       /* 0-based -> sched[frame]   */
        if (next < sched_n)
            while (g.irq_count < sched[next]) sd_irq();
    }
    consume_gate_bit();
}

/* ---- VGGO: the snapshot/compare point ------------------------------ */

static int frames_target = 600;
static int frames_compared, frames_clean, done;
static long total_bad, total_stack;

/* THE ONE DOCUMENTED MASK: $01E1-$01FF, the 6502 hardware stack proper.
 * The C port has no 6502 stack - subroutine linkage lives on the C stack -
 * so this region holds the oracle's return addresses and PHA-saved
 * registers, which the C port cannot and should not reproduce.  The ROM
 * sets SP = $FE at reset ($8040 LDX #$FE / TXS) and the stack grows down;
 * measured over all 34 captured frames it reaches no lower than $01EF.
 *
 * The mask deliberately does NOT cover the whole page.  Page 1 below this
 * is DATA, not stack, and the game reads it back constantly - the initials
 * table ($0122 $0122), the EAROM buffer and its state machine ($016D $016D,
 * EACS $018D ... PLAYTIME $0196), the bookkeeping counters ($0197 $0197,
 * $019B $019B, $019F $019F, $01AF $01AF) and THRENG $01E0, the
 * highest data alias in spaceduel_defines.asm.  irq.c reads ONTIME $018E
 * every four seconds; mainline's SetUpInitialsHigh writes $0118,Y at boot.
 * All of that is COMPARED, and it currently matches byte-for-byte - which
 * is what proves earom.c and the initials code correct.  Masking the whole
 * page (as this probe first did) would have hidden any future regression
 * there, so the boundary sits just above THRENG.
 *
 * Masked bytes are counted and reported separately, never hidden, and do
 * NOT count against a frame being byte-identical.  See NOTES_integration.md. */
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

/* Diagnostic only: SD_PROBE_DUMP=<dir> writes the C port's own vram/ram for
 * every compared frame, so diffs can be analysed offline.  Never affects
 * the comparison. */
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
        else printf("  frame %d: %ld mismatched bytes"
                    " (+%ld 6502-stack-page bytes, masked)\n",
                    frame, bad, stack);
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
    {   const char* rp = getenv("SD_PROBE_RND"); /* diagnostic LFSR log */
        if (rp) rnd_log = fopen(rp, "w"); }
    if (load_sched()) return 2;
    load_marks();
    printf("PROBE: %d VGGO schedule entries, %d mid-pass IRQ landmarks%s\n",
           sched_n, marks_have,
           marks_have ? "" : " (tests\\sched\\irq_marks.txt missing:"
                             " coarse gate-only IRQ replay)");

    sd_boot();
    booted = 1;
    while (!done)
        sd_mainline_frame();

    printf("PROBE: %d frames run, %d compared, %d byte-identical, "
           "%ld mismatched bytes\n",
           (int)g.frame_count, frames_compared, frames_clean, total_bad);
    printf("PROBE: masked separately: %ld bytes in the 6502 hardware stack "
           "$01E1-$01FF (the C port has no 6502 stack). Page-1 DATA below "
           "$01E1 - initials, EAROM buffer/state, bookkeeping - is compared, "
           "not masked. See NOTES_integration.md)\n", total_stack);
    printf("PROBE: pokey writes %u, earom ctl %u, earom data %u, "
           "irq services %u\n",
           pokey_writes, earom_ctl_writes, earom_data_writes, g.irq_count);
    printf("PROBE: RANDOM reads %lu\n", rnd_count);
    if (rnd_log) fclose(rnd_log);
    if (frames_compared && frames_clean == frames_compared) {
        printf("PROBE PASSED\n");
        return 0;
    }
    printf("PROBE FAILED (%d/%d clean)\n", frames_clean, frames_compared);
    return 1;
}
