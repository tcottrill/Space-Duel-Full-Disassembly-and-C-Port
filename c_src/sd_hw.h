/* sd_hw.h - the hardware seam for the Space Duel C port.
 *
 * Translated game code touches hardware ONLY through these functions.
 * Implemented by app_loop.c (real build, over the platform contract) and by
 * platform/headless (probes: injectable bytes, oracle-matched schedules).
 */
#ifndef SD_HW_H
#define SD_HW_H

#include <stdint.h>

/* ---- inputs ------------------------------------------------------------- */
/* IN0 ($0800): d7 3kHz clock, d6 VG HALT, d5 diag step, d4 self-test
 * (0 = test mode), d3 slam, d2-d0 coins. The 3 kHz and HALT bits are
 * synthesized by the harness/app loop, not sampled from a real clock. */
uint8_t sd_hw_in0(void);
/* IN1 ($0900-$0907): one switch per address, bit 7 = state. idx 0..7:
 * 0 hyperspace/shield, 2 rotate left, 4 start1, 5 option, 6 game select,
 * 7 cabinet/rotate right (see listing usage: HYPSW, ROTL, STRT1, OPTNA1,
 * GAMSEL, CABERE). */
uint8_t sd_hw_in1(uint8_t idx);

/* POKEY option-switch reads: the ROM reads DIPs through POKEY2 $1408 after
 * writing $140B, and POKEY1 $1008 likewise (difficulty). */
uint8_t sd_hw_pokey2_optionsw(void);
uint8_t sd_hw_pokey1_diffsw(void);

/* POKEY RANDOM ($100A/$140A): 8 bits off the 17-bit LFSR. The oracle
 * implements the identical generator; sequence parity is required. */
uint8_t sd_hw_pokey_random(int which);   /* 0 = POKEY1, 1 = POKEY2 */

/* ---- sound -------------------------------------------------------------- */
/* Raw POKEY register write (AUDF/AUDC/AUDCTL). ch = which POKEY. The real
 * build synthesizes or maps to samples later; probes just record. */
void sd_hw_pokey_write(int which, uint8_t reg, uint8_t val);

/* ---- outputs ------------------------------------------------------------ */
void sd_hw_out1(uint8_t v);        /* $0C00: coin counters, lamps, flip    */
void sd_hw_vggo(void);             /* $0C80: start the AVG                 */
void sd_hw_vgreset(void);          /* $0D80: hold the AVG in reset         */
/* watchdog ($0D00) and IRQ ack ($0E00) are dropped - hardware artifacts.   */

/* ---- EAROM -------------------------------------------------------------- */
uint8_t sd_hw_earom_read(void);            /* $0A00 */
void    sd_hw_earom_ctl(uint8_t v);        /* $0E80 */
void    sd_hw_earom_write(uint8_t off, uint8_t v);  /* $0F00+off */

/* ---- timing ------------------------------------------------------------- */
/* Run pending 246 Hz IRQ service ticks up to the next mainline sync point.
 * sd_wait_vghalt: the $401F/$85A1 'BIT HALT / BVC' loop.
 * sd_wait_frame_gate: the $4027 'LSR $33 / BCC' loop (returns when a $33
 * bit was consumed). Probe builds drive these off the oracle's schedule. */
void sd_wait_vghalt(void);
void sd_wait_frame_gate(void);
/* The CPU is spinning in some other hardware poll loop (e.g. the $80BB
 * EAROM-read wait): advance machine time by one IRQ tick. */
void sd_hw_idle(void);
/* L410D `JSR AddHaltToVector` has returned: the display list this Start2
 * pass built is complete, and VGLIST/EAC2 is its end.  A TIMING sync point,
 * not a hardware register - it is where the playable build knows how much
 * 6502 time the pass cost (app_loop.c's cpu_fits[], measured by
 * tools/prof_fit.py) and charges it, so a heavy list overruns the frame
 * gate exactly as it did on the board.  The probes replay the oracle's
 * recorded schedule instead and make it a no-op. */
void sd_hw_list_done(void);
/* The self-test's frame timer, $8592: n times { BIT HALT / BPL (wait for
 * the 3 kHz bit HIGH), BIT HALT / BMI (wait for it LOW) }.  Returns at the
 * falling edge that ends the n-th period; IRQs are serviced throughout. */
void sd_wait_3khz(uint8_t n);
/* The CPU restarts at the RESET vector ($803F Poweron) - the watchdog
 * timing out in WatchDogResetExit ($8618, self-test switch released), or
 * the bookkeeping screen's option 0 RTS-jumping there ($8C9E DoSelfTest).
 * Implementations run sd_boot(); the caller returns immediately after. */
void sd_hw_reset(void);
/* Mid-pass IRQ sync points.  On real hardware the ~4 IRQs of a mainline
 * pass fire spread through it, so routines that read a per-IRQ cell
 * ($44, INTRPT, SECOND, SANGLE/IANGLE) see a value that depends on WHERE
 * in the pass they run.  A probe that services a pass's IRQs only at the
 * frame gate makes every mid-pass read see the same (stale) value.
 * sd_hw_irq_mark(point) lets a probe advance machine time to the oracle's
 * recorded irq_count at that exact ROM location (tests/sched/irq_marks.txt,
 * produced by `oracle.py --irq-marks`), the same "replay the recorded
 * schedule" principle vggo_sched.txt already carries, sampled finer.
 * It is a TIMING sync point, NOT a hardware register: it never runs an IRQ
 * the recorded schedule did not, and the real build makes it a no-op.
 *   point 0 = L40FB, the JSR MotionUpdateRoutine (object motion + Pictur)
 *   point 1 = L4113, the JSR UsesTemp1Temp11 (whose first insn is INC $44)
 *   point 2 = L40E5, Start2_31, the LDX #$01 before the MoveShip pair
 *   point 3 = L40D7, Start2_20, before the FireShipsTorpedos pair
 *   point 4 = L8C24, the bookkeeping screen's exit ($44 = 0 .. JMP Pwron):
 *             IRQs before it still rotate IANGLE by $44's old bits
 *   point 5 = $803F, Poweron: a CPU restart (the self-test's option 0 /
 *             WatchDogResetExit) wipes RAM, so the IRQs the oracle took
 *             before it must land before the wipe too
 * The oracle run must record the SAME PCs in the SAME order:
 *   oracle.py --irq-marks 0x40FB --irq-marks 0x4113 \
 *             --irq-marks 0x40E5 --irq-marks 0x40D7 \
 *             --irq-marks 0x8C24 --irq-marks 0x803F
 * (tests/ref carries only the first four; the self-test refs all six.)
 */
void sd_hw_irq_mark(int point);
#define SD_IRQ_MARK_MOTION   0
#define SD_IRQ_MARK_FRAME    1
#define SD_IRQ_MARK_SHIPS    2
#define SD_IRQ_MARK_FIRE     3
#define SD_IRQ_MARK_TESTEXIT 4
#define SD_IRQ_MARK_RESET    5

#endif /* SD_HW_H */
