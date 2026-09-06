/* sound.c - Space Duel C port: the sound module (AS2SAC/AS2POK, $703C-$7419).
 *
 * The sound engine is a 16-channel script player driven once per IRQ:
 *
 *   g.ram[$56+ch]  script pointer   (0 = channel idle; $56 = POINT, and the
 *                                    named cells $0058 $58, $005A $5A,
 *                                    $005B $5B ... are channels 2,4,5 ...
 *                                    of this array)
 *   g.ram[$66+ch]  current register value (AUDF for even ch, AUDC for odd)
 *   g.ram[$76+ch]  steps left in the current script entry
 *   g.ram[$86+ch]  IRQ ticks left in the current step
 *   g.ram[$96]     channel-under-construction interlock ($FF = none)
 *
 * Channels 0-7 map to POKEY1 registers $1000-$1007, channels 8-15 to POKEY2
 * $1400-$1407 (the ROM writes $13F8,X for X>=8). A script entry is 4 bytes
 * at $719B + pointer*2 (the ASL carry picks the $729B bank, i.e. one
 * seamless 9-bit address space): value, tick count, per-step delta, step
 * count. Tick count 0 ends the script; its value byte, if nonzero, is a
 * restart pointer (looping scripts).
 *
 * ROM bytes (script tables, the $70C1 code->channel map, the Time table)
 * come from the generated sd_sndrom[] blob - see tools/gen_sound_data.py.
 */
#include "sd_state.h"
#include "sd_hw.h"
#include "sound.h"
#include "sound_data.h"
#include "samples.h"    /* sd_sample_* recorded-sample hooks (host-side
                         * seam: no machine state touched - see SOUNDS.md) */

/* ------------------------------------------------------------------ */
/* AlwaysRemainsSameBoth ($703C)                                       */
/* ------------------------------------------------------------------ */

/* Super-saucer twin: when SUPRSAC bit 7 is set, mirror saucer object $1F's
 * position/velocity into object $20 and its four shells ($24-$27), and set
 * the shot timer from the Time table ($7083, indexed $707F+SUPRDIS).
 * Caller's X (object index) is stack-saved by the ROM - register only. */
void always_remains_same_both(void)
{
    uint8_t a, y, d;
    int i;

    if (!(SUPRSAC & 0x80))               /* L703C BIT SUPRSAC / BPL rts     */
        return;
    g.ram[0xB7] = 0x41;                  /* L7041: activate other saucer    */
    a = g.ram[0x33F];                    /* L7045 OBJXL+$1F                 */
    g.ram[0x340] = a;                    /* L7048 OBJXL+$20                 */
    TEMP9 = a;                            /* L704B save A                    */
    y = g.ram[0x2D4];                    /* L704D OBJXH+$1F                 */
    g.ram[0x2D5] = y;                    /* L7050 OBJXH+$20                 */
    /* L7053 TXA/PHA ... L7080 PLA/TAX: caller X preserved, register only  */
    for (i = 3; i >= 0; i--) {           /* L7055 LDX #$03                  */
        g.ram[0x344 + i] = TEMP9;         /* L7057/59: shells OBJXL+$24..$27 */
        g.ram[0x2D9 + i] = y;            /* L705C/5D: shells OBJXH+$24..$27 */
    }
    d = SUPRDIS;                         /* L7063 CLC / L7064 LDA / TAX     */
    g.ram[0x307] = (uint8_t)(d + g.ram[0x306]); /* L7068/6B OBJYH+$1F->$20  */
    g.ram[0x372] = g.ram[0x371];         /* L706E/71 OBJYL+$1F -> +$20      */
    g.ram[0x220] = g.ram[0x21F];         /* L7074/77 XINC+$1F -> +$20       */
    SUPRTIM = SNDROM(0x707F + d);        /* L707A/7D: Time[$7083], d >= 4   */
}

/* ------------------------------------------------------------------ */
/* L2Saucers ($7091)                                                   */
/* ------------------------------------------------------------------ */

/* Step each active saucer's X velocity ($21F+X) one count toward the signed
 * minimum velocity ($D3+X). The ROM compares with SEC/SBC and fixes the
 * sign with the BVC/EOR #$80 idiom; V is modeled exactly. */
void l2_saucers(void)
{
    int x;

    for (x = 1; x >= 0; x--) {           /* L7091 LDX #$01 ... L7098 BPL    */
        uint8_t m, vel, r, eff;
        int v;

        if (g.ram[0xB6 + x] == 0)        /* L7093: saucer active flag       */
            continue;
        m   = g.ram[0xD3 + x];           /* L709C: minimum velocity, signed */
        vel = g.ram[0x21F + x];          /* XINC+$1F+X                      */
        r   = (uint8_t)(m - vel);        /* SEC / SBC $021F,X               */
        v   = ((m ^ vel) & (m ^ r) & 0x80) != 0;   /* 6502 V of the SBC     */
        eff = v ? (uint8_t)(r ^ 0x80) : r;         /* BVC skip / EOR #$80   */
        if (m & 0x80) {                  /* L709E BPL L2Saucers_30          */
            if (eff & 0x80)              /* L70A7 BPL _15 / else DEC        */
                g.ram[0x21F + x]--;
        } else {
            if (r == 0)                  /* L70B2 BEQ _15 (raw result)      */
                continue;
            if (!(eff & 0x80))           /* L70B8 BMI _15 / else INC        */
                g.ram[0x21F + x]++;
        }
    }
}

/* ------------------------------------------------------------------ */
/* trigger stubs ($72B9-$72EF)                                         */
/* ------------------------------------------------------------------ */

/* RandomFuzz ($6B45): the burning-rod fuse crackle - on a 1-in-8 POKEY1
 * RANDOM draw, fire the fuse sound of whichever rigid-pair ship is still
 * alive.  The RANDOM read happens on EVERY call (LFSR-visible).  x_in /
 * y_in are the caller's live 6502 X/Y, passed through to the FusePlyr
 * trigger's TEMPA/TEMPB parking (Drawrod calls with X = TEMP3, Y = the
 * TEMP2 leftover it also hands Explosion). */
void random_fuzz(uint8_t x_in, uint8_t y_in)
{
    if ((sd_hw_pokey_random(0) & 0x07) != 0)    /* L6B45/48 LDA $100A/AND  */
        return;                                 /* L6B4C RTS: not time     */
    if (g.ram[0xB8] & 0x80)                     /* L6B4D: is this one dead? */
        fuse_plyr0(x_in, y_in);                 /* L6B54 JMP (yes)         */
    else
        fuse_plyr1(x_in, y_in);                 /* L6B51 JMP               */
}

/* StopFuseSound ($6B57): kill the fuse - stop the channel-0/1/6/7 script
 * pointers and silence POKEY1 AUDC1/AUDC4 directly. */
void stop_fuse_sound(void)
{
    sd_sample_fuse_stop();                      /* host sample seam        */
    POINT = 0x00;                               /* L6B59: channel 0 ($56)  */
    g.ram[0x57] = 0x00;                         /* L6B5B: channel 1        */
    (g.ram[0x005C]) = 0x00;                              /* L6B5D: channel 6 ($5C)  */
    (g.ram[0x005D]) = 0x00;                              /* L6B5F: channel 7 ($5D)  */
    sd_hw_pokey_write(0, 0x01, 0x00);           /* L6B61 STA $1001 (AUDC1) */
    sd_hw_pokey_write(0, 0x07, 0x00);           /* L6B64 STA $1007 (AUDC4) */
}

void popsn(uint8_t x_in, uint8_t y_in)        { high_score_tune(0xDF, x_in, y_in); } /* Popsn       $72B9 */
void fuse_plyr1(uint8_t x_in, uint8_t y_in)   { high_score_tune(0x9F, x_in, y_in); } /* FusePlyr1   $72BD */
void fuse_plyr0(uint8_t x_in, uint8_t y_in)   { high_score_tune(0x8F, x_in, y_in); } /* FusePlyr0   $72C1 */
void reenter(uint8_t x_in, uint8_t y_in)      { high_score_tune(0x4F, x_in, y_in); } /* Reenter     $72C5 */
void reenter2(uint8_t x_in, uint8_t y_in)     { high_score_tune(0x3F, x_in, y_in); } /* Reenter2    $72C9 */
void sh0sn(uint8_t x_in, uint8_t y_in)        { high_score_tune(0xBF, x_in, y_in); } /* Sh0sn       $72CD */
void sh1sn(uint8_t x_in, uint8_t y_in)        { high_score_tune(0xCF, x_in, y_in); } /* Sh1sn       $72D1 */
void saucer_fire(uint8_t x_in, uint8_t y_in)  { high_score_tune(0x0F, x_in, y_in); } /* SaucerFire  $72D5 */
void player0_fire(uint8_t x_in, uint8_t y_in) { high_score_tune(0x1F, x_in, y_in); } /* Player0Fire $72D9 */
void player1_fire(uint8_t x_in, uint8_t y_in) { high_score_tune(0x2F, x_in, y_in); } /* Player1Fire $72DD */
void extra_life2(uint8_t x_in, uint8_t y_in)  { high_score_tune(0x5F, x_in, y_in); } /* ExtraLife2  $72E1 */
void explosion(uint8_t x_in, uint8_t y_in)    { high_score_tune(0x6F, x_in, y_in); } /* Explosion   $72E5 */
void thrust_sound(uint8_t x_in, uint8_t y_in) { high_score_tune(0x7F, x_in, y_in); } /* ThrustSound $72E9 */
void gates(uint8_t x_in, uint8_t y_in)        { high_score_tune(0xAF, x_in, y_in); } /* Gates       $72ED */

/* ------------------------------------------------------------------ */
/* HighScoreTune ($72F1) / Badhab ($72FA)                              */
/* ------------------------------------------------------------------ */

/* HighScoreTune ($72F1): sounds play in game, or any time while the
 * high-score tune is up; in plain attract mode this is a pure no-op
 * (no RAM touched at all - the early-out skips Badhab's TEMPA/6 parks). */
void high_score_tune(uint8_t code, uint8_t x_in, uint8_t y_in)
{
    if (!(HSCFLG & 0x80)) {              /* L72F1 BIT HSCFLG / BMI Badhab   */
        if (!(ZP_35 & 0x80))             /* L72F6 BIT $35 / BPL L731C (rts) */
            return;
    }
    badhab(code, x_in, y_in);
}

/* Badhab ($72FA): start the sound. Scans channels 15..0 against the
 * code->channel map at $70C1 (row = code high nibble); a nonzero map byte
 * is the channel's script pointer. $86/$76 are seeded to 1 so the next
 * continue_sounds() tick performs the real first script fetch ("DUMMY
 * START, NO SOUND TILL MODSND STORES TO POKEY"). $96 interlocks the
 * channel against the IRQ while it is half-built. */
void badhab(uint8_t code, uint8_t x_in, uint8_t y_in)
{
    uint8_t y;
    int x;

    sd_sample_trigger(code);             /* host sample seam (samples.c)    */
    TEMPA = x_in;                        /* L72FA STX TEMPA (caller's X)    */
    TEMPB = y_in;                        /* L72FC STY TEMPB (caller's Y)    */
    y = code;                            /* L72FE TAY                       */
    for (x = 0x0F; x >= 0; x--, y--) {   /* L72FF LDX #$0F ... L7316 BPL    */
        uint8_t p = SNDROM(0x70C1 + y);  /* L7301                           */
        if (p != 0) {
            g.ram[0x96] = (uint8_t)x;    /* L7306: interlock this channel   */
            g.ram[0x56 + x] = p;         /* L7308: script pointer (POINT,X) */
            g.ram[0x86 + x] = 0x01;      /* L730C: dummy tick count         */
            g.ram[0x76 + x] = 0x01;      /* L730E: dummy step count         */
            g.ram[0x96] = 0xFF;          /* L7312: interlock off            */
        }
    }
    /* L7318 LDX TEMPA / L731A LDY TEMPB: register restore only            */
}

/* ------------------------------------------------------------------ */
/* ContinuesPreviouslyStartedSound ($731D)                             */
/* ------------------------------------------------------------------ */

/* YesStartValue ($732F): fetch the channel's next script entry (pointer
 * advances by 2 per entry; entry address = $719B + pointer*2, the ASL
 * carry selecting the $729B bank = seamless +$100). A tick count of 0
 * ends the script: pointer is cleared, and the entry's value byte, if
 * nonzero, restarts the script there (BNE YesStartValue loop). Falls
 * through to the POKEY register update (L7392) in the caller. */
static void yes_start_value(int x)
{
    for (;;) {
        uint8_t p, fc;
        uint16_t base;

        p = (uint8_t)(g.ram[0x56 + x] + 2);  /* L732F/31 INC POINT,X twice  */
        g.ram[0x56 + x] = p;
        base = (uint16_t)(0x719B + ((uint16_t)p << 1)); /* L7335 ASL / TAY  */
        g.ram[0x66 + x] = SNDROM(base);      /* L7339/49: new value         */
        g.ram[0x76 + x] = SNDROM(base + 3);  /* L733E/4E: step count        */
        fc = SNDROM(base + 1);               /* L7343/53: tick count        */
        g.ram[0x86 + x] = fc;                /* L7356                       */
        if (fc != 0)                         /* L7358 BNE L7364             */
            return;
        g.ram[0x56 + x] = 0;                 /* L735A: kill channel (A=0)   */
        if (g.ram[0x66 + x] == 0)            /* L735C/5E: restart pointer?  */
            return;
        g.ram[0x56 + x] = g.ram[0x66 + x];   /* L7360: restart script       */
    }                                        /* L7362 BNE YesStartValue     */
}

/* ContinuesPreviouslyStartedSound ($731D): called every IRQ tick from
 * sd_irq ($8703) outside self-test. For each scripted channel, count down
 * the tick counter; on expiry either apply the entry's delta to the value
 * (odd channels = AUDC keep their old high nibble - distortion bits - and
 * take only the new low nibble = volume) or fetch the next entry, then
 * store the value to the channel's POKEY register.
 * sub_731f ($731F) and sub_73a1 ($73A1) are the loop's internal JMP
 * targets (L73A4/L739B) - control flow here, not separate entries. */
void continue_sounds(void)
{
    int x;

    for (x = 0x0F; x >= 0; x--) {        /* L731D LDX #$0F; L73A1 DEX/BMI   */
        uint8_t ptr, v;

        ptr = g.ram[0x56 + x];           /* L731F LDA POINT,X               */
        if (ptr == 0)                    /* BEQ L73A1: channel idle         */
            continue;
        if ((uint8_t)x == g.ram[0x96])   /* L7323 CPX $96: being built      */
            continue;
        if (--g.ram[0x86 + x] != 0)      /* L7327 DEC / BNE L73A1           */
            continue;
        if (--g.ram[0x76 + x] != 0) {    /* L732B DEC / BNE L7367           */
            /* L7367: another step of the same entry - apply the delta      */
            uint16_t base = (uint16_t)(0x719B + ((uint16_t)ptr << 1));
            uint8_t delta, oldv;

            g.ram[0x86 + x] = SNDROM(base + 1);  /* L736B/79: reload ticks  */
            delta = SNDROM(base + 2);            /* L7370/7B                */
            oldv = g.ram[0x66 + x];              /* L737E LDY $66,X         */
            v = (uint8_t)(oldv + delta);         /* L7380 CLC / ADC $66,X   */
            g.ram[0x66 + x] = v;                 /* L7383                   */
            if (x & 1) {                 /* L7385 TXA/LSR/BCC L7392         */
                /* odd channel = AUDC: keep OLD high nibble (distortion),
                 * take new low nibble (volume). L7389-L7390.               */
                v = (uint8_t)(((oldv ^ v) & 0xF0) ^ v);
                g.ram[0x66 + x] = v;
            }
        } else {
            yes_start_value(x);          /* L732F                           */
        }
        /* L7392: update the POKEY audio channel                            */
        v = g.ram[0x66 + x];
        if (x >= 8)                      /* L7394 CPX #$08 / BCC            */
            sd_hw_pokey_write(1, (uint8_t)(x - 8), v);  /* L7398 $13F8,X    */
        else
            sd_hw_pokey_write(0, (uint8_t)x, v);        /* L739E POKEY,X    */
    }
}

/* ------------------------------------------------------------------ */
/* Inisou ($73A8)                                                      */
/* ------------------------------------------------------------------ */

/* Silence both POKEYs: SKCTL 0 then 7 (reset/normal), audio registers
 * $x000-$x007 cleared, AUDCTL cleared, and script pointers + values of
 * channels 0-7 zeroed. Quirk kept: the LDX #$07 loop leaves channels
 * 8-15's script cells ($5E-$65/$6E-$75) alone, so POKEY2 scripts survive
 * an Inisou and keep running under continue_sounds. */
void inisou(void)
{
    int x;

    sd_sample_stop_all();                /* host sample seam                */
    sd_hw_pokey_write(0, 0x0F, 0x00);    /* L73AA STA $100F (SKCTL1)        */
    sd_hw_pokey_write(1, 0x0F, 0x00);    /* L73AD STA $140F (SKCTL2)        */
    sd_hw_pokey_write(0, 0x0F, 0x07);    /* L73B2                           */
    sd_hw_pokey_write(1, 0x0F, 0x07);    /* L73B5                           */
    for (x = 7; x >= 0; x--) {           /* L73B8 LDX #$07 ... L73C7 BPL    */
        sd_hw_pokey_write(0, (uint8_t)x, 0x00);  /* L73BC STA POKEY,X       */
        sd_hw_pokey_write(1, (uint8_t)x, 0x00);  /* L73BF STA POKEY2,X      */
        g.ram[0x56 + x] = 0;             /* L73C2 STA POINT,X (script ptr)  */
        g.ram[0x66 + x] = 0;             /* L73C4 STA $66,X (channel value) */
    }
    sd_hw_pokey_write(0, 0x08, 0x00);    /* L73CB STA $1008 (AUDCTL1)       */
    sd_hw_pokey_write(1, 0x08, 0x00);    /* L73D0 STX $1408 (AUDCTL2, X=0)  */
}

/* ------------------------------------------------------------------ */
/* ForceFieldUp ($73D4)                                                */
/* ------------------------------------------------------------------ */

/* The force-field hum, called once per mainline frame ($4107). While
 * COMTIMER runs: POKEY2 AUDCTL=1 (15 kHz base lowers the hum), the hum
 * divider SFREQ walks down to $30 every 8th frame ($44 mask 7) - lower
 * divider = rising pitch - and AUDF2/AUDC2 get SFREQ/$A3. When idle:
 * AUDF2/AUDC2/AUDCTL and SFREQ are cleared. Either way the same tone is
 * echoed on POKEY1 AUDF3/AUDC3 (value+1 / tone), unless sound channel 4
 * ($5A = $005A, POKEY1 AUDF3's script cell) is in use. */
void force_field_up(void)
{
    uint8_t a, xreg;

    sd_sample_hum(COMTIMER != 0, SFREQ); /* host sample seam (per frame)    */
    if (COMTIMER == 0) {                 /* L73D4/BNE _10                   */
        sd_hw_pokey_write(1, 0x02, 0x00);/* L73D9 STA $1402 (AUDF2) off     */
        sd_hw_pokey_write(1, 0x03, 0x00);/* L73DC STA $1403 (AUDC2)         */
        SFREQ = 0;                       /* L73DF                           */
        sd_hw_pokey_write(1, 0x08, 0x00);/* L73E2 STA $1408: normal freq    */
        xreg = 0;                        /* L73E5 TAX                       */
        a = 0xFF;                        /* L73E6 (+1 below wraps to 0)     */
    } else {
        /* ForceFieldUp_10 ($73EA)                                          */
        sd_hw_pokey_write(1, 0x08, 0x01);/* L73EC: lower freq of hum        */
        if ((ZP_44 & 0x07) == 0) {       /* L73EF/F1: every 8th frame       */
            a = SFREQ;                   /* L73F5: up freq                  */
            if (a >= 0x30)               /* L73F8 CMP #$30 / BCC (max)      */
                SFREQ = (uint8_t)(a - 1);/* L73FC SBC #$01 / STA            */
        }
        /* ForceFieldUp_20 ($7401)                                          */
        a = SFREQ;                       /* L7401                           */
        sd_hw_pokey_write(1, 0x02, a);   /* L7404 STA $1402 (AUDF2)         */
        xreg = 0xA3;                     /* L7407: tone                     */
        sd_hw_pokey_write(1, 0x03, xreg);/* L7409 STX $1403 (AUDC2)         */
    }
    /* ForceFieldUp_25 ($740C)                                              */
    if (g.ram[0x5A] != 0)                /* L740C LDY $005A: chan 4 busy */
        return;                          /* L740E BNE _40 (rts)             */
    a = (uint8_t)(a + 1);                /* L7410 CLC / ADC #$01            */
    sd_hw_pokey_write(0, 0x04, a);       /* L7413 STA $1004 (AUDF3)         */
    sd_hw_pokey_write(0, 0x05, xreg);    /* L7416 STX $1005 (AUDC3)         */
}
