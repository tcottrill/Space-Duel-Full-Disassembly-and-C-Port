/* app_loop.c - Space Duel C port: the real application loop.
 *
 * This file is linked ONLY into the game binaries (sd_win.exe and the
 * headless sd_selftest.exe).  The differential probe links its own copy of
 * the sd_hw_* seam (tests/probe_attract.c), which models the ORACLE's
 * hardware, not a cabinet - the two must never be linked together.
 *
 * What lives here:
 *
 *  (a) the sd_hw_* seam (sd_hw.h) over the platform contract
 *      (platform/sd_platform.h): the IN0/IN1 port-bit encodings and their
 *      polarities, the two POKEYs (c012294.c: RANDOM, the option switches on
 *      ALLPOT, and the sound the ROM programs into them), the ER2055 EAROM
 *      (er2055.c) and its NVRAM image, the OUT1 latch, and the AVG frame
 *      boundary;
 *  (b) machine time: the 246.09 Hz IRQ driven off the wall clock, the
 *      $33 frame gate and the $401F VG-HALT wait - and, per IRQ, the
 *      POKEY clock feed and one tick of rendered audio;
 *  (c) sd_app_init / sd_app_step / sd_app_exit, the hooks the Windows
 *      backend's WinMain calls.
 *
 * Hardware truth (which bit means what, and which way round it reads) lives
 * HERE.  Key bindings are backend policy (platform/windows/plat_win.c).
 * See NOTES_playable.md for the evidence behind every bit.
 *
 * Modeled on the finished Omega Race port's app_loop.c, with one structural
 * difference forced by the ROM: Omega Race's mainline is a tick loop the app
 * drives, while Space Duel's Start2 loop blocks on TWO hardware polls
 * ($401F BIT HALT / BVC and $4027 LSR $33 / BCC) in the middle of its pass.
 * So sd_mainline_frame() runs to completion inside one sd_app_step() and the
 * waits do the real waiting, exactly as the 6502 did.  Frame pacing is not
 * a number written down anywhere: it EMERGES from max(frame gate, AVG draw
 * time), which is what DESIGN.md's timing model asks for.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* The chip models come first: sd_state_defs.h aliases the ROM's zero-page
 * cells SKCTL ($xx) and POTGO ($xx) as macros - the ROM reused the chip
 * register names for scratch - and c012294.h's struct has fields of those
 * names.  Parsed before the aliases exist, the struct is fine; this file
 * never touches those fields directly (c012294.c does not include
 * sd_state.h at all). */
#include "c012294.h"   /* cycle audio shares the chip's hardware counters */
#include "er2055.h"

#include "sd_state.h"
#include "sd_hw.h"
#include "selftest.h"  /* sd_cpu_loop(): is the CPU parked in a test loop */
#include "avg.h"
#include "samples.h"
#include "platform/sd_platform.h"

/* module entry points (mainline.h / irq.c) */
extern void sd_irq(void);            /* irq.c:      Irq $8639             */
extern void sd_boot(void);           /* mainline.c: Poweron game path     */
extern void sd_mainline_frame(void); /* mainline.c: one Start2 pass       */

/* ------------------------------------------------------------------ */
/* constants                                                           */
/* ------------------------------------------------------------------ */

/* Machine time.  The board's IRQ is 1.512 MHz / 6144 = 246.09375 Hz
 * (AAE drivers/bwidow.cpp: timer_set(TIME_IN_HZ(246)); the exact divisor is
 * the one NOTES_oracle.md's model uses and the one the oracle's 2855 IRQs
 * over 600 frames were generated with). */
#define SD_IRQ_HZ      (1512000.0 / 6144.0)   /* 246.09375 Hz            */
#define SD_TICK_MS     (1000.0 / SD_IRQ_HZ)   /* 4.063492 ms per IRQ     */
#define SD_CYC_PER_MS  1512.0                 /* 6502 cycles per ms      */
#define SD_STALL_MS    100.0                  /* catch-up clamp          */

/* The POKEYs.  Both chips share the 6502's 12.096 MHz / 8 = 1.512 MHz
 * clock (spaceduel_defines.asm; AAE bwidow.cpp's pokey_interface), so one
 * CPU cycle is one POKEY cycle and an IRQ period is exactly 6144 of them.
 * c012294.h's time model: the chip charges nothing on its own, the host
 * feeds it machine time - one IRQ period per IRQ (machine_pump), and a
 * flat SD_RANDOM_READ_COST before each un-annotated game RANDOM read,
 * standing in for the 6502 cycles the read and its neighbours take (the
 * same 64 the Asteroids Deluxe host charges).  Both chips are advanced
 * from the same places by the same amounts. Read costs are deducted from
 * the next IRQ interval, not added on top of it, so audio and machine
 * time never drift apart. */
#define SD_POKEY_HZ           1512000u
#define SD_IRQ_POKEY_CYCLES   6144u          /* 1512000 / 246.09375       */
#define SD_RANDOM_READ_COST   64u
#define SD_AUDIO_RATE         44100          /* render/output rate, Hz    */

/* Beam space.  avg.c emits segments in AVG units around the beam CENTRE
 * (+x right, +y up).  The platform window is the AAE spacduel screen
 * rectangle x 0..520, y 0..395, y up (drivers/bwidow.cpp
 * AAE_DRIVER_SCREEN(1024,768, 0,520, 0,395)), and AAE maps AVG units to it
 * 1:1 with the beam starting at the rectangle's centre (aae_avg.cpp
 * xcenter/ycenter).  So the mapping is a pure translation - no scale, no
 * flip: the AVG delta LSB IS one unit of this window. */
#define BEAM_CX        260.0f                 /* 520 / 2                 */
#define BEAM_CY        197.5f                 /* 395 / 2                 */

/* IN0 ($0800) idle byte, low nibble + d4/d5.
 *
 * THE POLARITY TRAP (NOTES_oracle.md section 2): the coin inputs d2-d0 and
 * the slam input d3 are ACTIVE LOW.  coins.c's L741C reads a coin bit of 1
 * as "coin ABSENT", and L7442 reads d3 of 0 as "slam switch TRIPPED" (which
 * reloads the pre-coin timer $0025 to $F0 every IRQ and wipes the coin
 * status cells $2A-$2F, so no credit can ever accumulate).  The oracle -
 * and therefore the probe - idles these bits LOW on purpose, so attract
 * runs forever and coins are impossible.  A cabinet must idle them HIGH.
 *   d5 diag step  : active low (AAE input_ports_spacduel: PORT_BITX(0x20,
 *                   IP_ACTIVE_LOW, IPT_SERVICE, "Diagnostic Step"))
 *   d4 self-test  : active low, 0 = test mode; idle 1
 *   d3 slam       : 1 = not tripped
 *   d2-d0 coins   : 1 = no coin in the mech
 * d6 (VG HALT) and d7 (3 kHz clock) are synthesized per read, below. */
#define SD_IN0_IDLE    0x3Fu

/* EAROM: the ER-2055 on this board is 64 x 8 (MAME atari_vg_earom /
 * AAE EaromRead/EaromWrite/EaromCtrl model 64 addressable bytes; the ROM
 * stores whole bytes - packed BCD score bytes and glyph-coded initials -
 * through EADAL, see NOTES_earom.md section 1).  The NVRAM blob is that
 * image, raw, nothing else. */
#define SD_EAROM_SIZE  64u

/* ------------------------------------------------------------------ */
/* input: plat_inputs -> the hardware's port bytes                     */
/* ------------------------------------------------------------------ */

static plat_inputs cur_in;      /* sampled once per displayed frame */

/* synthesized IN0 bits, defined with the machine-time block below */
static int in0_halt(void);      /* d6: VG HALT   */
static int in0_clock(void);     /* d7: 3 kHz     */

/* IN0 ($0800).  See SD_IN0_IDLE above for the polarity argument.
 *
 * Coin mech order: coins.c indexes the mechs X = 2,1,0 onto IN0 d0,d1,d2,
 * where X=0 is the left mech (always one unit-coin), X=1 the centre mech
 * (ZMINE d4, DIP "Coin A" x1/x2) and X=2 the right mech (ZMINE d2-d3, DIP
 * "Coin B" x1/x4/x5/x6).  AAE/MAME label d0 COIN1 and d1 COIN2, so:
 *   coin1 (key 5) -> d0, coin2 (key 6) -> d1, coin3 (key 8) -> d2.
 * With the factory DIPs all three mechs are worth one credit each.
 *
 * d4 (self-test) has two sources: the cabinet switch line (`test`, key 9,
 * held) and the host's F2 toggle (`diag`, edge-detected here into
 * test_latch - MAME's service-mode key works the same way).  Low from the
 * game -> AllStopPlease's bookkeeping screen; low at power-on -> the full
 * diagnostics (selftest.c). */
static int test_latch;          /* F2 toggle state                       */
static int diag_prev;           /* last sampled F2, for the edge         */

uint8_t sd_hw_in0(void)
{
    uint8_t v = (uint8_t)SD_IN0_IDLE;

    if (cur_in.coin1)     v = (uint8_t)(v & ~0x01u);  /* right mech  (X=2) */
    if (cur_in.coin2)     v = (uint8_t)(v & ~0x02u);  /* centre mech (X=1) */
    if (cur_in.coin3)     v = (uint8_t)(v & ~0x04u);  /* left mech   (X=0) */
    /* d3 slam: no host control asserts it; a cabinet's tilt switch would. */
    if (cur_in.test || test_latch)
                          v = (uint8_t)(v & ~0x10u);  /* d4, active low    */
    if (cur_in.diag_step) v = (uint8_t)(v & ~0x20u);  /* d5, active low    */

    if (in0_halt())  v |= 0x40u;                  /* d6: VG HALT       */
    if (in0_clock()) v |= 0x80u;                  /* d7: 3 kHz clock   */
    return v;
}

/* IN1 ($0900-$0907): one switch pair per address, ACTIVE HIGH, tested with
 * BIT (bit 7 = the N flag, bit 6 = the V flag).  Idle is 0x00 - which is
 * what the oracle used and what tests/ref was captured under, so this map
 * cannot regress the probe.
 *
 * Evidence for each bit (C port call site + AAE SDControls, which is the
 * hardware's own decode - drivers/bwidow.cpp READ_HANDLER(SDControls)):
 *
 *  $0900 HYPSW  d7 shield/hyperspace P1  objects.c twin_game_both_shields()
 *               d6 fire P1               objects.c fire_ships_torpedos()
 *  $0901        d7/d6 the same for P2    (same call sites, index x = 1)
 *  $0902 ROTL   d7 rotate left P1        irq.c sd_hw_in1(2+x) & 0x80
 *               d6 rotate right P1       irq.c sd_hw_in1(2+x) & 0x40
 *  $0903        d7/d6 the same for P2
 *  $0904 STRT1  d7 thrust P1             objects.c move_ship() NEG(a) test
 *               d6 START                 mainline.c check_for_start_end()
 *  $0905 OPTNA1 d7 thrust P2             objects.c dorig3() sd_hw_in1(4+x)
 *               d6 "selling players"     mainline.c _12: TEMP5-- when set
 *  $0906 GAMSEL d7 SELECT GAME           mainline.c _16 SAVBOT debounce
 *               d6 2-coin-minimum option mainline.c _80
 *  $0907 CABERE d7 cocktail cabinet      mainline.c uses_temp1_temp11()
 *               d6 caberet cabinet       mainline.c nxtstep()
 *
 * The two d6 option lines on $0905/$0906 are cabinet jumpers, not buttons;
 * both read 0 = the standard upright wiring.  $0907 = 0x00 = upright.
 *
 * Player 2's switches read 0: plat_inputs has no P2 controls (see the open
 * issues in NOTES_playable.md).  In game 3 the ROM gives ONE player both
 * ships through $0900, so that game is fully playable one-handed. */
uint8_t sd_hw_in1(uint8_t idx)
{
    uint8_t v = 0x00;

    switch (idx & 7u) {
    case 0:                                          /* HYPSW  - player 1 */
        if (cur_in.shield)       v |= 0x80u;
        if (cur_in.fire)         v |= 0x40u;
        break;
    case 1: break;                                   /*          player 2 */
    case 2:                                          /* ROTL   - player 1 */
        if (cur_in.rotate_left)  v |= 0x80u;
        if (cur_in.rotate_right) v |= 0x40u;
        break;
    case 3: break;                                   /*          player 2 */
    case 4:                                          /* STRT1             */
        if (cur_in.thrust)       v |= 0x80u;
        if (cur_in.start1)       v |= 0x40u;
        break;
    case 5: break;                    /* P2 thrust d7; d6 option, off      */
    case 6:                           /* GAMSEL d7; d6 option, off         */
        /* The cabinet has ONE start button plus a SELECT button; AAE
         * labels this line START2, the ROM calls it GAMSEL and uses it to
         * step through the four games.  Both host keys reach it. */
        if (cur_in.game_select || cur_in.start2) v |= 0x80u;
        break;
    case 7: break;                    /* CABERE: 0x00 = upright cabinet    */
    default: break;
    }
    return v;
}

/* ------------------------------------------------------------------ */
/* the two POKEYs ($1000 POKEY1, $1400 POKEY2)                         */
/* ------------------------------------------------------------------ */

/* Two real chips (c012294.c - the cycle-stepped POKEY core shared with the
 * AAE and Atari 800 trees, its polys MAME 0.286's true LFSRs; a verbatim
 * copy, see README.md).  The translated ROM drives them register for register
 * through sd_hw_pokey_write - the script engine's AUDF/AUDC stores every
 * IRQ, Inisou's SKCTL 0-then-7, the self-test's beeps and POTGO strobes -
 * and reads RANDOM and ALLPOT back from them.  pokey[0] is POKEY1
 * ($1000, sound + the difficulty DIPs on its pot pins), pokey[1] is
 * POKEY2 ($1400, sound + the coinage DIPs). */
static ad_pokey pokey[2];
static uint32_t pokey_audio_clock_hz = SD_POKEY_HZ;
static uint32_t pokey_read_cycles;

static void pokey_init(void)
{
    pokey_read_cycles = 0;
    ad_pokey_init(&pokey[0], pokey_audio_clock_hz, SD_AUDIO_RATE);
    ad_pokey_init(&pokey[1], pokey_audio_clock_hz, SD_AUDIO_RATE);
    ad_pokey_set_cycle_audio(&pokey[0], true);
    ad_pokey_set_cycle_audio(&pokey[1], true);
    ad_pokey_set_quiet_skip(&pokey[0], plat_pokey_skip() != 0);
    ad_pokey_set_quiet_skip(&pokey[1], plat_pokey_skip() != 0);
    ad_pokey_set_allpot(&pokey[0], plat_dsw_pokey1());
    ad_pokey_set_allpot(&pokey[1], plat_dsw_pokey2());
}

/* Register writes.  reg is masked to the chip's 16 registers because the
 * ROM's power-on clear loop walks X = $00..$FF through STA POKEY,X (so
 * every register, SKCTL and POTGO included, sees sixteen zeros).  A POTGO
 * strobe re-samples the DIP bank onto the chip's pot pins first: the pins
 * are live inputs, and the platform is the one that owns the switches. */
void sd_hw_pokey_write(int which, uint8_t reg, uint8_t val)
{
    ad_pokey *p = &pokey[which & 1];

    reg = (uint8_t)(reg & 0x0Fu);
    if (reg == W_POTGO)
        ad_pokey_set_allpot(p, (which & 1) ? plat_dsw_pokey2()
                                           : plat_dsw_pokey1());
    ad_pokey_write(p, reg, val);
}

/* Option switches, through the chips' pot scanner.  Routing: POKEY1
 * ALLPOT ($1008) = DSW0 = lives/difficulty/language/bonus, read by Gtoptn
 * $76DB; POKEY2 ALLPOT ($1408) = DSW1 = coinage/multipliers/bonus coins,
 * read by CheckForStartEnd _12.  That is the AAE pokey_interface allpot
 * wiring ({ input_port_1_r, input_port_2_r }) and it agrees with the ROM:
 * with the factory bytes the EOR corrections in the ROM land on the
 * factory settings (see NOTES_playable.md for the arithmetic).
 *
 * Every one of the ROM's reads is the LDA right after an STA to the
 * chip's POTGO (Gtoptn, _12, the self-test's Optn2/sub_8f43/coin screen
 * - checked at all six call sites), so the read always lands inside the
 * scan c012294.c's ALLPOT model is running, where it answers with the
 * still-counting-line mask: the DIP byte, as the board straps it.  The
 * post-scan 0 that Asteroids Deluxe's PKYTST expects never comes into it
 * here - no read is far enough from its strobe. */
uint8_t sd_hw_pokey1_diffsw(void)   { return ad_pokey_read(&pokey[0], R_ALLPOT); }
uint8_t sd_hw_pokey2_optionsw(void) { return ad_pokey_read(&pokey[1], R_ALLPOT); }

/* RANDOM ($100A / $140A), from the real polynomial.  The game's reads are
 * not cycle-annotated, so this host moves BOTH chips a flat
 * SD_RANDOM_READ_COST before each one (c012294.h's time model; the chip
 * itself charges nothing per read, and machine time passes for both
 * chips whichever one the ROM strobes).  Together with the IRQ feed in
 * machine_pump() that is what makes consecutive reads differ - Stest4
 * flags a chip whose RANDOM sits still over six reads.
 *
 * Determinism: unlike the old free-running LFSR (seeded from the wall
 * clock), the sequence after the ROM's SKCTL reset in Inisou is now a
 * function of machine time alone, which is what the real chip does too -
 * on a cabinet the attract sequence is fixed by the same cycle counts,
 * and only the players' timing varies a game.  The probes keep the
 * oracle's LFSR in their own seam; nothing here touches them. */
uint8_t sd_hw_pokey_random(int which)
{
    ad_pokey_advance(&pokey[0], SD_RANDOM_READ_COST);
    ad_pokey_advance(&pokey[1], SD_RANDOM_READ_COST);
    pokey_read_cycles += SD_RANDOM_READ_COST;
    return ad_pokey_read(&pokey[which & 1], R_RANDOM);
}

/* ------------------------------------------------------------------ */
/* outputs                                                             */
/* ------------------------------------------------------------------ */

/* OUT1 ($0C00): d0/d1 EM coin counters, d4/d5 start lamps (lockout latch
 * $31 supplies them), d6/d7 the cocktail X/Y flip lines - the ROM ORs in
 * $C0 on an UPRIGHT cabinet ("ELSE FLIP FOR COCKTAIL NORMAL", $6911), i.e.
 * $C0 is the normal orientation and the renderer must NOT act on it (AAE
 * and MAME both ignore these bits for exactly that reason; the board has no
 * beam-flip hardware - cocktail flipping is done in the display list by
 * UPDOWN, which the ROM already applies). */
void sd_hw_out1(uint8_t v)
{
    g.out1 = v;
    plat_leds_out(v);
}

/* $0D80: holds the AVG in reset.  Our AVG only ever runs inside
 * sd_hw_vggo(), so there is no running state to stop; the one call site is
 * the power-on path before anything has been drawn. */
void sd_hw_vgreset(void) { }

/* Probe-only mid-pass IRQ sync point (sd_hw.h): it exists so a probe can
 * replay the ORACLE's recorded irq_count at four exact ROM locations.  On a
 * cabinet the IRQs simply land where they land - real elapsed time already
 * spreads them through the pass - so this is a no-op here, by design. */
void sd_hw_irq_mark(int point) { (void)point; }

/* ------------------------------------------------------------------ */
/* EAROM (ER-2055) + NVRAM                                             */
/* ------------------------------------------------------------------ */

/* A real ER2055 (er2055.c - the Asteroids Deluxe port's translation of
 * MAME 0.286's er2055_device; a verbatim copy, see README.md) behind the
 * board's three latches.  MAME's bwidow.cpp wires this board's EACTL to
 * the chip exactly as asteroid.cpp does - the decode er2055.c carries:
 *   bit 3 EACE -> CS1 (CS2 tied high)      bit 2 EAC1 -> C1, inverted
 *   bit 1 EAC2 -> C2                       bit 0 EACK -> the clock
 * so earom.c's control codes mean, on the chip: $0E = C2 alone = ERASE
 * (the cell goes to $FF), $0C = neither = WRITE (the cell is ANDed with
 * the data latch - which is why the ROM erases first), $08/$09/$08 = C1
 * alone with a clock pulse = READ (the falling edge latches the cell),
 * and every operation fires only on a genuine transition while selected.
 * A read can therefore never corrupt a cell, and a same-value rewrite of
 * the latch is a no-op - both as the part behaves.  See NOTES_earom.md.
 *
 * Persistence: the 64-byte array IS the sd_c.nv blob, raw, no header
 * (unchanged from the previous model: a written cell holds its data
 * byte either way).  A missing/short/absent file leaves the image all
 * zeroes, which is precisely a fresh part as this board ships it (MAME's
 * ROMREGION_ERASE00 for the region) - the boot path NOTES_earom.md §5
 * proves (both checksums are 0, so they match, and CopyFromBufferBack
 * reseeds the four 500-point top scores).  No special-casing anywhere. */
static ad_er2055 earom;

uint8_t sd_hw_earom_read(void)              { return ad_er2055_data(&earom); }
void    sd_hw_earom_write(uint8_t off, uint8_t v)
                                            { ad_er2055_set_addr_data(&earom, off, v); }

void sd_hw_earom_ctl(uint8_t v)
{
    ad_er2055_control(&earom, v);
    /* The $00 deselect that ends a pulse is the natural flush point
     * (NOTES_earom.md §6).  The state machine issues one every 16th IRQ
     * even when idle, so a finished byte reaches the disk within ~65 ms -
     * a power cut mid-batch then looks like a bad checksum, which the ROM
     * already handles by zeroing that batch.  `dirty` is the chip's own
     * "an erase or write changed rom[]" flag. */
    if (v == 0x00u && earom.dirty) {
        if (plat_nvram_write(earom.rom, sizeof earom.rom) == 0)
            earom.dirty = false;
    }
}

static void earom_load(void)
{
    ad_er2055_init(&earom);              /* zero-filled, latch cleared */
    ad_er2055_control(&earom, 0);        /* the board's reset line (MAME
                                          * bwidow's machine reset); a
                                          * no-op on a fresh chip, kept
                                          * so the sequence reads as the
                                          * hardware's */
    if (plat_nvram_read(earom.rom, sizeof earom.rom) != 0)
        memset(earom.rom, 0, sizeof earom.rom);      /* fresh blank part */
    earom.dirty = false;
}

/* ------------------------------------------------------------------ */
/* POKEY audio: one IRQ tick of rendered sound, pushed to the stream   */
/* ------------------------------------------------------------------ */

/* advance() produces cycle audio before each IRQ's new register writes.
 * Drain the completed interval here; writes affect subsequent samples.
 * One interval is 179.2 samples at native speed, 183.75 at fps_lock=60.
 * The integer remainder uses the same clock as the core's integrator.
 * Both chips are summed with saturation into the board's mono output.
 *
 * Synthetic time renders nothing: the power-on fast-forward (boot_fast)
 * runs 1.6 s of IRQs in an instant, and a stream fed that burst would
 * either flush it or carry it as latency for the rest of the run.  The
 * headless self-test is synthetic throughout and has no stream to
 * choke, so there every tick is pushed and counted. Discarded boot
 * audio is still drained, keeping the core's queue empty. */
static int     audio_live;             /* plat_audio_open succeeded      */
static uint64_t audio_tick_phase;     /* exact sample fraction, in chip Hz */
static unsigned audio_underrun_frames;
static int16_t audio_buf[2][512];      /* STREAM_BLOCK_FRAMES is the cap */

static int    fast_clock;              /* 1 = synthetic time (see below)  */
static int    selftest_mode;           /* set by the headless main below  */
static double mach_tick_ms;            /* scaled ms per IRQ (see below)   */

static void render_push_audio_tick(void)
{
    int n, i;

    audio_tick_phase += (uint64_t)SD_AUDIO_RATE * SD_IRQ_POKEY_CYCLES;
    n = (int)(audio_tick_phase / pokey_audio_clock_hz);
    audio_tick_phase %= pokey_audio_clock_hz;
    if (n > (int)(sizeof audio_buf[0] / sizeof audio_buf[0][0]))
        n = (int)(sizeof audio_buf[0] / sizeof audio_buf[0][0]);   /* defensive */
    if (n <= 0) return;

    for (i = 0; i < 2; ++i) {
        int got = ad_pokey_audio_read(&pokey[i], audio_buf[i], n);
        if (got < n) {
            audio_underrun_frames += (unsigned)(n - got);
            memset(audio_buf[i] + got, 0, (size_t)(n - got) * sizeof audio_buf[i][0]);
        }
    }
    /* Drain fast-forwarded/disabled audio too, so it cannot build a backlog. */
    if (!audio_live || (fast_clock && !selftest_mode)) return;
    for (i = 0; i < n; i++) {
        int v = (int)audio_buf[0][i] + (int)audio_buf[1][i];
        if (v > 32767) v = 32767; else if (v < -32768) v = -32768;
        audio_buf[0][i] = (int16_t)v;
    }
    plat_audio_push(audio_buf[0], n);
}

static void audio_open(void)
{
    audio_tick_phase = 0;
    audio_underrun_frames = 0;
    audio_live = plat_audio_open(SD_AUDIO_RATE) == 0;
    if (!audio_live)
        fprintf(stderr, "plat_audio_open failed; continuing without POKEY sound\n");
}

/* ------------------------------------------------------------------ */
/* machine time                                                        */
/* ------------------------------------------------------------------ */

/* Two clock modes share one code path:
 *
 *  - REAL (the cabinet): now = plat_now_ms(), and an idle spins/sleeps.
 *  - SYNTHETIC: now is a variable this file advances by exactly the amount
 *    a wait needs.  Used for (1) the power-on sequence, whose $61 EAROM
 *    warm-up gate ticks are 1.58 s of hardware time that would otherwise
 *    be 1.58 s of unpainted window, and (2) the headless self-test, which
 *    runs the same loop as fast as the CPU allows.
 *
 * The IRQ dynamics are identical in both modes - only the source of "now"
 * changes - so the self-test measures the model's own frame rate. */
/* fast_clock itself is declared with the audio block above */
static double fast_ms;             /* the synthetic 'now'                 */
static double last_ms = -1.0;      /* previous sample of 'now'            */
static double irq_acc;             /* machine ms not yet spent on an IRQ  */
static double vg_busy_until;       /* clock_ms() at which HALT goes high  */

/* fps lock: underclock the whole board so the $33 frame gate lands on a
 * PC monitor's refresh rate instead of the hardware's 61.5234 Hz (which
 * beats against a 60 Hz panel as a dropped frame every ~0.65 s).  The
 * scale multiplies BOTH hardware-time sources - the IRQ tick and the AVG
 * draw window - exactly as if the 12.096 MHz crystal were slower, so the
 * machine stays internally consistent: gameplay, timers, sound tempo and
 * the gate all slow together (2.48% at fps_lock=60).  0 = authentic.
 * The headless self-test and the probes never call the setter, so all
 * oracle-facing timing stays authentic. */
/* mach_tick_ms is declared with the audio block above; it starts at
 * SD_TICK_MS (set in sd_app_init) and the setter below rescales it. */
static double mach_scale   = 1.0;          /* scaled/authentic time ratio */

void sd_app_set_fps_lock(double fps)
{
    mach_scale   = (fps > 0.0) ? (SD_IRQ_HZ / 4.0) / fps : 1.0;
    mach_tick_ms = SD_TICK_MS * mach_scale;
    /* The audio sample clock must follow the same board underclock. */
    pokey_audio_clock_hz = (uint32_t)(SD_POKEY_HZ / mach_scale + 0.5);
    if (!pokey_audio_clock_hz) pokey_audio_clock_hz = 1;
}

static double clock_ms(void) { return fast_clock ? fast_ms : plat_now_ms(); }

/* ---- dropped frames: the cabinet's missed frame ------------------------
 * A vector monitor is lit only while the AVG draws.  Through the attract
 * demo a mainline pass overruns the frame gate - 5 or 6 IRQ periods, 20
 * to 24 ms, on most passes - and the tube's afterglow carries the picture
 * across those gaps.  About seven times per attract sequence (measured:
 * 7 passes in 3600 headless frames, all in the demo's opening seconds,
 * and 6 in the oracle's 1500) a pass runs to SEVEN periods, 28 ms, and
 * that one is what the user sees on the real machine: a single black
 * frame.  A window that presents on every VGGO and then holds the frame
 * never shows it.
 *
 * The event is exact, not a time threshold: a pass on which the machine
 * spends >= dropped_irqs (7) IRQ periods between one VGGO and the next.
 * 5- and 6-IRQ passes (1476 and 516 of the 3600) can never fire it.  A
 * 60 Hz presenter that blanked every refresh no VGGO reached was tried on
 * 2026-09-13 and blanked 566 of them per attract - the demo really does
 * run at 41.7-50 fps, so the eye and the phosphor, not a raster tick,
 * decide what counts as a missed frame.
 *
 * Timing, the tube's own: the blank goes up when the AVG finishes drawing
 * this pass's list (vg_busy_until, ~17 ms in) and comes down at the next
 * VGGO (~28 ms), 11 ms of dark.  That needs the pass's length BEFORE it
 * is spent, and sd_hw_list_done() has it: the ticks are floor(owed + the
 * build's cost + the next pass's pre) plus whatever the gate adds (never
 * less), all known there - exact on every one of the 7 events, no false
 * positives (2026-09-13).  A fallback in the idle loop - six IRQs already
 * run since the VGGO and the machine waiting for a seventh - covers a
 * pass with no fit (it can only show ~4 ms of black, but it keeps the
 * count honest).  NOTHING is drawn on the blank: black with the phosphor
 * off (the default), the decaying afterglow with it on.  An optional
 * hold (dropped_frame_hold_ms) keeps the blank up past the next VGGO,
 * delaying that frame's present - 0 by default; a full-refresh hold was
 * the user's first live look and read as "a little too much black".
 * Only the host present moves; the machine clock, the IRQ schedule, the
 * $33 gate and the AVG busy window are untouched, and the probes (their
 * own seam) never see any of this.  One present per event, never two in
 * a refresh (the fault of the rolled-back 2026-09-03 attempt).  No
 * presents at all during a CPU restart. */
static int    dropped_irqs = 7;      /* passes this long blank; 0 = never */
static double hold_ms;               /* blank kept up past the next VGGO  */
static unsigned irq_at_vggo;         /* g.irq_count at the last VGGO      */
static double blank_at = -1.0;       /* clock_ms() to show this pass's
                                      * blank (predicted); -1 = none      */
static double blank_until = -1.0;    /* clock_ms() the hold ends          */
static int    blank_shown;           /* this pass's blank is already up   */
static int    frame_pending;         /* a capture waiting for the hold    */
static int    booting;               /* inside sd_boot(): no presents     */
static int    ref_events, ref_dropped;         /* per status second       */
static long   ref_events_total;                /* since start (selftest)  */

/* ---- test mode: the steady flicker of a 44 fps screen -------------------
 * The bookkeeping screen's list takes 22.65 ms to draw and the ROM waits
 * on HALT, so it runs at exactly 44.15 fps (the user's "44" from the
 * cabinet) with the beam busy the whole period - no dark gap, so the
 * dropped-frame event above can never fire, and a window holding each
 * frame shows a rock-steady picture where the tube shows a rock-steady
 * flicker: every spot is re-lit once per 22.65 ms and fades in between.
 * The attract demo's 6-IRQ stretches re-light each spot every 24 ms, the
 * same thing physically, yet the eye passes them: large bright static
 * text shows flicker, dim moving objects hide it, and (the user's own
 * rule) a short dip to 41 fps is hard to see where a long stretch is
 * not.  No single physical rule separates the two, so this is keyed on
 * what the ROM is doing: while the CPU is parked in a test loop
 * (sd_cpu_loop() != SD_LOOP_START2) the picture is presented the way a
 * raster display or AAE shows a vector game - at the panel's refresh
 * rate ([main] refresh_hz, the display's own by default), each tick
 * showing the newest VGGO if one arrived since the previous tick and
 * NOTHING (plat_video_blank) otherwise: ~16 blanks/s at 44 fps in a
 * near-steady pattern.  Frankly an approximation ("I hate to fake it"),
 * kept out of the game and attract, where it would blank ~20 times a
 * second through the demo. */
static double refresh_ms;            /* panel period; 0 = no raster mode  */
static double next_refresh = -1.0;   /* clock_ms() of the next tick       */
static int    frame_fresh;           /* a VGGO captured since the tick    */
static int    ref_blanks;            /* per status second                 */
static long   ref_blanks_total;      /* since start (selftest)            */

void sd_app_set_refresh(double hz)
{
    refresh_ms   = (hz > 0.0) ? 1000.0 / hz : 0.0;
    next_refresh = -1.0;
}

static int test_raster(void)
{
    return refresh_ms > 0.0 && sd_cpu_loop() != SD_LOOP_START2;
}

void sd_app_set_dropped_frame(int irqs, double hold)
{
    dropped_irqs = irqs > 0 ? irqs : 0;
    hold_ms      = hold > 0.0 ? hold : 0.0;
}

static void show_blank(void)
{
    plat_video_blank();
    blank_shown = 1;
    blank_at    = -1.0;
    blank_until = clock_ms() + hold_ms;   /* after a vsynced swap */
}

/* Called wherever the machine waits for time. */
static void presenter_poll(void)
{
    double now;

    if (booting) return;             /* a CPU restart draws nothing */
    now = clock_ms();
    if (test_raster()) {             /* test mode: the panel's own tick */
        if (next_refresh < 0.0) next_refresh = now + refresh_ms;
        if (now < next_refresh) return;
        if (frame_fresh) {
            plat_video_present();
        } else {
            plat_video_blank();
            ref_blanks++;
            ref_blanks_total++;
        }
        frame_fresh = 0;
        next_refresh += refresh_ms;
        now = clock_ms();            /* a vsynced swap may have blocked */
        if (next_refresh < now) next_refresh = now + refresh_ms;
        return;
    }
    next_refresh = -1.0;             /* the game: rearm for next time */
    if (dropped_irqs > 0 && !blank_shown) {
        if (blank_at >= 0.0 && now >= blank_at) {      /* the tube just
                                                        * went dark      */
            show_blank();
            return;
        }
        if (g.irq_count - irq_at_vggo >= (unsigned)(dropped_irqs - 1)) {
            show_blank();            /* fallback: the 7th tick is next */
            return;
        }
    }
    if (frame_pending && now >= blank_until) {
        plat_video_present();
        frame_pending = 0;
    }
}

/* Absorb elapsed time and run every IRQ it bought.  Returns how many ran.
 * The stall clamp is Omega Race's: a debugger break, a dragged window or a
 * laptop resume must not dump a thousand IRQs into one frame. */
static int machine_pump(void)
{
    double now = clock_ms();
    int n = 0;

    if (last_ms < 0.0) last_ms = now;
    irq_acc += now - last_ms;
    last_ms = now;
    if (irq_acc > SD_STALL_MS) irq_acc = SD_STALL_MS;

    while (irq_acc >= mach_tick_ms) {
        irq_acc -= mach_tick_ms;
        /* RANDOM accesses already spent part of this interval. Charging a
         * full interval again makes cycle audio outrun playback. */
        uint32_t spent = pokey_read_cycles < SD_IRQ_POKEY_CYCLES ?
            pokey_read_cycles : SD_IRQ_POKEY_CYCLES;
        pokey_read_cycles -= spent;
        ad_pokey_advance(&pokey[0], SD_IRQ_POKEY_CYCLES - spent);
        ad_pokey_advance(&pokey[1], SD_IRQ_POKEY_CYCLES - spent);
        sd_irq();
        render_push_audio_tick();  /* drain audio already produced by advance */
        n++;
    }
    return n;
}

/* Give up the CPU for up to `remain` ms.  In synthetic mode this simply
 * moves the clock; that is what makes the self-test instant and keeps the
 * headless backend (whose plat_sleep_ms advances ITS clock) from ever
 * needing to be involved in pacing. */
static void machine_idle(double remain)
{
    presenter_poll();                 /* a refresh tick may be due */
    if (fast_clock) {
        /* The synthetic clock jumps a whole wait at once; a refresh tick
         * inside the jump must still be seen on time, or the test-mode
         * presenter would find a fresh frame at every tick it sees. */
        if (test_raster() && next_refresh >= 0.0) {
            double to_tick = next_refresh - clock_ms();
            if (to_tick > 0.0 && to_tick < remain) remain = to_tick;
        }
        /* The bias matters: (t + d) - t can come back a few ULPs SHORT of
         * d, so an exact "advance by the shortfall" leaves the accumulator
         * forever a hair under one tick and the wait never ends (it did,
         * the first time this was written).  1e-6 ms of synthetic time per
         * idle is ~0.25 ppm of drift - nothing, and it only exists in the
         * synthetic mode where "wall time" is a fiction anyway. */
        fast_ms += ((remain > 0.0) ? remain : 0.0) + 1e-6;
        return;
    }
    /* 1 ms granularity (plat_win.c holds timeBeginPeriod(1)); the last
     * couple of ms are spun so a frame is never late. */
    if (remain > 2.0) plat_sleep_ms(1);
}

/* Run at least one more IRQ, waiting on the clock if machine time has not
 * caught up yet. */
static void machine_tick(void)
{
    while (machine_pump() == 0)
        machine_idle(mach_tick_ms - irq_acc);
}

/* Wait until an absolute clock time, servicing IRQs throughout - which is
 * what the 6502 did: the interrupt kept firing while it sat in a poll
 * loop. */
static void machine_wait_until(double until)
{
    for (;;) {
        double now;
        machine_pump();
        now = clock_ms();
        if (now >= until) return;
        machine_idle(until - now);
    }
}

/* The CPU is spinning in some other hardware poll (the $80BB EAROM-read
 * wait): let one IRQ tick's worth of machine time pass. */
void sd_hw_idle(void) { machine_tick(); }

/* ---- vector timing correction: the 6502's own time --------------------
 * A translated Start2 pass costs microseconds, but on the board it is real
 * CPU time: Gtoptn and the self-test test before the AVG wait ($401F), then
 * DoLowOnesEvery, the frame gate, the buffer swap and everything the pass
 * builds up to `L410D JSR AddHaltToVector` - two to six IRQ periods.  With
 * no model of that the port could not reproduce the ROM's own overrun
 * frames: the oracle's 600-frame attract run takes 4 IRQs on 556 passes but
 * 5, 6 or 7 on 43 of them, and the port took 4 every time.  (Space Duel is
 * milder than Gravitar, whose port ran 2-5x too fast before this was
 * modelled, because Space Duel's mainline strobes the VG itself and its
 * $33 gate already paces the common case.)
 *
 * THE COSTS BELOW ARE MEASURED, NOT INVENTED.  tools/prof_fit.py, an
 * observer over the oracle (the hardware model itself unchanged), reports
 * per pass the mainline's own cycles - everything but the two hardware
 * waits ($401F BIT HALT / $4027 LSR $33) and the IRQ handler - against the
 * display-list bytes the pass built, split PRE/POST at the first wait.
 * Fitted per (STATE, DSTATE) = (ATRACT $35, ATSTG $DC), Space Duel's
 * equivalent of Gravitar's pair, over three scenarios on 2026-09-13:
 * attract 3000 frames, play 3000 frames, selftest 440 frames - 6,046
 * passes.  The list length explains most of the spread in every state (the
 * residual sd is 1.7-1.9 k cycles against a 3.0-6.5 k spread about the
 * plain mean), so none of them takes Gravitar's per-state-mean treatment.
 *
 * W cycles of mainline work occupy W / (6144 - handler) IRQ periods of
 * machine time, because the IRQ handler steals `handler` cycles of every
 * 6144-cycle period.  Fractions carry over, so a 4.01 averages 4.01.
 *
 * That the model is the right one is checkable: grouped by the IRQs the
 * oracle actually spent on the pass, attract's measured work per pass is
 * 2.68 IRQ periods on the 521 four-IRQ passes, 4.55 on the 30 five-IRQ
 * ones, 5.84 on the 22 six-IRQ ones and 6.07 on the single seven-IRQ one -
 * the overruns ARE the CPU time, and nothing else. */
typedef struct {
    uint8_t state, dstate;
    double  base, per_byte;         /* mainline cycles per pass            */
    double  pre;                    /* of which, before the AVG wait       */
    double  handler;                /* IRQ handler cycles per IRQ          */
} cpu_fit;
static const cpu_fit cpu_fits[] = {
    /* ATRACT ATSTG   base  per_byte    pre  handler  (prof_fit, 2026-09-13) */
    { 0x00, 0x00,   5047.0, 48.28,  1877.0, 798.0 }, /* attract, no special  695 passes sd 1719, 190-504 bytes = 2.66-5.50 IRQs */
    { 0x00, 0x80,   1180.0, 56.56,  1864.0, 800.0 }, /* attract, special    2482 passes sd 1855, 226-574 bytes = 2.61-6.30 IRQs */
    { 0x80, 0x00,   2207.0, 51.35,  1843.0, 490.0 }, /* a game running      2868 passes sd 1853, 140-302 bytes = 1.66-3.13 IRQs */
    { 0x80, 0x80,  23042.0,  0.0,    307.0, 792.0 }, /* the first pass of a game: 1 pass, 114 bytes, 4.31 IRQs */
};
#define SD_IRQ_CYCLES 6144.0

static double cpu_owed;                  /* fractional IRQ periods carried */
static const cpu_fit *cur_fit;           /* this pass's fit, or NULL       */
static int    cpu_pass_armed;            /* a Start2 pass is about to open */

static const cpu_fit *fit_lookup(uint8_t state, uint8_t dstate)
{
    size_t i;
    for (i = 0; i < sizeof cpu_fits / sizeof *cpu_fits; i++)
        if (cpu_fits[i].state == state && cpu_fits[i].dstate == dstate)
            return &cpu_fits[i];
    return NULL;                         /* charge nothing for an unfitted
                                          * state rather than invent one   */
}

/* Spend `irqs` IRQ periods of machine time, as the 6502 would have. */
static void cpu_charge(double irqs)
{
    cpu_owed += irqs;
    while (cpu_owed >= 1.0) {
        machine_tick();
        cpu_owed -= 1.0;
    }
}

/* Spend `cycles` of MAINLINE time under a fit: the IRQ handler steals its
 * share of every period, so the wall time is longer by that ratio. */
static void cpu_charge_cycles(const cpu_fit *f, double cycles)
{
    if (cycles > 0.0)
        cpu_charge(cycles / (SD_IRQ_CYCLES - f->handler));
}

/* L410D `JSR AddHaltToVector` has returned: the list this pass built is
 * complete and VGLIST/EAC2 gives its length ($2002/$2402 + n).  This is
 * Space Duel's Namony - under a fit it is the first moment the build's cost
 * is known, so the POST half is charged here, while the buffer the AVG is
 * drawing is still the one strobed at $4056. */
void sd_hw_list_done(void)
{
    if (cur_fit) {
        double bytes = (double)(((((unsigned)EAC2 << 8) | VGLIST) & 0x03FFu)) - 2.0;
        double post_cyc = cur_fit->base + cur_fit->per_byte * bytes - cur_fit->pre;

        /* Will this pass be a dropped frame?  Nothing of it has been spent
         * yet (the build is instant), and its length is floor(owed + this
         * build + the next pass's pre) IRQ periods plus whatever the gate
         * adds, never less - so >= dropped_irqs here is certain.  Exact on
         * all 7 events of a 3600-frame attract, no false positives
         * (2026-09-13).  The blank is scheduled for the moment the AVG
         * finishes this frame's list: when the tube goes dark. */
        if (dropped_irqs > 0 && !blank_shown) {
            const cpu_fit *nf = fit_lookup(ATRACT, ATSTG);
            double post = post_cyc > 0.0
                          ? post_cyc / (SD_IRQ_CYCLES - cur_fit->handler) : 0.0;
            double pre  = nf ? nf->pre / (SD_IRQ_CYCLES - nf->handler) : 0.0;
            unsigned ticks = (g.irq_count - irq_at_vggo)
                             + (unsigned)(cpu_owed + post + pre);
            if (ticks >= (unsigned)dropped_irqs) blank_at = vg_busy_until;
        }
        cpu_charge_cycles(cur_fit, post_cyc);
    }
    cpu_pass_armed = 1;         /* the next $401F wait opens a Start2 pass */
}

/* IN0 d6 - VG HALT.  The AVG holds it LOW while it is drawing; the mainline
 * blocks at $401F until it goes high.  The busy window is the cycle-true
 * draw time of the list we last started (avg_frame_time_ms(), the
 * mame_late state-machine model validated on all 34 captured frames). */
static int in0_halt(void) { return clock_ms() >= vg_busy_until; }

/* IN0 d7 - the 3 kHz clock, (cycles / 252) & 1 (NOTES_oracle.md §2/§6).
 * Only the self-test busy-waits on it, so its phase is inert for the game;
 * it is derived from machine time rather than faked so a future selftest.c
 * sees a real square wave. */
static int in0_clock(void)
{
    /* machine progress in HARDWARE ms (irq_acc is in scaled wall ms) */
    double mach_ms = ((double)g.irq_count + irq_acc / mach_tick_ms) * SD_TICK_MS;
    double half    = (mach_ms * SD_CYC_PER_MS) / 252.0;
    return (int)((uint64_t)half & 1u);
}

/* $4027 LSR $33 / BCC - consume one frame-gate bit with the ROM's own
 * dynamics (the IRQ does INC $33 every 4th tick; the mainline shifts bits
 * out until one falls into the carry).  Byte-for-byte the probe's
 * consume_gate_bit(), except that running out of bits WAITS for machine
 * time here instead of synthesizing it. */
static void consume_gate_bit(void)
{
    for (;;) {
        int c = ZP_33 & 1;
        ZP_33 >>= 1;
        if (c) return;
        if (ZP_33 == 0) machine_tick();       /* out of bits: time passes */
    }
}

void sd_wait_frame_gate(void)
{
    machine_pump();
    consume_gate_bit();
}

/* $401F BIT HALT / BVC - a REAL wait for the AVG to finish the list it is
 * drawing.  Together with the gate wait above this makes the frame period
 * max(16.26 ms, AVG draw time) without either number being written down:
 * heavy display lists slow the game down exactly as they did on the
 * hardware (DESIGN.md "Timing model").
 *
 * It is also the pass's FIRST hardware wait, so the PRE half of the pass's
 * CPU time (Start2's Gtoptn and the self-test test, which on the board run
 * before the 6502 ever looks at HALT) is charged here.  The arm flag keeps
 * that to Start2 passes: selftest.c calls this from $85A1 and St2, loops
 * with no display-list build and no fit, and only sd_hw_list_done() arms
 * it.  The first pass after a boot is therefore uncharged - one pass. */
void sd_wait_vghalt(void)
{
    if (cpu_pass_armed) {
        cpu_pass_armed = 0;
        cur_fit = fit_lookup(ATRACT, ATSTG);
        if (cur_fit)
            cpu_charge_cycles(cur_fit, cur_fit->pre);
    } else {
        cur_fit = NULL;
    }
    machine_wait_until(vg_busy_until);
}

/* $8592 BIT HALT / BPL, BIT HALT / BMI, n times - the self-test's frame
 * timer, 25 periods of the 3 kHz clock (~8.3 ms).  The clock is a pure
 * function of machine time (in0_clock above), so the edge the loop exits on
 * is computed and waited for exactly: per period, if the clock is low wait
 * for the next high half (h odd), then for the low half after it. */
void sd_wait_3khz(uint8_t n)
{
    double cyc, target;
    uint64_t h;
    int i;

    machine_pump();
    cyc = ((double)g.irq_count + irq_acc / mach_tick_ms) * SD_TICK_MS
          * SD_CYC_PER_MS;                      /* machine cycles so far   */
    h = (uint64_t)(cyc / 252.0);                /* half-period index       */
    for (i = 0; i < (int)n; i++) {
        if (!(h & 1u)) h++;                     /* BPL: wait for high      */
        h++;                                    /* BMI: wait for low       */
    }
    target = (double)h * 252.0;
    machine_wait_until(clock_ms() + (target - cyc) / SD_CYC_PER_MS * mach_scale);
}

/* ------------------------------------------------------------------ */
/* the AVG frame boundary                                              */
/* ------------------------------------------------------------------ */

/* Per-frame statistics, also read by the self-test main below. */
static int    stat_segs, stat_words;
static double stat_avg_ms;
static double stat_frame_ms;

static void emit_seg(float x0, float y0, float x1, float y1, int color, int lum)
{
    /* avg.c reports dark moves too (lum == 0) so callers can trace the
     * beam; the beam is blanked for those, so they are not drawn. */
    if (lum <= 0) return;
    stat_segs++;
    plat_video_line(BEAM_CX + x0, BEAM_CY + y0,
                    BEAM_CX + x1, BEAM_CY + y1, color, lum);
}

/* $0C80 VGGO: the frame boundary.  The mainline has just swapped the buffer
 * select word at $2001 and strobed GOADD, so the list reachable from word
 * address 0 is the finished frame; the pass then builds the NEXT one into
 * the other buffer.  Walking it here is exactly what the AVG does. */
void sd_hw_vggo(void)
{
    static double fps_t0 = -1.0, last_flip = -1.0;
    static double jit_min, jit_max, jit_sum;
    static int    jit_n, fps_frames, fps_segs;
    double now;

    g.frame_count++;

    stat_segs = 0;
    plat_video_begin();
    avg_run(emit_seg, &stat_words);
    now = clock_ms();

    /* The pass that just ended: the truth about whether it was a dropped
     * frame is its IRQ count (the blank itself went up from the idle loop
     * when the last of those IRQs was still to come). */
    if (dropped_irqs > 0 && g.irq_count - irq_at_vggo >= (unsigned)dropped_irqs) {
        ref_events++;
        ref_events_total++;
    }
    irq_at_vggo = g.irq_count;
    blank_shown = 0;
    blank_at    = -1.0;              /* a prediction never shown lapses */
    if (frame_pending) ref_dropped++;   /* a held frame, never shown */
    if (test_raster()) {
        frame_fresh   = 1;           /* captured; the tick shows it */
        frame_pending = 0;
        presenter_poll();
    } else if (now < blank_until) {
        frame_pending = 1;           /* the blank has not had its hold */
    } else {
        plat_video_present();
        frame_pending = 0;
        frame_fresh   = 0;
    }
    stat_avg_ms   = avg_frame_time_ms();    /* authentic, for the stats */
    vg_busy_until = now + stat_avg_ms * mach_scale; /* HALT low this long
                                             * (the AVG shares the crystal,
                                             * so the fps lock scales it) */

    /* delivery statistics -> the window title (and sd_win.log) once a second */
    if (fps_t0 < 0.0) fps_t0 = now;
    if (last_flip >= 0.0) {
        double d = now - last_flip;
        stat_frame_ms = d;
        if (jit_n == 0 || d < jit_min) jit_min = d;
        if (jit_n == 0 || d > jit_max) jit_max = d;
        jit_sum += d;
        jit_n++;
    }
    last_flip = now;
    fps_frames++;
    fps_segs += stat_segs;

    if (now - fps_t0 >= 1000.0) {
        char buf[256];
        snprintf(buf, sizeof buf,
                 "%.1f fps  frame %.2f ms (min %.2f max %.2f)  "
                 "avg draw %.2f ms  %d segs  %d list bytes  "
                 "%d dropped (%d held)  %d blank  "
                 "pokey q %u/%u underrun %u overrun %llu/%llu",
                 (double)fps_frames * 1000.0 / (now - fps_t0),
                 jit_n ? jit_sum / jit_n : 0.0,
                 jit_n ? jit_min : 0.0,
                 jit_n ? jit_max : 0.0,
                 stat_avg_ms,
                 fps_frames ? fps_segs / fps_frames : 0,
                 stat_words * 2,
                 ref_events, ref_dropped, ref_blanks,
                 ad_pokey_audio_available(&pokey[0]),
                 ad_pokey_audio_available(&pokey[1]),
                 audio_underrun_frames,
                 (unsigned long long)ad_pokey_audio_overruns(&pokey[0]),
                 (unsigned long long)ad_pokey_audio_overruns(&pokey[1]));
        plat_status_text(buf);
        jit_sum = 0.0; jit_n = 0;
        fps_frames = 0; fps_segs = 0;
        ref_events = 0; ref_dropped = 0; ref_blanks = 0;
        fps_t0 = now;
    }
}

/* ------------------------------------------------------------------ */
/* the app hooks                                                       */
/* ------------------------------------------------------------------ */

/* Poweron on synthetic time.  StartThingsRunning burns $61 frame gate
 * ticks (~1.58 s of hardware time) waiting for the EAROM to warm up, then
 * polls while the IRQ-driven state machine reads it; on real time that is
 * 1.6 s of a black, unpainted window that reads as a hang.  The IRQ
 * sequence is bit-identical either way - only the wall time it occupies
 * changes - so it is fast-forwarded, at power-on and again for the
 * self-test's two CPU restarts (sd_hw_reset). */
static void boot_fast(void)
{
    int was_fast = fast_clock;

    fast_clock = 1;
    if (!was_fast) fast_ms = 0.0;    /* a fresh synthetic clock       */
    last_ms    = -1.0;
    irq_acc    = 0.0;
    booting    = 1;
    sd_boot();
    booting    = 0;

    if (!selftest_mode) {
        /* Start live output at a fresh sample boundary, retaining oscillators. */
        ad_pokey_set_cycle_audio(&pokey[0], true);
        ad_pokey_set_cycle_audio(&pokey[1], true);
        audio_tick_phase = 0;
        pokey_read_cycles = 0;
        fast_clock = 0;              /* from here on: the wall clock */
        last_ms    = -1.0;
        irq_acc    = 0.0;
    }
    vg_busy_until = clock_ms();      /* nothing has been drawn yet */
    irq_at_vggo   = g.irq_count;     /* the first pass starts here, not
                                      * 388 boot IRQs ago */
    blank_shown = 0; frame_pending = 0; blank_until = -1.0; blank_at = -1.0;
}

/* WatchDogResetExit $8618 (self-test switch turned off in the diagnostics)
 * and the bookkeeping screen's option 0: the CPU restarts at Poweron.  The
 * watchdog's own timeout is not modeled - the restart is immediate. */
void sd_hw_reset(void) { boot_fast(); }

void sd_app_init(void)
{
    memset(&g, 0, sizeof g);
    if (mach_tick_ms <= 0.0) mach_tick_ms = SD_TICK_MS;   /* no fps lock set */
    pokey_init();                    /* live before Poweron's STA POKEY,X loop */
    earom_load();
    audio_open();
    plat_input_poll(&cur_in);        /* CABERE/self-test reads at $80A2 */
    test_latch = cur_in.diag ? 1 : 0;/* F2 held at launch: power-on test */
    diag_prev  = cur_in.diag;
    boot_fast();
}

/* One displayed frame.  sd_mainline_frame() is one Start2 pass and blocks
 * in the two waits above, so it returns having consumed a real frame's
 * worth of time; the return value is therefore always 0 ("a frame just
 * ran") and WinMain's sleep hint never fires.  Inputs are sampled once per
 * pass - the same granularity the 6502 got, since the backend's key state
 * only updates when WinMain drains the message queue between passes. */
double sd_app_step(double now_ms)
{
    (void)now_ms;                    /* the seam reads the clock itself */
    plat_input_poll(&cur_in);
    if (cur_in.diag && !diag_prev)   /* F2: toggle the self-test switch */
        test_latch ^= 1;
    diag_prev = cur_in.diag;
    sd_mainline_frame();
    sd_sample_frame();               /* age the held sample loops */
    return 0.0;
}

void sd_app_exit(void)
{
    if (earom.dirty) {
        if (plat_nvram_write(earom.rom, sizeof earom.rom) == 0)
            earom.dirty = false;
    }
}

/* ------------------------------------------------------------------ */
/* SD_SELFTEST_MAIN: the headless timed/scripted run                   */
/* ------------------------------------------------------------------ */
/*
 * Built as tests\sd_selftest.exe by build_win.bat: this same file plus the
 * game modules plus platform/headless/plat_headless.c.  It runs the REAL
 * app loop and the REAL seam - only the backend and the clock differ - and
 * injects inputs through hl_inputs, so it answers "does a coin register /
 * does start begin a game / does the ship respond" without a human at the
 * keyboard.  It also round-trips the NVRAM blob through sd_c.nv.
 *
 *     tests\sd_selftest.exe [frames]        (default 900)
 */
#ifdef SD_SELFTEST_MAIN

#include "platform/headless/plat_headless.h"

extern void transfer_high_scores_buffer(void);   /* earom.h */
extern void write_high_scores_initials(void);    /* earom.h */
extern int  sd_cpu_loop(void);                   /* selftest.h */

#define OST(i) (g.ram[0x97u + (unsigned)(i)])    /* object status table */

static int    st_seg_min, st_seg_max;
static long   st_seg_sum;
static int    st_frames;
static double st_ms_min, st_ms_max, st_ms_sum;
static int    st_ms_n;
static long   st_events0, st_blanks0;  /* dropped-frame / test-mode blank
                                        * totals at reset */

/* Ship 0's four torpedo slots: FireShipsTorpedos_20 searches object status
 * slots $2B down to $28 (g.ram[$C2]..g.ram[$BF]) - the start/stop indices
 * from the $4D6B table with X = ship + 2.  A torpedo lives $12/$24 frames,
 * so the test watches the PEAK, not the count when the burst is over. */
static int st_torp_peak;

static int st_torps_active(void)
{
    int i, n = 0;
    for (i = 0x28; i <= 0x2B; i++) if (OST(i)) n++;
    return n;
}

static void st_reset_stats(void)
{
    st_seg_min = 1 << 30; st_seg_max = 0; st_seg_sum = 0; st_frames = 0;
    st_ms_min = 1e30; st_ms_max = 0.0; st_ms_sum = 0.0; st_ms_n = 0;
    st_events0 = ref_events_total; st_blanks0 = ref_blanks_total;
}

/* --trace: one line per displayed frame - frame number (the oracle's
 * numbering, so ref_index.json's VGGO cycle deltas line up), the list
 * size, segments, the AVG draw time and the frame period the loop
 * delivered.  For comparing the port's pacing against the real ROM's. */
static int st_trace;

static void st_run(int n)
{
    int i;
    for (i = 0; i < n; i++) {
        sd_app_step(plat_now_ms());
        if (st_trace)
            printf("TRACE frame %u words %d segs %d avg %.2f ms period %.2f ms irqs %u dropped %ld\n",
                   g.frame_count, stat_words, stat_segs, stat_avg_ms,
                   stat_frame_ms, g.irq_count, ref_events_total);
        if (st_torps_active() > st_torp_peak) st_torp_peak = st_torps_active();
        st_frames++;
        st_seg_sum += stat_segs;
        if (stat_segs < st_seg_min) st_seg_min = stat_segs;
        if (stat_segs > st_seg_max) st_seg_max = stat_segs;
        if (stat_frame_ms > 0.0) {
            if (stat_frame_ms < st_ms_min) st_ms_min = stat_frame_ms;
            if (stat_frame_ms > st_ms_max) st_ms_max = stat_frame_ms;
            st_ms_sum += stat_frame_ms;
            st_ms_n++;
        }
    }
}

/* Run until ship 0's status ($B8) shows a ship that is present (nonzero)
 * and not exploding (bit 7 clear), up to ~15 s of machine time; returns
 * the frames spent waiting.  A dead ship re-enters only once MoveShip's
 * SDELAY has run down and nothing is near the spawn point. */
static int st_wait_live_ship(void)
{
    int i;
    for (i = 0; i < 900 && (g.ram[0xB8] == 0 || (g.ram[0xB8] & 0x80)); i++)
        st_run(1);
    return i;
}

static void st_report(const char* what)
{
    printf("  %-22s %4d frames  segs %d..%d avg %ld   frame %.2f..%.2f ms "
           "avg %.2f (%.1f fps)   dropped frames %ld   test-mode blanks %ld\n",
           what, st_frames, st_seg_min, st_seg_max,
           st_frames ? st_seg_sum / st_frames : 0,
           st_ms_n ? st_ms_min : 0.0, st_ms_n ? st_ms_max : 0.0,
           st_ms_n ? st_ms_sum / st_ms_n : 0.0,
           st_ms_n && st_ms_sum > 0.0 ? 1000.0 * st_ms_n / st_ms_sum : 0.0,
           ref_events_total - st_events0, ref_blanks_total - st_blanks0);
}

/* sd_c.nv <-> the headless in-memory NVRAM, so two consecutive runs of this
 * binary exercise the exact file the Windows backend writes. */
static void st_nv_load(void)
{
    FILE* f = fopen("sd_c.nv", "rb");
    if (!f) { hl_nvram_len = 0; return; }
    hl_nvram_len = (unsigned)fread(hl_nvram, 1, SD_EAROM_SIZE, f);
    fclose(f);
}

static void st_nv_save(void)
{
    FILE* f;
    if (hl_nvram_len == 0) return;
    f = fopen("sd_c.nv", "wb");
    if (!f) return;
    fwrite(hl_nvram, 1, hl_nvram_len, f);
    fclose(f);
}


int main(int argc, char** argv)
{
    int frames = (argc > 1) ? atoi(argv[1]) : 900;
    int fails = 0;
    int i;

    for (i = 1; i < argc; i++)
        if (!strcmp(argv[i], "--trace")) st_trace = 1;
    uint8_t credits_before, credits_after;
    uint8_t ang0, ang1, ang2;
    int objs_before, objs_after;
    uint8_t vxl, vxh, vyl, vyh;

    setvbuf(stdout, NULL, _IONBF, 0);        /* progress must survive a hang */
    setvbuf(stderr, NULL, _IONBF, 0);
    selftest_mode = 1;                       /* synthetic clock throughout */
    sd_app_set_dropped_frame(7, 0.0);        /* the game build's defaults */
    sd_app_set_refresh(60.0);                /* a 60 Hz panel for test mode */
    st_nv_load();
    if (plat_init()) return 2;

    printf("SELFTEST: headless run of the real app loop "
           "(%d attract frames, then a scripted game)\n", frames);
    printf("SELFTEST: NVRAM %s\n",
           hl_nvram_len ? "loaded from sd_c.nv" : "absent (fresh blank part)");

    sd_app_init();
    printf("SELFTEST: boot done, %u IRQs, EAROM bad-checksum flags $%02X "
           "(0 = both batches OK)\n", g.irq_count, g.ram[0x187]);
    printf("SELFTEST: top-of-table score bytes $DE/$ED/$FC/$10B = "
           "%02X %02X %02X %02X (05 = the reseeded 500)\n",
           g.ram[0xDE], g.ram[0xED], g.ram[0xFC], g.ram[0x10B]);

    /* ---- attract -------------------------------------------------
     * The first ~500 frames are the title / high-score screens: 4-IRQ
     * passes, never a dropped frame.  The demo game that follows
     * overruns the gate, and its opening seconds hold the 7-IRQ passes
     * that ARE the cabinet's dropped frames: 7 of them in 3600 frames
     * (2026-09-13), so a 3600-frame run must count a handful, not none
     * and not dozens. */
    {
        long light, total;
        int  head = frames < 500 ? frames : 500;
        st_reset_stats();
        st_run(head);
        light = ref_events_total - st_events0;
        if (frames > head) st_run(frames - head);
        st_report("attract");
        total = ref_events_total - st_events0;
        if (st_seg_max == st_seg_min) {
            printf("  FAIL: attract is a still picture (segment count never "
                   "changed)\n");
            fails++;
        }
        if (light != 0) {
            printf("  FAIL: %ld dropped frames on the light attract screens "
                   "(4-IRQ passes cannot reach 7 IRQs)\n", light);
            fails++;
        }
        if (frames >= 3600 && (total < 3 || total > 20)) {
            printf("  FAIL: %ld dropped frames in the attract; the ROM's own "
                   "overruns give about 7 per 3600 frames\n", total);
            fails++;
        }
        if (ref_blanks_total - st_blanks0 != 0) {
            printf("  FAIL: test-mode blanks in the attract (the raster "
                   "presenter is for the test loops only)\n");
            fails++;
        }
    }

    /* ---- insert a coin ------------------------------------------- */
    credits_before = DIAGBI;
    hl_inputs.coin1 = 1;
    st_reset_stats(); st_run(12);            /* ~200 ms of coin present */
    hl_inputs.coin1 = 0;
    st_run(120);                             /* the $2A post-coin timer */
    st_report("coin inserted");
    credits_after = DIAGBI;
    printf("  credits $$CRDT $20: %u -> %u   $CNCT $26 = %u   "
           "$CMODE $24 = $%02X\n",
           credits_before, credits_after, (g.ram[0x0026]), ZMINE);
    if (credits_after <= credits_before) {
        printf("  FAIL: the coin did not register\n");
        fails++;
    }

    /* ---- select a game, then press start --------------------------
     * The ROM's own start lockout: Pwron sets STRTLOK = $80 ("no starts
     * allowed") and only CheckForStartEnd_42 clears bit 7 - on the rising
     * edge of the GAME SELECT switch, and only while a credit is showing.
     * So a freshly powered cabinet needs coin -> SELECT -> START, which is
     * how the machine actually behaved. */
    printf("  STRTLOK $43D before select = $%02X (bit7 = starts locked)\n",
           STRTLOK);
    hl_inputs.game_select = 1;
    st_reset_stats(); st_run(6);
    hl_inputs.game_select = 0;
    st_run(6);
    printf("  STRTLOK after select      = $%02X, game type $34 = %u\n",
           STRTLOK, ZP_34);

    hl_inputs.start1 = 1;
    st_run(10);
    hl_inputs.start1 = 0;
    st_run(120);
    st_report("game started");
    printf("  game flag $35 = $%02X (bit7 = playing)  game type $34 = %u  "
           "credits = %u  lives $47/$48 = %u/%u\n",
           ZP_35, ZP_34, DIAGBI, g.ram[0x47], g.ram[0x48]);
    if (!(ZP_35 & 0x80)) {
        printf("  FAIL: start did not begin a game\n");
        fails++;
    }

    /* ---- rotate --------------------------------------------------- */
    ang0 = IANGLE;
    hl_inputs.rotate_left = 1;  st_run(30); hl_inputs.rotate_left = 0;
    ang1 = IANGLE;
    hl_inputs.rotate_right = 1; st_run(30); hl_inputs.rotate_right = 0;
    ang2 = IANGLE;
    printf("  IANGLE $3D0: idle %u -> rotate-left %u -> rotate-right %u\n",
           ang0, ang1, ang2);
    if (ang1 == ang0 || ang2 == ang1) {
        printf("  FAIL: the ship does not rotate\n");
        fails++;
    }

    /* Thrust and fire need ship 0 on screen, and for long enough.  Where
     * the rocks spawn is RANDOM's business, and RANDOM is now the POKEY
     * polynomial under machine time - deterministic from the ROM's SKCTL
     * reset, exactly like the chip - so a given attract length can hand
     * the scripted pilot a rock through the windscreen a frame into a
     * check (600 frames does; 601 does not), after which MoveShip holds
     * the re-entry while anything is near the spawn point.  Each check
     * therefore waits for a live ship (st_wait_live_ship), watches for
     * the effect on every frame rather than only at the end, and retries
     * after a death.  A ship that never responds while alive is the
     * failure; dying is the game. */

    /* ---- thrust --------------------------------------------------- */
    {
        int tries, moved = 0;
        for (tries = 0; tries < 4 && !moved; tries++) {
            int f, waited = st_wait_live_ship();
            vxl = g.ram[0x4B]; vxh = g.ram[0x221];
            vyl = g.ram[0x4D]; vyh = g.ram[0x223];
            hl_inputs.thrust = 1;
            for (f = 0; f < 60 && !moved; f++) {
                st_run(1);
                if (g.ram[0x4B] != vxl || g.ram[0x221] != vxh ||
                    g.ram[0x4D] != vyl || g.ram[0x223] != vyh)
                    moved = 1;
            }
            hl_inputs.thrust = 0;
            printf("  thrust try %d: ship on screen after %d frames; velocity "
                   "X %02X%02X -> %02X%02X   Y %02X%02X -> %02X%02X after %d "
                   "frames   position $2D6/$308 = %02X/%02X   status $B8 = %02X\n",
                   tries + 1, waited,
                   vxh, vxl, g.ram[0x221], g.ram[0x4B],
                   vyh, vyl, g.ram[0x223], g.ram[0x4D], f,
                   g.ram[0x2D6], g.ram[0x308], g.ram[0xB8]);
        }
        if (!moved) {
            printf("  FAIL: thrust changed nothing\n");
            fails++;
        }
    }

    /* ---- fire -----------------------------------------------------
     * Ship 0's torpedoes live in object status slots $28-$2B (g.ram[$BF]-
     * g.ram[$C2]): FireShipsTorpedos_20 enters Temp280Fast0 with the
     * start/stop indices from the $4D6B table, X = ship + 2.  The ROM
     * edge-detects the button (LASTSW bit 7), so the switch has to be
     * released between shots. */
    {
        int tries;
        objs_before = 0;
        objs_after = 0;
        for (tries = 0; tries < 4 && objs_after <= objs_before; tries++) {
            int waited = st_wait_live_ship();
            objs_before = st_torps_active();
            st_torp_peak = objs_before;
            for (i = 0; i < 12 && st_torp_peak <= objs_before; i++) {
                hl_inputs.fire = 1; st_run(3);
                hl_inputs.fire = 0; st_run(3);
            }
            objs_after = st_torp_peak;
            printf("  fire try %d: ship on screen after %d frames (status $B8 "
                   "= %02X, entry/shield $4F = %02X); torpedo slots $BF-$C2 "
                   "active: %d at rest, peak %d while firing\n",
                   tries + 1, waited, g.ram[0xB8], g.ram[0x4F],
                   objs_before, objs_after);
        }
        if (objs_after <= objs_before) {
            printf("  FAIL: fire launched nothing\n");
            fails++;
        }
    }

    /* ---- rock splitting (SplitRockIntoFragments $6554) -------------
     * Keep rotating and firing: a torpedo hit on a rock must now split
     * it - the split writes exactly $A0 (a fresh full-length explosion)
     * into the old rock's status slot, and a real split also raises
     * NROCKS.  Watched every frame across a sustained barrage. */
    {
        uint8_t nrocks0 = NROCKS, nrocks_pk = NROCKS;
        int a0_frames = 0, j;
        for (j = 0; j < 900; j++) {
            hl_inputs.rotate_left = (j & 0x20) != 0;
            hl_inputs.fire = (j & 0x04) != 0;   /* edge-detected: toggle  */
            st_run(1);
            if (NROCKS > nrocks_pk) nrocks_pk = NROCKS;
            for (i = 0; i <= 0x10; i++)
                if (g.ram[0x97 + i] == 0xA0) { a0_frames++; break; }
        }
        hl_inputs.rotate_left = 0; hl_inputs.fire = 0;
        printf("  rock splitting: NROCKS %u -> peak %u, frames with a fresh"
               " $A0 rock explosion %d\n", nrocks0, nrocks_pk, a0_frames);
        if (a0_frames == 0) {
            printf("  FAIL: no rock ever exploded or split\n");
            fails++;
        }
    }

    /* ---- POKEY audio ----------------------------------------------
     * The headless backend counts what the core streams.  Two claims:
     * the render is rate-locked to machine time (179.2 frames per IRQ at
     * 44.1 kHz, so frames pushed == IRQs * 44100 / 246.09375 to within
     * the fractional carry), and the chips actually made a sound during
     * the game above (firing, thrusting and exploding all program the
     * POKEYs through the script engine; the peak is 0 only if every
     * register write was lost on the way to c012294.c). */
    {
        double expect = (double)g.irq_count * (double)SD_AUDIO_RATE / SD_IRQ_HZ;
        double got    = (double)hl_audio_frames;
        double err    = got > expect ? got - expect : expect - got;
        printf("  POKEY stream: %llu frames at %d Hz over %u IRQs (expect "
               "%.1f, off by %.2f)   peak level %d of 32767\n",
               (unsigned long long)hl_audio_frames, hl_audio_rate,
               g.irq_count, expect, err, hl_audio_peak);
        if (hl_audio_rate != SD_AUDIO_RATE || err > 2.0) {
            printf("  FAIL: the POKEY render is not rate-locked to the IRQ\n");
            fails++;
        }
        if (hl_audio_peak == 0) {
            printf("  FAIL: the POKEYs never made a sound\n");
            fails++;
        }
    }

    /* ---- self-test: the host's F2 path through the real app loop ------
     * F2 (toggle) mid-game -> AllStopPlease's bookkeeping screen; SELECT
     * until option 0 shows, START+SELECT -> the CPU restarts with the
     * switch still on -> the power-on diagnostics; DIAG STEP (F1) -> the
     * next screen; F2 again -> WatchDogResetExit -> Poweron -> attract.
     * The screens' bytes are the probes' business (tests\probe_selftest);
     * this checks the seam: the F2 latch, sd_wait_3khz, sd_hw_reset. */
    {
        int loop, tries;

        hl_inputs.diag = 1; st_run(1); hl_inputs.diag = 0;   /* F2 press  */
        st_reset_stats(); st_run(30);
        loop = sd_cpu_loop();
        st_report("bookkeeping (F2)");
        /* 44.15 fps against a 60 Hz panel: about one refresh in four has
         * no new frame and is blank - the cabinet's steady flicker. */
        if (ref_blanks_total - st_blanks0 == 0) {
            printf("  FAIL: the bookkeeping screen never blanked a refresh "
                   "(44 fps must flicker on a 60 Hz panel)\n");
            fails++;
        }
        printf("  CPU loop %d (1 = St2 bookkeeping)  game flag $35 = $%02X  "
               "option $1A&3 = %u\n", loop, ZP_35, ZP_1A & 3);
        if (loop != 1 || st_seg_max == 0) {
            printf("  FAIL: F2 did not bring up the bookkeeping screen\n");
            fails++;
        }
        for (tries = 0; (ZP_1A & 3) != 0 && tries < 4; tries++) {
            hl_inputs.game_select = 1; st_run(2);         /* SELECT: the  */
            hl_inputs.game_select = 0; st_run(2);         /* release bumps */
        }
        hl_inputs.start1 = 1; hl_inputs.game_select = 1;  /* START+SELECT  */
        st_run(2);                                        /* option 0: RESET */
        hl_inputs.start1 = 0; hl_inputs.game_select = 0;
        st_reset_stats(); st_run(30);
        loop = sd_cpu_loop();
        st_report("diagnostics (reset)");
        printf("  CPU loop %d (2 = MainLineDiagLoop)  screen $A0 = %02X  "
               "ROM checksums $F0-$F6 = %02X %02X %02X %02X %02X %02X %02X  "
               "ERPLC $80-$83 = %02X %02X %02X %02X\n",
               loop, (g.ram[0x00A0]),
               g.ram[0xF0], g.ram[0xF1], g.ram[0xF2], g.ram[0xF3],
               g.ram[0xF4], g.ram[0xF5], g.ram[0xF6],
               g.ram[0x80], g.ram[0x81], g.ram[0x82], g.ram[0x83]);
        if (loop != 2 || (g.ram[0x00A0]) != 2 || st_seg_max == 0) {
            printf("  FAIL: option 0 did not restart into the diagnostics\n");
            fails++;
        }
        for (i = 0xF0; i <= 0xF6; i++) if (g.ram[i]) fails++, printf("  FAIL: ROM checksum $%02X = %02X\n", i, g.ram[i]);
        for (i = 0x80; i <= 0x83; i++) if (g.ram[i]) fails++, printf("  FAIL: ERPLC $%02X = %02X\n", i, g.ram[i]);
        hl_inputs.diag_step = 1; st_run(4);               /* F1 held       */
        hl_inputs.diag_step = 0; st_run(4);
        printf("  after DIAG STEP: $A0 = %02X (expect $04, the next screen)\n", (g.ram[0x00A0]));
        if ((g.ram[0x00A0]) != 4) {
            printf("  FAIL: DIAG STEP did not advance the screen\n");
            fails++;
        }
        hl_inputs.diag = 1; st_run(1); hl_inputs.diag = 0;   /* F2 again  */
        st_reset_stats(); st_run(30);
        loop = sd_cpu_loop();
        st_report("back in attract");
        printf("  CPU loop %d (0 = Start2)  $35 = $%02X  $44 = %u\n",
               loop, ZP_35, ZP_44);
        if (loop != 0 || st_seg_max == 0) {
            printf("  FAIL: F2 off did not reset into the game\n");
            fails++;
        }
    }

    /* ---- EAROM round trip ----------------------------------------- */
    /* Stage the live high-score cells into the batch-0 buffer and start the
     * real write (2 IRQ ticks per byte, ~3.6 s of machine time), then run
     * until the state machine goes idle.  On the next run of this binary
     * the boot read must bring the same bytes back. */
    g.ram[0xDD] = 0x00; g.ram[0xDE] = 0x13; g.ram[0xDF] = 0x37;
    transfer_high_scores_buffer();
    write_high_scores_initials();
    for (i = 0; i < 2000 && (g.ram[0x188] || g.ram[0x185]); i++)
        st_run(1);
    printf("  EAROM write done after %d frames; image[2..7] = "
           "%02X %02X %02X %02X %02X %02X\n",
           i, earom.rom[2], earom.rom[3], earom.rom[4],
           earom.rom[5], earom.rom[6], earom.rom[7]);
    sd_app_exit();
    st_nv_save();
    if (hl_nvram_len != SD_EAROM_SIZE) {
        printf("  FAIL: NVRAM blob is %u bytes, expected %u\n",
               hl_nvram_len, (unsigned)SD_EAROM_SIZE);
        fails++;
    }

    /* ---- reboot and read it back ---------------------------------- */
    {
        uint8_t s1, s2;
        sd_app_init();                       /* re-reads the same blob */
        s1 = g.ram[0xDE]; s2 = g.ram[0xDF];
        printf("  after reboot: top score bytes $DE/$DF = %02X %02X "
               "(expect 13 37), bad flags $%02X\n", s1, s2, g.ram[0x187]);
        if (s1 != 0x13 || s2 != 0x37) {
            printf("  FAIL: the EAROM did not survive a restart\n");
            fails++;
        }
    }

    /* The idle loop's blank (shown while a dropped frame's last IRQ is
     * still to come) and the VGGO's count of the pass (the truth) must
     * agree one-for-one: every event blanked once, nothing else ever. */
    printf("  dropped frames: %ld passes of %d+ IRQs, %ld test-mode blanks, "
           "%d blank presents in all\n",
           ref_events_total, dropped_irqs, ref_blanks_total, hl_blanks);
    if ((long)hl_blanks != ref_events_total + ref_blanks_total) {
        printf("  FAIL: blank presents != dropped-frame passes + test-mode "
               "blanks\n");
        fails++;
    }

    plat_shutdown();
    printf("SELFTEST: %s (%d failure%s)\n", fails ? "FAILED" : "PASSED",
           fails, fails == 1 ? "" : "s");
    return fails ? 1 : 0;
}
#endif /* SD_SELFTEST_MAIN */
