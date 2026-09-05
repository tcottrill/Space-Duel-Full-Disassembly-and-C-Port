/* irq.c - Space Duel C port: the 246 Hz interrupt service (Irq, $8639,
 * module A2IRQ).
 *
 * Called once per hardware IRQ tick by the app loop / harness. The IRQ
 * acknowledge write ($0E00) and register save/restore are hardware
 * artifacts and dropped.
 */
#include "sd_state.h"
#include "sd_hw.h"
#include "sd_bcd.h"

/* module externs (translated elsewhere) */
extern void output_earom_erased_written(void);  /* OutputEaromErasedWritten $864A (A2EARO) */
extern void coin_routine(void);                 /* L741A (COIN65) */
extern void continue_sounds(void);              /* ContinuesPreviouslyStartedSound (AS2SAC) */

/* Irq ($8639) */
void sd_irq(void)
{
    uint8_t a;

    g.irq_count++;

    TOTOBJ--;                               /* L8642 DEC TOTOBJ ($32)      */
    a = TOTOBJ;
    if ((a & 0x0F) == 0) {                  /* every 16th tick             */
        output_earom_erased_written();      /* EAROM update check          */
        a = TOTOBJ;                         /* L864D reload                */
    }
    if ((a & 0x03) == 0)                    /* every 4th tick: the ~61.5Hz */
        ZP_33++;                            /*   mainline frame gate       */

    /* coin routine unless disabled (LANGBT bit 7) or in self-test */
    if (!(LANGBT & 0x80) && (sd_hw_in0() & 0x10))
        coin_routine();                     /* L8660 JSR L741A             */

    if (TOTOBJ == 0) {                      /* L8663: once per 256 ticks   */
        SECOND++;                           /*   (~1.04 s)                 */
        if ((SECOND & 0x03) == 0) {         /* every ~4 s: BCD bookkeeping */
            int c = 0;                      /* L8671 CLC ... SED           */
            if (!(ZP_35 & 0x80)) {          /* on-time only outside a game */
                bcd_res r = bcd_adc(g.ram[A_EAREQU], 0x01, 0);
                g.ram[A_EAREQU] = r.r; c = r.c;
                r = bcd_adc(g.ram[A_EARWRQ], 0x00, c);
                g.ram[A_EARWRQ] = r.r; c = r.c;
                r = bcd_adc(g.ram[A_EABAD], 0x00, c);
                g.ram[A_EABAD] = r.r; c = r.c;
                r = bcd_adc(g.ram[A_EAFLG], 0x00, c);
                g.ram[A_EAFLG] = r.r;
                c = 0;                      /* L8697 CLC                   */
            }
            {                               /* game time, 4 s BCD counts   */
                bcd_res r = bcd_adc(GTIME, 0x01, c);
                GTIME = r.r; c = r.c;
                if (r.n) {                  /* L86A0 BPL: past 79 counts   */
                    SCSHSP = 0x80;          /*   saucers mad now           */
                    g.ram[0x39E] = 0x80;
                }
                r = bcd_adc(g.ram[0x3B1], 0x00, c);
                g.ram[0x3B1] = r.r; c = r.c;
                r = bcd_adc(g.ram[0x3B2], 0x00, c);
                g.ram[0x3B2] = r.r; c = r.c;
                r = bcd_adc(g.ram[0x3B3], 0x00, c);
                g.ram[0x3B3] = r.r;
            }                               /* L86C2 CLD                   */
        }
    }

    /* ship rotation, both players (X = 1 then 0) */
    for (int x = 1; x >= 0; x--) {
        /* damaged ships only rotate on alternate tick pairs (flicker) */
        if (g.ram[A_PRTDAMAGE + x] != 0 && (TOTOBJ & 0x02) != 0)
            continue;                       /* L86CE BNE Irq_18            */

        /* left (Irq_12): game reads ROTL,X bit 7; attract uses $44 bit 7 */
        if (ZP_35 & 0x80) {
            if (sd_hw_in1((uint8_t)(2 + x)) & 0x80)
                g.ram[A_IANGLE + x]++;
        } else if (ZP_44 & 0x80) {
            g.ram[A_IANGLE + x]++;
        }
        /* right (Irq_14): game reads ROTL,X bit 6; attract uses $44 bit 5 */
        if (ZP_35 & 0x80) {
            if (sd_hw_in1((uint8_t)(2 + x)) & 0x40)
                g.ram[A_IANGLE + x]--;
        } else if (ZP_44 & 0x20) {
            g.ram[A_IANGLE + x]--;
        }
    }

    if (sd_hw_in0() & 0x10)                 /* not in self-test            */
        continue_sounds();                  /* L8703                       */

    /* mirror the instantaneous angles for the mainline */
    a = g.ram[A_IANGLE];
    SANGLE = a;                             /* L8709 STA SANGLE ($2A3)     */
    if (!(ZP_51 & 0x80))                    /* BIT $51: separate angles    */
        a = g.ram[0x3D1];
    g.ram[0x2A4] = a;                       /* L8713 (SANGLE+1)            */
}
