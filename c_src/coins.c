/* coins.c - Space Duel C port: the coin/credit routine (COIN65, $741A-$7528).
 *
 * State (all zero page, all oracle-diffed):
 *   DIAGBI  $20      credits
 *   ZSHIP  $21      coin-routine call counter (per IRQ)
 *   $0022 $22      bonus-adder unit-coin accumulator
 *   ZPAIR  $23      bonus coins earned
 *   ZMINE  $24      coin option byte: d0-d1 coin mode (0 free play, 1 = 2
 *                   credits/coin, 2 = 1 credit/coin, 3 = 1 credit/2 coins),
 *                   d2-d3 right-mech multiplier (x1/x4/x5/x6), d4 center-
 *                   mech multiplier (x1/x2), d5-d7 bonus-adder mode
 *   $0025  $25      pre-coin slam timer (shared by all mechs)
 *   $0026  $26      unit-coin count (CNCT)
 *   $27+X  ($0027)  per-mech EM coin-counter pulse cell: low nibble =
 *                   pulses pending, high nibble = pulse on-time
 *   $2A+X           per-mech post-coin slam timer
 *   $2D+X           per-mech coin status: d0-d4 coin-on down-counter
 *                   (starts $1F), d5-d7 coin-off up-counter
 *
 * Mech index X runs 2,1,0 = IN0 coin bits d0,d1,d2 (X=0 is the left mech).
 * Inputs are ACTIVE LOW: coin bit high = coin absent, IN0 d3 high = slam
 * switch off. NOTES_oracle.md: the oracle idles IN0 low, so the slam input
 * reads active and $0025 is reloaded to $F0 every IRQ, zeroing $2A-$2F -
 * that polarity is deliberate and reproduced here (IN0 is re-read from the
 * seam for every mech and again for the slam check, exactly like the ROM).
 */
#include "sd_state.h"
#include "sd_hw.h"
#include "coins.h"

/* NumberUnitCoinsRequired ($74CF): unit-coins needed per bonus-adder mode.
 * Inlined 8-byte table, byte-checked against spacduel_64k.bin by
 * tools/gen_sound_data.py ($7F = "never" sentinel). */
static const uint8_t number_unit_coins_required[8] = {
    0x7F, 0x02, 0x04, 0x04, 0x05, 0x03, 0x7F, 0x7F
};

/* Ext ($74FA): every second call, run the EM coin-counter pulse timers in
 * $27-$29. Phase 1 decrements the on-time of any running pulse (high
 * nibble, cell >= $10); if none is running, phase 2 starts one pending
 * pulse (adds $EF: moves a count from the low nibble into a full-length
 * high nibble) - at most one, so pulses never overlap. */
static void ext(void)
{
    uint8_t on;
    int x;

    ZSHIP++;                             /* L74FA INC ZSHIP                 */
    if (ZSHIP & 0x01)                    /* L74FC/FE LSR / BCS Ext_99       */
        return;
    on = 0;                              /* L7501 LDY #$00                  */
    for (x = 2; x >= 0; x--) {           /* L7503 LDX #$02 ... L7513 BPL    */
        uint8_t t = g.ram[0x0027 + x];  /* L7505                           */
        if (t == 0)                      /* BEQ Ext_3                       */
            continue;
        if (t < 0x10)                    /* L7509 CMP #$10 / BCC: pending   */
            continue;
        t = (uint8_t)(t + 0xF0);         /* L750D ADC #$EF (C=1): dec MSBs  */
        on++;                            /* L750F INY: a pulse is running   */
        g.ram[0x0027 + x] = t;          /* L7510                           */
    }
    if (on != 0)                         /* L7515/16: skip if any on        */
        return;
    for (x = 2; x >= 0; x--) {           /* L7518 LDX #$02 ... L7526 BPL    */
        uint8_t t = g.ram[0x0027 + x];  /* L751A                           */
        if (t == 0)                      /* BEQ Ext_5                       */
            continue;
        t = (uint8_t)(t + 0xEF);         /* L751E CLC / ADC #$EF: start it  */
        g.ram[0x0027 + x] = t;          /* L7521                           */
        if (t & 0x80)                    /* L7523 BMI Ext_99: only one      */
            return;
    }
}

/* Extb ($74D7): convert unit-coins to credits. Price = 1 unit-coin in
 * modes 1 and 2, 2 in mode 3; mode 1 pays two credits. Bonus coins
 * (ZPAIR) can cover a shortfall. Mode 0 = free play: CNCT is cleared
 * (the L74DC BEQ lands on L_2's STA $0026 with A = 0). Falls into Ext. */
static void extb(void)
{
    uint8_t mode, a;

    mode = (uint8_t)(ZMINE & 0x03);      /* L74D7/D9, TAY at L74DB          */
    if (mode == 0) {                     /* L74DC BEQ L_2: free play        */
        a = 0;
    } else {
        uint8_t price = (uint8_t)((mode >> 1) + (mode & 0x01)); /* L74DE/DF */
        unsigned diff = (unsigned)(g.ram[0x0026]) + (unsigned)(uint8_t)~price + 1u;
        a = (uint8_t)diff;               /* L74E1-E4 EOR/SEC/ADC $0026      */
        if (diff <= 0xFF) {              /* L74E6 BCS L_33: borrow taken    */
            a = (uint8_t)(a + ZPAIR);    /* L74E8 ADC ZPAIR (C=0)           */
            if (a & 0x80) {              /* L74EA BMI Ext: still short      */
                ext();
                return;
            }
            ZPAIR = a;                   /* L74EC: unused bonus coins       */
            a = 0;                       /* L74EE: new CNCT                 */
        }
        /* L_33 ($74F0)                                                     */
        if (mode < 2)                    /* CPY #$02 / BCS L_1              */
            DIAGBI++;                     /* L74F4: mode 1 gives 2           */
        DIAGBI++;                         /* L_1 ($74F6)                     */
    }
    (g.ram[0x0026]) = a;                           /* L_2 ($74F8): update CNCT        */
    ext();
}

/* GetBonusAdderMode ($74B3): when enough unit-coins accumulated for the
 * DIP bonus mode, grant a bonus coin (two in mode 3). Falls into Extb.
 * (The ROM's closing BNE Extb assumes the INC ZPAIR result is nonzero.) */
static void get_bonus_adder_mode(void)
{
    uint8_t y, a;

    y = (uint8_t)(ZMINE >> 5);           /* L74B3-BA: bonus mode, TAY       */
    a = (uint8_t)((g.ram[0x0022]) - number_unit_coins_required[y]); /* L74BB-BE      */
    if (!(a & 0x80)) {                   /* L74C1 BMI Extb: not enough      */
        (g.ram[0x0022]) = a;                      /* L74C3                           */
        ZPAIR++;                         /* L74C5                           */
        if (y == 0x03)                   /* L74C7 CPY #$03 / BNE Extb       */
            ZPAIR++;                     /* L74CB: 2 bonus for 4 inserted   */
    }
    extb();
}

/* L741A: the per-IRQ coin routine (see file header). The per-mech
 * debounce/validation state machine is InstructionsBracketsAreIllustration
 * ($7428); the loop re-enters at L741C for each mech. */
void coin_routine(void)
{
    int x;

    for (x = 2; x >= 0; x--) {           /* L741A LDX #$02; L74B0 JMP L741C */
        uint8_t in0, a;
        int coin_absent, credit;

        in0 = sd_hw_in0();               /* L741C LDA HALT                  */
        /* L741F-L7427: CPX/LSRs leave the mech's coin bit in carry -
         * X=2 one LSR (d0), X=1 two (d1), X=0 three (d2). 1 = absent.     */
        coin_absent = (in0 >> (2 - x)) & 0x01;
        a = (uint8_t)(g.ram[0x2D + x] & 0x1F); /* L7428/2A coin status     */

        if (coin_absent) {               /* L742C BCS _5                    */
            /* InstructionsBracketsAreIllustration_5 ($7465)                */
            if (a >= 0x1B) {             /* CMP #$1B / BCS _6: too short    */
                a = 0x1F;                /* _6: reset down-counter -> _1    */
            } else {
                unsigned sum = (unsigned)g.ram[0x2D + x] + 0x20;
                a = (uint8_t)sum;        /* L7469/6B ADC #$20 (C=0): bump
                                          * the coin-off up-counter         */
                if (sum > 0xFF) {        /* L746D BCC _1: no wrap -> store  */
                    if (a == 0) {        /* L746F BEQ _6: on too long       */
                        a = 0x1F;        /* _6 (C=1) -> _1: just reset      */
                    } else {
                        /* L7471 CLC; _6 falls through: a VALID coin-off    */
                        g.ram[0x2D + x] = 0x1F;          /* L7472/76        */
                        credit = (g.ram[0x2A + x] != 0); /* L7478/7C: give
                                          * credit a little early if the
                                          * post-coin timer is running      */
                        g.ram[0x2A + x] = 0x78;          /* L747D/7F        */
                        goto tally;      /* falls into _8                   */
                    }
                }
            }
        } else {
            /* coin present: run the down-counter                           */
            if (a != 0) {                /* L742E BEQ _1: stick at 0        */
                if (a >= 0x1B)           /* L7430 CMP #$1B / BCS _10        */
                    a--;                 /* _10 SBC #$01 (C=1): run fast    */
                else if ((ZSHIP & 0x07) == 0x07) /* L7435-3C: 1 per 8 IRQs  */
                    a--;
            }
        }
        g.ram[0x2D + x] = a;             /* _1 ($7440) STA $2D,X            */

        /* slam switch (IN0 re-read, d3 low = active)                       */
        if (!(sd_hw_in0() & 0x08))       /* L7442/45/47                     */
            (g.ram[0x0025]) = 0xF0;                /* L7449/4B: pre-coin slam timer   */
        /* _2 ($744D)                                                       */
        if ((g.ram[0x0025]) != 0) {
            (g.ram[0x0025])--;                     /* L7451                           */
            g.ram[0x2D + x] = 0;         /* L7455: clear coin status        */
            g.ram[0x2A + x] = 0;         /* L7457: clear post-coin timer    */
        }
        /* _3 ($7459): run the post-coin slam timer; expiry = a coin        */
        credit = 0;                      /* CLC: default no coin            */
        if (g.ram[0x2A + x] != 0) {      /* L745A/5C                        */
            if (--g.ram[0x2A + x] == 0)  /* L745E/60                        */
                credit = 1;              /* L7462 SEC                       */
        }

tally:  /* _8 ($7481)                                                       */
        if (credit) {                    /* BCC _9                          */
            uint8_t units = 0;           /* L7483 LDA #$00 (to add 1)       */
            if (x == 1) {                /* L7485/89: center mech           */
                if (ZMINE & 0x10)        /* L7497/99: x2 multiplier         */
                    units = 0x01;        /* L749D                           */
            } else if (x == 2) {         /* right mech: _83/_85 ($748B)     */
                uint8_t m = (uint8_t)((ZMINE & 0x0C) >> 2);
                if (m != 0)              /* L7491 BEQ: x1                   */
                    units = (uint8_t)(m + 0x02); /* L7493: x4/x5/x6         */
            }
            /* (x == 0, left mech: always 1 unit - L7487 BCC L749F)         */
            /* L749F SEC/PHA/ADC/STA/PLA/SEC/ADC/STA: add units+1 to both   */
            (g.ram[0x0022]) = (uint8_t)((g.ram[0x0022]) + units + 1); /* bonus-adder counter  */
            (g.ram[0x0026])  = (uint8_t)((g.ram[0x0026]) + units + 1);  /* CNCT                 */
            g.ram[0x0027 + x]++;        /* L74AB: queue an EM pulse        */
        }
        /* _9 ($74AD) DEX / BMI GetBonusAdderMode / JMP L741C               */
    }
    get_bonus_adder_mode();
}
