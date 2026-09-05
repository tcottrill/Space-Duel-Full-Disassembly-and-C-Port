/* selftest.c - Space Duel C port: the self-test module (AS2TST, Owen Rubin).
 *
 * ROM regions owned here:
 *   $8110-$82CF  BeginningPattern .. Ok2: power-on RAM marches, ROM EOR
 *                checksums, POKEY RANDOM and EAROM checks
 *   $82D2-$8636  the six diagnostic screens (Stest5, Cocktail, Stest7,
 *                Stest8, SetScale1, Stst10), Optn2, CenterBeam, Swtst,
 *                MainLineDiagLoop, Sftjse
 *   $89B9-$8C61  Averag, AllStopPlease / St2 (the bookkeeping screen)
 *   $8C80-$8D32  Set0Balnking, MultiplyBy2Decimal, Times4Decimal,
 *                OptionSelected + Clear*, CorrectMessageAndColor
 *   $8D33-$8E41  signature analysis
 *   $8F43        the difficulty-switch read
 *
 * Frame model: see selftest.h. Hardware only through sd_hw.h; the two seam
 * calls this module adds are sd_wait_3khz() (the $8592 frame timer) and
 * sd_hw_reset() (the two places the ROM restarts the CPU at Poweron).
 *
 * NOT translated, deliberately: the RAM-error reporters (BeginningPattern_5
 * .. NoiseLowerNibbleStatus $8141-$8185, L04_20 .. NoWtchdgdog $81C3-$8243)
 * and the ROM-error tone at JustLabel $8290. They report faults in the
 * memory chips by counting beeps on POKEY1; the port's RAM is the host's and
 * the ROM bytes are constants carried in sd_progrom.c, so the comparisons
 * that reach them cannot fail here. The successful path reproduces every
 * store the marches make (the $88 the full march leaves in every cell of
 * vector RAM included).
 */
#include "sd_state.h"
#include "sd_hw.h"
#include "sd_bcd.h"
#include "vgutil.h"
#include "selftest.h"
#include "sd_vecrom.h"
#include "sd_progrom.h"
#include "earom.h"
#include "mainline.h"
#include "msgs.h"
#include "score.h"
#include "sound.h"

extern void sd_irq(void);                    /* irq.c: Irq $8639 - the BRK vector too */

/* ------------------------------------------------------------------ */
/* where the CPU is parked                                             */
/* ------------------------------------------------------------------ */

/* The one piece of state that is not machine RAM: which of the ROM's
 * infinite loops the CPU sits in. On the 6502 that is the program counter;
 * the frame driver needs it to know which pass to run next. */
static enum sd_cpu_loop cpu_loop = SD_LOOP_START2;

int  sd_cpu_loop(void)       { return (int)cpu_loop; }
void sd_cpu_loop_reset(void) { cpu_loop = SD_LOOP_START2; }

/* ------------------------------------------------------------------ */
/* small helpers                                                       */
/* ------------------------------------------------------------------ */

/* LDA abs,X / (ptr),Y over the ROM: the vector ROM, the program ROM and its
 * $9000-$FFFF mirror (the 4 KB at $8000 supplies the vectors). */
static uint8_t rom_byte(uint16_t a)
{
    if (a >= 0x2800u && a < 0x4000u) return sd_vecrom[a - 0x2800u];
    if (a >= 0x4000u && a < 0x9000u) return sd_progrom[a - 0x4000u];
    if (a >= 0x9000u)                return sd_progrom[0x4000u + (a & 0x0FFFu)];
    return 0;                                /* RAM/IO: no caller reads there */
}

/* STA to a raw POKEY address: $1000-$13FF is POKEY1 (mirrored), $1400-$17FF
 * POKEY2; the register is the low nibble. Stest8 writes through such
 * "fake" addresses ($13F0,Y). */
static void pokey_write_addr(uint16_t addr, uint8_t v)
{
    sd_hw_pokey_write((addr >> 10) & 1, (uint8_t)(addr & 0x0F), v);
}

/* the previous-channel/offset/frequency views of the $83B8 table */
#define SNDSEL_PREV(x)  (selftest_sndsel[(x)])            /* $83B8,X            */
#define SNDSEL_OFF(x)   (selftest_sndsel[1 + (x)])        /* SoundTableLo,X     */
#define SNDSEL_FREQ(x)  (selftest_sndsel[10 + (x)])       /* Sndfrq,X           */

/* ------------------------------------------------------------------ */
/* the power-on path: BeginningPattern $8110 .. Ok2 $82B8               */
/* ------------------------------------------------------------------ */

static void stop0(void);
static void eor_cksum_roms(void);
static void stest4(void);

/* BeginningPattern ($8110): the zero-page march. S holds the pattern, Y the
 * cell under test; for each pattern $11, $22, $44, $88 (ASL until the carry
 * falls out) and each of the 256 cells: write the pattern, scan the other
 * 255 cells for zero, verify the cell, clear it. Falls into Stop0. */
void beginning_pattern(void)
{
    unsigned p, y;

    for (p = 0x11; p < 0x100; p <<= 1) {        /* L8136 ASL / BCS Stop0 */
        for (y = 0; y < 0x100; y++) {
            g.ram[y] = (uint8_t)p;              /* L8114 STX BLACK / L813D STX BLACK,Y */
            /* L811A-L8121: scan forward, reads only (cannot fail here)  */
            /* L8129 EOR BLACK,Y: verify (cannot fail here)              */
            /* L8125 STA WTCHDG: watchdog kick dropped                    */
            g.ram[y] = 0x00;                    /* L8131 STX BLACK,Y: clear */
        }
    }
    stop0();
}

/* Stop0 ($8186) / L04 ($8191): zero the zero page, then the full march over
 * pages $01-$03 and $20-$27 through the (BLACK),Y pointer (BLUE = page):
 * every cell must read 0, then takes $11, $22, $44, $88 in turn and is LEFT
 * at $88 - so vector RAM comes out of the march all $88. Pages 1-3 are
 * cleared again by EorCksumRoms; vector RAM is not. */
static void stop0(void)
{
    unsigned x, y, p, page;

    /* L8186 LDX #$FF / TXS: the stack is reset - CPU artifact             */
    for (x = 0; x < 0x100; x++) g.ram[x] = 0x00;    /* Stop0_10 STA BLACK,X  */
    /* L04: TAY (Y = 0), LDA #$01, STA BLUE: start at page 1 (BLACK = 0)   */
    for (page = 0x01; page < 0x28; page++) {
        if (page == 0x04) page = 0x20;          /* L81B6: next @ $2000        */
        BLUE = (uint8_t)page;                   /* L8194 STA BLUE / L81AE INC */
        for (y = 0; y < 0x100; y++) {
            uint8_t* cell = (page < 0x04)
                ? &g.ram[(page << 8) | y]
                : &g.vram[((page - 0x20) << 8) | y];
            /* L8198 LDA (BLACK),Y / BNE L04_20: a non-zero cell is an
             * error - unreachable here, the reset loop cleared it       */
            for (p = 0x11; p < 0x100; p <<= 1)  /* L819D .. L81A6 BCC L04_16 */
                *cell = (uint8_t)p;             /* STA / EOR (BLACK),Y verify */
        }
        /* L81AB STA WTCHDG: watchdog kick dropped                         */
    }
    BLUE = 0x28;                                /* the INC BLUE that fails
                                                 * CPX #$28 leaves $28      */
    eor_cksum_roms();                           /* L81C0 JMP: RAM is good   */
}

/* EorCksumRoms ($8244): clear pages 1-3, then EOR-checksum every ROM: 16
 * pages each from $3000, $4000 .. $8000 seeded with the ROM index X (0..5),
 * results in $F1-$F6; then, as the special case, the 8 pages at $2800
 * seeded with X = $FF, stored through the zero-page wrap of STA $F1,X into
 * $F0 (BGSHEN, AS2TST's PNTTBL). Atari built each ROM so the seeded EOR is
 * 0. The pointer is WHITE/EACE ($07/$08). */
static void eor_cksum_roms(void)
{
    unsigned x, y, npages;
    uint8_t a;

    for (x = 0; x < 0x100; x++) {               /* L8247: X = 0, $FF .. $01 */
        g.ram[0x100 + x] = 0x00;
        g.ram[0x200 + x] = 0x00;                /* STA XINC,X               */
        g.ram[0x300 + x] = 0x00;
    }
    /* L8253 TAY: Y = 0 */
    WHITE = 0x00;                               /* pointer lo               */
    EACE  = 0x30;                               /* pointer hi: $2800 is the
                                                 * special case, done last */
    x = 0;
    npages = 0x10;
    for (;;) {
        POKRAN = (uint8_t)npages;               /* EorCksumRoms_6: # pages  */
        a = (uint8_t)x;                         /* L825E TXA: the seed      */
        do {
            for (y = 0; y < 0x100; y++)         /* L825F EOR (WHITE),Y      */
                a ^= rom_byte((uint16_t)(((uint16_t)EACE << 8) | y));
            EACE++;                             /* L8264 INC EACE           */
            /* L8266 STA WTCHDG: watchdog kick dropped                     */
            POKRAN--;                           /* L8269 DEC POKRAN         */
        } while (POKRAN != 0);
        g.ram[(0xF1 + x) & 0xFF] = a;           /* L826D STA $F1,X (zp wrap)*/
        x = (x + 1) & 0xFF;                     /* INX                      */
        if (x == 0) break;                      /* BEQ JustLabel: was $2800 */
        a = EACE;                               /* L8272                    */
        if (a == 0x40) EACE = 0x40;             /* L8274-8: no-op store     */
        if (a < 0x90) {                         /* L827C CMP #$90 / BCC     */
            EACE = a;                           /* L8258 STA EACE           */
            npages = 0x10;                      /* L825A LDA #$10           */
            continue;
        }
        x = 0xFF;                               /* L8280: checksum -> $F0   */
        EACE = 0x28;                            /* L8282-4: start @ $2800   */
        npages = 0x08;                          /* L8286: only 8 pages here */
    }
    /* JustLabel ($828A): any VGROM error sounds the alarm on POKEY1 ch 3  */
    if ((BGSHEN | g.ram[0xF1]) != 0) {
        sd_hw_pokey_write(0, 0x04, 0xF0);       /* L8294 STA $1004 (AUDF3)  */
        sd_hw_pokey_write(0, 0x05, 0xA2);       /* L8297 STX $1005 (AUDC3)  */
    }
    stest4();
}

/* Stest4 ($829A): each POKEY's RANDOM must change - read it, then compare
 * up to six more reads against the first; six equal reads flag the chip in
 * ERPLC+1/+2 ($81/$82). Then Ok2: interrupts on, read the EAROM, judge it
 * (ERPLC+3 = $83, bad batches zeroed), pick the first screen and park in
 * MainLineDiagLoop. The RANDOM read counts are oracle-visible (the LFSR is
 * the instruction-path checksum): 1 + k reads per POKEY, k = compares. */
static void stest4(void)
{
    uint8_t a, y;
    int x;

    a = sd_hw_pokey_random(0);                  /* L829C LDA $100A          */
    for (x = 5;; x--) {                         /* L829F CMP $100A / BNE    */
        if (sd_hw_pokey_random(0) != a) break;  /* yes - random #'s differ  */
        if (x == 0) { ZP_ERPLC1 = a; break; }   /* L82A7 STA $81: bad POKEY1*/
    }
    a = sd_hw_pokey_random(1);                  /* Ok1_82A9: LDA $140A      */
    for (x = 5;; x--) {
        if (sd_hw_pokey_random(1) != a) break;
        if (x == 0) { ZP_ERPLC2 = a; break; }   /* L82B6 STA $82: bad POKEY2*/
    }
    /* Ok2 ($82B8): CLI - interrupts live from here (serviced at the seam
     * waits; the marches above ran with them masked, as on the 6502)     */
    read_everything();                          /* L82B9                    */
    y = 0x02;                                   /* default good             */
    a = g.ram[0x187];                           /* EAROM bad-checksum flags */
    if (a != 0) {
        ZP_ERPLC3 = a;                          /* L82C3 STA $83: bad EAROM */
        eazero();                               /* clear it if bad          */
        y = 0x00;
        g.ram[0x187] = 0x00;                    /* L82CA STY $0187          */
    }
    OBJ = y;                                    /* which state first?       */
    cpu_loop = SD_LOOP_DIAG;                    /* L82CF JMP MainLineDiagLoop */
}

/* ------------------------------------------------------------------ */
/* the diagnostic screens                                              */
/* ------------------------------------------------------------------ */

static void optn2(uint8_t a_strobe);
static void swtst(void);

/* Stest5 ($82D2), OBJ = 0 (the EAROM-was-bad state): once the EAROM driver
 * is idle, read it again, report the result in ERPLC+3 and go straight to
 * the report screen. */
static void stest5(void)
{
    if ((g.ram[0x188] | g.ram[0x185]) != 0)     /* L82D2-8: still operating */
        return;                                 /* BNE -> RTS at $82E6      */
    read_everything();                          /* try another read         */
    ZP_ERPLC3 = g.ram[0x187];                   /* still bad? (report)      */
    OBJ = 0x02;                                 /* go straight to report    */
}

/* Cocktail ($82E7), OBJ = 2: the status screen - option switches in big
 * digits (Optn2), the non-zero ROM checksums as "ROM# value" lines, the
 * R/P/P/E error letters for bad RAM / POKEY1 / POKEY2 / EAROM, and a beep
 * on any switch closure (Swtst). On a cocktail cabinet the flip is turned
 * off first. */
static void cocktail(void)
{
    uint8_t x, y, a, ypos;

    if (sd_hw_in1(7) & 0x80)                    /* BIT CABERE / BPL +5      */
        sd_hw_out1(0x00);                       /* cocktail: flip off       */
    set_vg_status(0xA7);                        /* L82F1-3                  */
    vg_add2(0x61, 0xAF);                        /* L82F6 (JSRL word $AF61)  */
    vg_vctr_dark(0xB0, 0xF0);                   /* L82FD                    */
    use_full_size(0x00);                        /* scale 0: big numbers     */
    optn2(BLUE);                                /* A = BLUE after AddY1ToVector */
    set_vg_scale(0x01, 0x01);                   /* L830C; Y = 1 from SaveCFlag */
    POTGO = 0x46;                               /* starting Y, checksum lines */
    for (x = 6;; x--) {                         /* L8315 LDX #$06           */
        a = g.ram[A_BGSHEN + x];                /* PNTTBL $F0,X             */
        if (a != 0) {                           /* BEQ +$2A: skip if clean  */
            POKRAN = x;                         /* save chksum #            */
            center_beam_in_middle();
            ypos = POTGO;                       /* L8320 LDX POTGO          */
            POTGO = (uint8_t)(ypos - 0x08);     /* SEC / SBC: 32 below      */
            vg_vctr_dark(0xF6, ypos);           /* position beam (X = old)  */
            (void)display_digit(POKRAN);        /* ROM #                    */
            vg_vctr_dark(0x06, 0x00);           /* L8332-6                  */
            /* LDA POKRAN / CLC / ADC #$F0 / LDY #$01: the checksum's own
             * zero-page address, one byte, C = 0 (no carry out of $F0+X) */
            save_input_parameters((uint8_t)(POKRAN + 0xF0), 0x01, 0);
            x = POKRAN;                         /* L8343 LDX POKRAN         */
        }
        if (x == 0) break;                      /* DEX / BPL                */
    }
    center_beam_in_middle();                    /* L8348                    */
    vg_vctr_dark(0xF6, 0x50);                   /* position for error list  */
    POKRAN = 0x03;
    for (;;) {                                  /* L8356                    */
        x = POKRAN;
        y = 0x00;
        if (g.ram[A_COCKBI + x] != 0)           /* ERPLC,X: any bad news?   */
            y = selftest_badnws[x];
        vg_add2(sd_vecrom[0x324A + y - 0x2800], /* the letter's JSRL word   */
                sd_vecrom[0x324B + y - 0x2800]);/* (Y = 0: the blank glyph) */
        POKRAN--;
        if (POKRAN & 0x80) break;               /* DEC / BPL                */
    }
    swtst();                                    /* beep on switch closure   */
}

/* Stest7 ($8372), OBJ = 4: one JSRL - the canned test picture at $AA76. */
static void stest7(void)
{
    vg_add2(0x76, 0xAA);
}

/* Stest8 ($8379), OBJ = 6: the sound and scale test. Every 64 frames the
 * channel index XCOMP steps: the previous channel's AUDC is silenced and
 * the new one gets its Sndfrq tone at $A8, through the "fake" POKEY
 * addresses $13F0,Y (POKEY1 mirror) / $1400,Y (POKEY2). The scale word
 * uses the same index (never 0). */
static void stest8(void)
{
    uint8_t x, y, a;

    if ((ZP_FRAME & 0x3F) == 0)                 /* L8379-D                  */
        XCOMP++;                                /* next channel             */
    x = (uint8_t)(XCOMP & 0x07);
    y = SNDSEL_PREV(x);                         /* L8386 LDY $83B8,X        */
    pokey_write_addr((uint16_t)(0x13F1 + y), 0x00); /* previous AUDC off    */
    y = SNDSEL_OFF(x);                          /* L838E LDY SoundTableLo,X */
    pokey_write_addr((uint16_t)(0x13F0 + y), SNDSEL_FREQ(x)); /* AUDF       */
    pokey_write_addr((uint16_t)(0x13F1 + y), 0xA8);           /* AUDC       */
    vg_add2(0x79, 0xAA);                        /* L839C                    */
    center_beam_in_middle();
    a = (uint8_t)(XCOMP & 0x07);
    if (a == 0) a = 0x01;                       /* don't allow 0            */
    use_full_size(a);                           /* test scale               */
    vg_add2(0x63, 0xA8);                        /* L83B1                    */
}

/* SetScale1 ($83CA), OBJ = 8: the seven color bars, XCOMP = 6..0, color =
 * ~XCOMP & 7 (so group 0 is white and gets its own picture $AA57). */
static void set_scale1(void)
{
    uint8_t y;

    use_full_size(0x01);                        /* set scale 1              */
    XCOMP = 0x06;
    for (;;) {                                  /* L83D3                    */
        center_beam_in_middle();
        y = XCOMP;
        vg_vctr_dark(selftest_posbars[y], selftest_position[y]);
        set_vg_status((uint8_t)(~XCOMP & 0x07)); /* EOR #$FF / AND #$07     */
        if (XCOMP == 0) vg_add2(0x57, 0xAA);    /* white group              */
        else            vg_add2(0x54, 0xAA);
        XCOMP--;
        if (XCOMP & 0x80) break;                /* DEC XCOMP / BPL          */
    }
    vg_add2(0x66, 0xAA);                        /* LastWhite                */
}

/* Stst10 ($841F), OBJ = $A: the crosshatch - 8 horizontal and 12 vertical
 * bars - and the color switch: SELECT held three frames bumps $17, which
 * MainLineDiagLoop turns into the box color on this screen. */
static void stst10(void)
{
    uint8_t y;
    int c;

    center_beam_in_middle();
    use_full_size(0x01);
    POKRAN = 0x07;                              /* "nine bars horiz"        */
    center_beam_in_middle();                    /* L842B: once, not per bar */
    for (;;) {                                  /* L842E                    */
        y = POKRAN;
        vg_vctr_dark(0x80, selftest_hlpos[y]);  /* position for this line   */
        vg_add2(0x72, 0xAA);
        POKRAN--;
        if (POKRAN & 0x80) break;
    }
    POKRAN = 0x0B;                              /* "thirteen bars vert"     */
    for (;;) {                                  /* L8447                    */
        y = POKRAN;
        vg_vctr_dark(selftest_vlpos[y], 0x60);
        vg_add2(0x6E, 0xAA);
        POKRAN--;
        if (POKRAN & 0x80) break;
    }
    if (sd_hw_in1(6) & 0x80) {                  /* L845C LDA GAMSEL / BPL   */
        c = (TEMP5 & 0x80) != 0;                /* ASL TEMP5: debounce      */
        TEMP5 = (uint8_t)(TEMP5 << 1);
        if (c) ZP_17++;                         /* next color               */
        return;                                 /* JMP $846E                */
    }
    TEMP5 = 0x20;                               /* reset: not pushed        */
}

/* CenterBeam ($8483): the coin-mech line - '1' for the left mech, the
 * centre mech's multiplier (ZMINE d4 + 1) and the dollar mech's (ZMINE
 * d3-d2 through DollarMechMultipliers), then falls into Optn2 with
 * XCOMP = $FF. Each $140B strobe is the STA of whatever A held - the list
 * pointer's low byte, which AddY1ToVector leaves in A. */
static void center_beam(void)
{
    uint8_t a, x;

    center_beam_in_middle();
    vg_vctr_dark(0xFB, 0x4D);                   /* position beam            */
    (void)display_digit(0x01);                  /* 1 for left coin mech     */
    sd_hw_pokey_write(1, 0x0B, BLUE);           /* L8492 STA $140B (POTGO)  */
    a = sd_hw_pokey2_optionsw();                /* L8495 LDA $1408 'OPTN3'  */
    ZMINE = a;
    a = (uint8_t)(((a & 0x10) >> 4) + 1);       /* AND #$10, LSR x4, ADC #1 */
    (void)display_digit(a);                     /* centre mech value        */
    sd_hw_pokey_write(1, 0x0B, BLUE);           /* L84A5 STA $140B          */
    a = sd_hw_pokey2_optionsw();                /* L84A8 LDA $1408          */
    x = (uint8_t)((a & 0x0C) >> 2);
    (void)display_digit(selftest_dollar[x]);    /* dollar mech value        */
    vg_vctr_dark(0xC6, 0xEE);                   /* position for next line   */
    XCOMP = 0xFF;                               /* flag for position        */
    optn2(BLUE);                                /* falls through            */
}

/* Optn2 ($84C1): 16 option-switch digits (POKEY2 $1408 d0..d7, then POKEY1
 * $1008 d0..d7, as the PLA/ROR chain pairs them), then d7/d6 of each IN1
 * line $0907 down to $0900, then IN0 d0..d5, then ten 'X's. XCOMP bit 7
 * selects the line spacing (set when entered from CenterBeam). a_strobe is
 * the A the caller arrived with - it is STA'd to the $100B POTGO strobe. */
static void optn2(uint8_t a_strobe)
{
    uint8_t p2, y, v;
    int c;

    POKRAN = 0x0F;
    sd_hw_pokey_write(0, 0x0B, a_strobe);       /* L84C5 STA $100B: strobe  */
    POTGO = sd_hw_pokey1_diffsw();              /* L84C8 LDA $1008 'OPTN1'  */
    sd_hw_pokey_write(1, 0x0B, POTGO);          /* L84CD STA $140B          */
    p2 = sd_hw_pokey2_optionsw();               /* L84D0 LDA $1408 'OPTN3'  */
    for (;;) {                                  /* L84D3 PHA                */
        (void)display_digit((uint8_t)(p2 & 0x01)); /* display 0 or 1        */
        c = POTGO & 0x01;                       /* L84D9 LSR POTGO          */
        POTGO >>= 1;
        p2 = (uint8_t)((p2 >> 1) | (c << 7));   /* PLA / ROR                */
        POKRAN--;
        if (POKRAN & 0x80) break;               /* DEC POKRAN / BPL         */
    }
    y = (XCOMP & 0x80) ? 0x9E : 0x9F;           /* L84E1-7                  */
    vg_vctr_dark(y, 0xF8);                      /* position for next line   */
    POKRAN = 0x07;                              /* do all other switches    */
    for (;;) {                                  /* L84F3                    */
        v = sd_hw_in1(POKRAN);                  /* LDA HYPSW,X              */
        (void)display_digit((uint8_t)(v >> 7));        /* ROL/ROL/AND #1: d7*/
        (void)display_digit((uint8_t)((v >> 6) & 1));  /* PLP/ROL/AND #1: d6*/
        POKRAN--;
        if (POKRAN & 0x80) break;
    }
    y = (XCOMP & 0x80) ? 0x9E : 0x9F;           /* L850B-11                 */
    vg_vctr_dark(y, 0xF8);                      /* position for next line   */
    POKRAN = 0x05;
    v = (uint8_t)(sd_hw_in0() & 0x3F);          /* remaining switches; d6,
                                                 * d7 don't care            */
    for (;;) {                                  /* L8522 AND #$01 ... ROR   */
        (void)display_digit((uint8_t)(v & 0x01));
        v >>= 1;
        POKRAN--;
        if (POKRAN & 0x80) break;
    }
    POKRAN = 0x09;                              /* fill rest with 'X'       */
    for (;;) {
        (void)vg_char(0x22, 0);                 /* L8534 JSR SaveCFlag      */
        POKRAN--;
        if (POKRAN & 0x80) break;
    }
}

/* Swtst ($853C): beep while any switch is closed. Group 1 (POKEY1 ch 1):
 * d7/d6 of $0903..$0900 gathered into TEMP5. Group 2 (ch 2): STRT1 d7/d6,
 * OPTNA1 d7, GAMSEL d7, and IN0 d0-d2 inverted (coin lines). The tone is
 * the gathered byte + $40 (the ADC's carry is the last ROL's carry-out,
 * which is always 0 - the byte never has its top bit set before that
 * shift). The two ASL abs on $0905/$0906 are read-modify-writes of input
 * addresses; the write-back reaches nothing and is dropped. */
static void swtst(void)
{
    uint8_t x, v, a, y;

    y = 0x00;
    TEMP5 = 0x00;
    for (x = 3;; x--) {                         /* L8542 LDA HYPSW,X        */
        v = sd_hw_in1(x);
        TEMP5 = (uint8_t)((TEMP5 << 1) | (v >> 7));         /* ASL / ROL   */
        TEMP5 = (uint8_t)((TEMP5 << 1) | ((v >> 6) & 1));   /* ASL / ROL   */
        if (x == 0) break;
    }
    a = TEMP5;
    if (a != 0) {                               /* L8550 BEQ                */
        a = (uint8_t)(a + 0x40);                /* ADC #$40, C = 0          */
        sd_hw_pokey_write(0, 0x00, a);          /* STA POKEY (AUDF1)        */
        y = 0xA4;
    }
    sd_hw_pokey_write(0, 0x01, y);              /* L8559 STY $1001 (AUDC1)  */
    y = 0x00;
    TEMP5 = 0x00;
    v = sd_hw_in1(4);                           /* STRT1: both bits here    */
    TEMP5 = (uint8_t)((TEMP5 << 1) | (v >> 7));
    TEMP5 = (uint8_t)((TEMP5 << 1) | ((v >> 6) & 1));
    v = sd_hw_in1(5);                           /* ASL OPTNA1: d7           */
    TEMP5 = (uint8_t)((TEMP5 << 1) | (v >> 7));
    v = sd_hw_in1(6);                           /* ASL GAMSEL: only bit 7   */
    TEMP5 = (uint8_t)((TEMP5 << 1) | (v >> 7));
    v = (uint8_t)~sd_hw_in0();                  /* L8573-6: backwards       */
    TEMP5 = (uint8_t)((TEMP5 << 1) | (v & 1)); v >>= 1;      /* LSR / ROL   */
    TEMP5 = (uint8_t)((TEMP5 << 1) | (v & 1)); v >>= 1;
    TEMP5 = (uint8_t)((TEMP5 << 1) | (v & 1));
    a = TEMP5;
    if (a != 0) {                               /* L8583 BEQ                */
        a = (uint8_t)(a + 0x40);                /* ADC #$40, C = 0          */
        sd_hw_pokey_write(0, 0x02, a);          /* STA $1002 (AUDF2)        */
        y = 0xA4;
    }
    sd_hw_pokey_write(0, 0x03, y);              /* L858C STY $1003 (AUDC2)  */
}

/* Sftjse ($8626): dispatch the screen for OBJ through the RTS jump table
 * Sftjsr (target = table word + 1). OBJ only ever steps by 2 from 0 or 2, so
 * an odd value (which would read a straddling pair) never happens; $0C and
 * above restart at 2. */
static void sftjse(void)
{
    uint8_t x = OBJ;
    uint16_t target;

    if (x >= 0x0C) {                            /* non valid state?         */
        x = 0x02;
        OBJ = 0x02;                             /* start over               */
    }
    target = (uint16_t)((selftest_sftjsr[x] |
                        ((uint16_t)selftest_sftjsr[x + 1] << 8)) + 1);
    switch (target) {
    case 0x82D2: stest5();     break;
    case 0x82E7: cocktail();   break;
    case 0x8372: stest7();     break;
    case 0x8379: stest8();     break;
    case 0x83CA: set_scale1(); break;
    case 0x841F: stst10();     break;
    default:                   break;           /* odd OBJ: unreachable     */
    }
}

/* ------------------------------------------------------------------ */
/* signature analysis ($8D33)                                          */
/* ------------------------------------------------------------------ */

/* The bench mode: interrupts off, and a canned AVG list selected by the
 * three option jumpers (CABERE, GAMSEL, OPTNA1 d6) is re-triggered every
 * time the AVG halts, so a signature analyser can be clocked on the vector
 * hardware. Pattern 0 fills vector RAM with a 5-step ramp and draws
 * nothing. Entered from MainLineDiagLoop (DIAG STEP held with SELECT) and
 * never returns.
 *
 * The SEI means no timed IRQs run in this mode on the hardware; the port's
 * seam waits do service them (only the bookkeeping cells they touch could
 * differ, and nothing is compared in this mode). */
static void sig_anal_pass(int first)
{
    uint8_t a, x, y;

    if (!first) {
        /* L8D3B: a pattern loaded and the AVG halted -> run it again      */
        if (BLACK != 0 && (sd_hw_in0() & 0x40)) {
            sd_hw_vgreset();                    /* STA STOPAD               */
            sd_hw_vggo();                       /* STA GOADD                */
        } else {
            sd_hw_idle();                       /* the 6502 just spins here */
        }
    }
    /* L8D4C STA WTCHDG: watchdog kick dropped                             */
    a = (uint8_t)(sd_hw_in0() & 0x10);
    if (a != 0) {
        /* L8D56 BRK. AS2TST/XYSIG.MAC meant "if the self-test switch is
         * turned off, exit" - but this board's BRK vector is the IRQ
         * handler ($FFFE = $8639), which has no B-flag check: it runs, and
         * RTIs to $8D58, the $00 operand of the LDA #$00 at $8D57 - a
         * SECOND BRK - whose RTI lands on $8D5A, the STA BLACK, with A
         * still $10. So the switch-off path is two IRQ services and BLACK
         * = $10 instead of 0, and the mode never exits. The hardware's
         * behaviour is what is reproduced. */
        sd_irq();
        sd_irq();
    } else {
        a = 0x00;                               /* L8D57 LDA #$00           */
    }
    BLACK = a;                                  /* L8D59 STA BLACK          */
    /* LDA CABERE / ROL / ROL / ROL BLACK, then GAMSEL, then OPTNA1: two
     * ROLs of A leave d6 in the carry, so BLACK gathers the d6 jumpers    */
    BLACK = (uint8_t)((BLACK << 1) | ((sd_hw_in1(7) >> 6) & 1));
    BLACK = (uint8_t)((BLACK << 1) | ((sd_hw_in1(6) >> 6) & 1));
    BLACK = (uint8_t)((BLACK << 1) | ((sd_hw_in1(5) >> 6) & 1));
    a = BLACK;
    if (a == EAC2) return;                      /* L8D72 CMP / BEQ: same    */
    EAC2 = a;
    if (a == 0) {
        /* L8D9C: pattern 0 - fill $2000-$27FF with a ramp through the
         * CHAN2V/RED pointer, BLUE the running value, BLACK the page count */
        RED    = 0x20;
        CHAN2V = 0x00;
        BLUE   = 0x00;
        BLACK  = 0x08;
        do {
            y = 0;
            do {                                /* L8DAB                    */
                g.vram[(((unsigned)RED - 0x20u) << 8) | y] = BLUE;
                BLUE = (uint8_t)(BLUE + 0x05);  /* CLC / ADC #$05           */
                y++;
            } while (y != 0);                   /* INY / BNE                */
            RED++;
            BLACK--;
        } while (BLACK != 0);
        sd_hw_vgreset();                        /* L8DBD JMP L8D96          */
        return;
    }
    /* L8D7B: copy the pattern's word stream into $2002.. - indexed from the
     * ROM with X = the jumper byte (or $80|jumpers after the BRK path, which
     * runs past the tables into whatever follows; read as the ROM has it) */
    g.vram[0x000] = 0xC7;                       /* L8D7B-D STA VECMEM       */
    g.vram[0x001] = 0x60;                       /* STAT word $60C7 at $2000 */
    y = rom_byte((uint16_t)(0x8DC0 + a));       /* L8D85 LDY $8DC0,X        */
    x = rom_byte((uint16_t)(0x8DC8 + a));       /* L8D88 LDA $8DC8,X / TAX  */
    for (;;) {                                  /* L8D8C                    */
        g.vram[0x002 + x] = rom_byte((uint16_t)(0x8DD0 + y));
        y--;                                    /* DEY (wraps)              */
        if (x-- == 0) break;                    /* DEX / BPL                */
    }
    sd_hw_vgreset();                            /* L8D96 STA STOPAD         */
}

/* ------------------------------------------------------------------ */
/* MainLineDiagLoop ($8590): one pass                                  */
/* ------------------------------------------------------------------ */

/* Frame timer (25 periods of the 3 kHz clock, ~8.3 ms), frame count, wait
 * for the AVG, then: DIAG STEP or slam (IN0 d5/d3 low) held three frames
 * steps OBJ to the next screen (SELECT as well -> signature analysis);
 * the box, the screen, HALT, VGGO. Switch off -> WatchDogResetExit. */
static void main_line_diag_frame(void)
{
    uint8_t a, y;
    int x, c;

    sd_wait_3khz(0x19);                         /* L8590 LDX #$18: 25 x     */
    ZP_FRAME++;                                 /* L859F INC $A1            */
    sd_wait_vghalt();                           /* L85A1 BIT HALT / BVC     */
    /* ReloadVector: list pointer = $2000 */
    BLUE = 0x00;
    EAC2 = 0x20;
    a = (uint8_t)(~sd_hw_in0() & 0x28);         /* switch pushed?           */
    if (a != 0) {
        c = (YTOP & 0x80) != 0;                 /* L85B7 ASL YTOP           */
        YTOP = (uint8_t)(YTOP << 1);
        if (c) {                                /* pressed long enough      */
            if (sd_hw_in1(6) & 0x80) {          /* L85BB LDA GAMSEL / BPL   */
                inisou();                       /* sound off                */
                /* L85C3 JMP L8D33: gone to sig anal, not to return.
                 * L8D33 SEI / CLD, LDA #$FF / STA EAC2, BNE L8D4C         */
                EAC2 = 0xFF;
                cpu_loop = SD_LOOP_SIGANAL;
                sig_anal_pass(1);
                return;
            }
            OBJ = (uint8_t)(OBJ + 2);           /* L85C6-8: next test       */
            for (x = 6;; x -= 2) {              /* L85CA-D6: AUDC1-4 off    */
                sd_hw_pokey_write(0, (uint8_t)(1 + x), 0x00);
                sd_hw_pokey_write(1, (uint8_t)(1 + x), 0x00);
                if (x == 0) break;
            }
        }
    } else {
        YTOP = 0x20;                            /* not pressed: restart timer */
    }
    /* L85DF: the box color - the color switch's on the crosshatch screen  */
    if (OBJ == 0x0A) {
        a = (uint8_t)(ZP_17 & 0x07);
        if (a == 0) a = 0x01;
        y = (uint8_t)(a | 0xC0);                /* intensity                */
    } else {
        y = 0xA7;                               /* white box                */
    }
    set_vg_status(y);                           /* L85F5                    */
    vg_add2(0x62, 0xA8);                        /* do box                   */
    sftjse();                                   /* do this routine          */
    center_beam_in_middle();
    vg_add_halt();                              /* center and halt          */
    sd_hw_vggo();                               /* L8608 STA GOADD          */
    /* L860B STA WTCHDG: watchdog kick dropped                             */
    if (sd_hw_in0() & 0x10) {                   /* L860E: still self test?  */
        /* WatchDogResetExit ($8618): BNE to itself until the watchdog
         * resets the CPU - the way out of the diagnostics                 */
        sd_hw_reset();
        return;
    }
    /* L8615 JMP MainLineDiagLoop: next pass                               */
}

/* ------------------------------------------------------------------ */
/* the bookkeeping screen: Averag, AllStopPlease, St2                  */
/* ------------------------------------------------------------------ */

/* Set0Balnking ($8C80) / PointerData ($8C81): SEC, A = $15 (NOBJ), then
 * SaveInpuParameers - draw y BCD bytes from NOBJ up, zero-suppressed. */
static void set0_balnking(uint8_t y)
{
    save_input_parameters(0x15, y, 1);
}

/* MultiplyBy2Decimal ($8C86): the 3-byte BCD number at NOBJ ($15-$17)
 * doubled, carry rippling. Times4Decimal ($8C98): twice. */
static void multiply_by2_decimal(void)
{
    int c = 0;                                  /* L8C86 CLC / SED          */
    uint8_t x;
    for (x = 0; x < 3; x++) {                   /* LDY #$02 .. DEY / BPL    */
        bcd_res r = bcd_adc(g.ram[A_NOBJ + x], g.ram[A_NOBJ + x], c);
        g.ram[A_NOBJ + x] = r.r;
        c = r.c;
    }                                           /* CLD                      */
}

static void times4_decimal(void)
{
    multiply_by2_decimal();
    multiply_by2_decimal();
}

/* CorrectMessageAndColor ($8CD4): position and draw bookkeeping message y
 * (index into the four $8CEF tables) in its color. */
static void correct_message_and_color(uint8_t y)
{
    uint8_t x;

    TEMP2 = y;                                  /* save Y                   */
    center_beam_in_middle();
    y = TEMP2;
    vg_vctr_dark(selftest_msg_x[y], selftest_msg_y[y]); /* position        */
    x = TEMP2;
    pass_color(selftest_msg_color[x], selftest_msg_num[x]); /* (exit)      */
}

/* Averag ($89B9): for each of the 4 game types, average seconds per game
 * by repeated BCD subtraction: TEMP1-$12 = games played (3 bytes from
 * $01A6), WHITE-POKRAN = play time (4 bytes from EACS); the quotient - 1
 * (or 0 for no games, $FF past 255) lands in $97+type. */
static void averag(void)
{
    uint8_t x, y, v;

    TEMP7 = 0x03;
    for (;;) {                                  /* L89BD SED                */
        y = TEMP7;
        x = selftest_avgidx[y];                 /* index for # of games     */
        for (y = 0; y < 3; y++)                 /* Averag_10: 3 bytes       */
            g.ram[A_TEMP1 + y] = g.ram[0x1A6 + x + y];
        y = TEMP7;
        x = selftest_timix[y];                  /* index for seconds        */
        TEMP5 = 0x00;                           /* 0 games?                 */
        for (y = 0; y < 4; y++) {               /* Averag_20: 4 bytes       */
            v = g.ram[A_EACS + x + y];
            g.ram[A_WHITE + y] = v;
            TEMP5 |= v;                         /* to check for 0 games     */
        }
        y = 0x01;                               /* 1 will go to 0 (below)   */
        if (TEMP5 != 0) {
            y = 0x00;
            for (;;) {                          /* Averag_30                */
                bcd_res r;
                int c;
                y++;
                if (y == 0) break;              /* INY / BEQ _40            */
                r = bcd_sbc(WHITE, TEMP1, 1);   /* SEC / SBC TEMP1          */
                WHITE = r.r; c = r.c;
                r = bcd_sbc(EACE, NMROCK, c);
                EACE = r.r; c = r.c;
                r = bcd_sbc(VGBRIT, ZP_12, c);
                VGBRIT = r.r; c = r.c;
                r = bcd_sbc(POKRAN, 0x00, c);   /* come along carry         */
                POKRAN = r.r;
                if (r.n) break;                 /* BPL _30: not done yet    */
            }
        }
        /* Averag_40: CLD */
        y--;                                    /* DEY / TYA                */
        g.ram[0x97 + TEMP7] = y;                /* a good place to put it   */
        if (TEMP7 == 0) { TEMP7 = 0xFF; break; }/* DEY / STY TEMP7 / BPL    */
        TEMP7--;
    }
}

/* Clrbuf ($8CB8): the bookkeeping cells EAREQU+$00..$29 and their $97..
 * display copies to zero. ClearTimes ($8CB5) requests the EAROM
 * bookkeeping batch zeroed first; ClearBoth ($8CC5) zeroes both batches
 * and recopies the default initials; ClearScores ($8CCE) just the scores. */
static void clrbuf(void)
{
    uint8_t x;
    for (x = 0x29;; x--) {                      /* Clrbuf_10                */
        g.ram[A_EAREQU + x] = 0x00;             /* clear RAM also           */
        g.ram[0x97 + x] = 0x00;                 /* clear temp buffer too    */
        if (x == 0) break;
    }
}

static void clear_times(void)  { zero_earom(); clrbuf(); }
static void clear_both(void)   { eazero(); clrbuf(); set_up_initials_high(); }
static void clear_scores(void) { eazhis(); set_up_initials_high(); }

/* OptionSelected ($8CA6): RTS-dispatch the selected option ($1A & 3)
 * through DoSelfTest: 0 = the RESET vector, 1 clear scores, 2 clear times,
 * 3 clear both. Returns 1 when the CPU was restarted. */
static int option_selected(void)
{
    uint8_t x = (uint8_t)((ZP_1A & 0x03) << 1); /* words (x2)               */
    uint16_t target = (uint16_t)((selftest_dosel[x] |
                                 ((uint16_t)selftest_dosel[x + 1] << 8)) + 1);
    switch (target) {
    case 0x803F: sd_hw_reset(); return 1;       /* Poweron                  */
    case 0x8CCE: clear_scores(); break;
    case 0x8CB5: clear_times();  break;
    case 0x8CC5: clear_both();   break;
    default:                     break;
    }
    return 0;
}

/* L8F43: the difficulty-switch reading - $1008 behind the $100B strobe
 * (A = the caller's $A8), corrected for all-off, d3-d2 -> 0..3. C = 0. */
static uint8_t sub_8f43(void)
{
    sd_hw_pokey_write(0, 0x0B, 0xA8);           /* L8F44 STA $100B          */
    return (uint8_t)(((sd_hw_pokey1_diffsw() ^ 0x85) >> 2) & 0x03);
}

static void st2_frame(void);

/* AllStopPlease ($8A1D): the bookkeeping screen's prologue - stop the AVG,
 * silence, compute the averages, end any game, allow coins - and its static
 * display list at $2000: the box JSRL, the five row headings, the F/S
 * (fighters / space station) column letters, a JMPL to $24A8 and a HALT.
 * The JMPL's high byte at $20A7 is what St2 toggles to swap between the
 * $20A8 and $24A8 dynamic halves. Falls into St2. */
void all_stop_please(void)
{
    uint8_t y;

    sd_hw_vgreset();                            /* L8A1D STA STOPAD         */
    inisou();                                   /* turn off sounds          */
    averag();                                   /* calculate averages       */
    ZP_35 = 0x00;                               /* end any game here        */
    g.ram[0xD1] = 0x00;                         /* always English           */
    LANGBT = 0x00;                              /* allow coins again        */
    BLUE = 0x00;                                /* L8A2E-34: list at $2000  */
    EAC2 = 0x20;
    vg_add2(0x94, 0xAA);                        /* L8A36                    */
    for (y = 0x08; y <= 0x0C; y++)              /* '1 PLAYER' .. 'AVG GAME TIME' */
        correct_message_and_color(y);
    NOBJ = 0x02;                                /* space station / fighters */
    for (;;) {                                  /* AllStopPlease_10         */
        center_beam_in_middle();
        y = NOBJ;
        vg_vctr_dark(0x98, selftest_fs_ypos[y]);        /* Y pos            */
        (void)vg_char(0x10, 0);                         /* 'F'              */
        center_beam_in_middle();
        y = NOBJ;
        vg_vctr_dark(0x98, selftest_fs_ypos[3 + y]);    /* Y2pos            */
        (void)vg_char(0x1D, 0);                         /* 'S'              */
        NOBJ--;
        if (NOBJ & 0x80) break;                 /* DEC NOBJ / BPL           */
    }
    vg_add2(0x54, 0xE2);                        /* so next swap goes to the
                                                 * first buffer            */
    vg_add_halt();                              /* so it will halt          */
    cpu_loop = SD_LOOP_ST2;
    st2_frame();                                /* St2: the first pass      */
}

/* St2 ($8A8C): one pass of the bookkeeping loop. Wait for the AVG, swap the
 * dynamic half ($20A7 EOR #$02), VGGO, then build the next half at $x0A8:
 * the difficulty message, cocktail 'C' and flip, the lives as ship
 * pictures, the language letter, '2' for two-coin minimum, TOTAL ON TIME
 * and the four per-game rows (seconds x4, games, average), the option
 * prompt and the selected option, the SELECT step, ERASING while the EAROM
 * works, BONUS ADDER, and the coin/option digits (CenterBeam -> Optn2).
 * Switch off -> Pwron. */
static void st2_frame(void)
{
    uint8_t a, x, y;

    sd_wait_vghalt();                           /* St2: BIT HALT / BVC      */
    a = (uint8_t)(g.vram[0x0A7] ^ 0x02);        /* L8A91: swap buffers      */
    g.vram[0x0A7] = a;
    /* L8A99 STA WTCHDG: watchdog kick dropped                             */
    x = (a & 0x02) ? 0x20 : 0x24;               /* L8A9C-A2                 */
    BLUE = 0xA8;                                /* St2_12                   */
    EAC2 = x;
    sd_hw_vggo();                               /* L8AAA STA GOADD          */
    a = (uint8_t)(sub_8f43() + 0x0D);           /* diff reading + message #
                                                 * offset (C = 0)           */
    correct_message_and_color(a);
    if (sd_hw_in1(7) & 0x80) {                  /* BIT CABERE / BPL         */
        center_beam_in_middle();                /* need C for cocktail      */
        vg_vctr_dark(0x98, 0x00);
        (void)vg_char(0x0D, 0);                 /* output a 'C'             */
        a = 0x00;                               /* guess normal             */
        if (sd_hw_in1(4) & 0x40) a = 0xC0;      /* BIT STRT1 / BVC          */
        sd_hw_out1(a);
    }
    center_beam_in_middle();                    /* display lives            */
    vg_vctr_dark(0x96, 0x0E);
    set_vg_scale(0x02, 0x03);                   /* L8AE0; Y = 3 from
                                                 * AddVectorToVector        */
    gtoptn();
    a = g.ram[0xD1];                            /* PHA: save language       */
    g.ram[0xD1] = 0x00;                         /* always English           */
    WHITE = g.ram[0x47];                        /* lives                    */
    do {                                        /* L8AF3: a ship per life   */
        vg_add2(sd_vecrom[0x30AC - 0x2800], sd_vecrom[0x30AF - 0x2800]);
        WHITE--;
    } while (WHITE != 0);                       /* DEC WHITE / BNE          */
    set_vg_scale(0x01, 0x01);                   /* return to normal; Y = 1  */
    center_beam_in_middle();                    /* center                   */
    vg_vctr_dark(0xA0, 0x00);                   /* position for lang letter */
    x = a;                                      /* PLA / TAX: letter index  */
    (void)vg_char(selftest_langlt[x], 0);       /* output letter            */
    if (sd_hw_in1(6) & 0x40) {                  /* BIT GAMSEL / BVC: 2 coin min */
        center_beam_in_middle();                /* position for 2           */
        vg_vctr_dark(0x0D, 0x4D);
        (void)vg_char(0x03, 0);                 /* display a '2'            */
    }
    correct_message_and_color(0x07);            /* 'TOTAL ON TIME'          */
    for (x = 3;; x--) {                         /* St2_50: to page 0        */
        g.ram[A_NOBJ + x] = g.ram[A_EAREQU + x];
        if (x == 0) break;
    }
    times4_decimal();                           /* seconds times 4          */
    set0_balnking(0x04);
    /* TimeDisplayCalulationsHere */
    TEMP7 = 0x03;                               /* game number              */
    for (;;) {                                  /* _20                      */
        x = TEMP7;
        y = selftest_timix[x];                  /* offset into RAM          */
        for (x = 0; x < 4; x++)                 /* _21: 4 bytes             */
            g.ram[A_NOBJ + x] = g.ram[A_EACS + y + x];
        center_beam_in_middle();
        y = TEMP7;
        vg_vctr_dark(selftest_tipos[y], selftest_tipos[4 + y]);
        times4_decimal();                       /* actual second count      */
        set0_balnking(0x04);                    /* 8 digits                 */
        center_beam_in_middle();
        y = TEMP7;
        vg_vctr_dark(selftest_gmpos[y], selftest_gmpos[4 + y]);
        x = TEMP7;
        y = selftest_avgidx[x];                 /* offset for this number   */
        for (x = 0; x < 3; x++)                 /* _22: 3 bytes             */
            g.ram[A_NOBJ + x] = g.ram[0x1A6 + y + x];
        set0_balnking(0x03);                    /* 6 digits                 */
        center_beam_in_middle();
        y = TEMP7;
        vg_vctr_dark(selftest_avpos[y], selftest_avpos[4 + y]);
        y = TEMP7;                              /* max avg is 255 x 4 s     */
        hex_bcd_conversion_input(g.ram[0x97 + y]);
        times4_decimal();                       /* 4-count seconds          */
        set0_balnking(0x02);                    /* 4 digits                 */
        if (TEMP7 == 0) { TEMP7 = 0xFF; break; }/* DEC TEMP7 / BMI _30      */
        TEMP7--;
    }
    /* TimeDisplayCalulationsHere_30 */
    correct_message_and_color(0x00);            /* 'PUSH START & SELECT'    */
    y = (uint8_t)((ZP_1A & 0x03) + 1);          /* selected option 1 of 4   */
    correct_message_and_color(y);
    a = (uint8_t)(sd_hw_in1(4) << 1);           /* STRT1: START d6 -> d7    */
    a &= sd_hw_in1(6);                          /* AND GAMSEL: SELECT d7    */
    if (a & 0x80) {                             /* both pushed              */
        if (option_selected()) return;          /* option 0: the CPU reset  */
    }
    /* Nooptn: the option steps when SELECT is released */
    a = sd_hw_in1(6);
    if (a & 0x80) {
        ZP_1B = a;                              /* L8BD7: arm on release    */
    } else if ((a | ZP_1B) & 0x80) {            /* Nooptn_10: armed?        */
        ZP_1B = 0x00;                           /* clear flag               */
        ZP_1A++;                                /* bump option              */
    }
    /* Nooptn_20 */
    if (g.ram[0x188] != 0 && g.ram[0x184] != 0) /* EAROM operating, erasing */
        correct_message_and_color(0x05);        /* 'ERASING'                */
    correct_message_and_color(0x06);            /* 'BONUS ADDER'            */
    x = (uint8_t)((ZMINE >> 5) & 0x07);         /* ROL x4 / AND #$07: d7-d5 */
    NOBJ = selftest_bonus_disp[x];              /* display info             */
    /* L8C07 CLC: dead, Set0Balnking sets C                                */
    set0_balnking(0x01);
    center_beam_in_middle();                    /* center beam then...      */
    vg_vctr(0xD7, 0x38);                        /* L8C14 JSR Vgvtr1         */
    center_beam();                              /* ...output of options     */
    vg_add_halt();
    if (sd_hw_in0() & 0x10) {                   /* L8C1D: not test any more */
        sd_hw_irq_mark(SD_IRQ_MARK_TESTEXIT);   /* probe timing sync point  */
        ZP_44 = 0x00;                           /* start attract over       */
        ZP_45 = 0x00;
        NROCKS = 0x00;
        SAUMIN = 0x00;
        cpu_loop = SD_LOOP_START2;
        pwron();                                /* L8C2F JMP Pwron          */
        return;
    }
    swtst();                                    /* Nooptn_45: beep on switch */
    /* L8C35 JMP St2: next pass                                            */
}

/* ------------------------------------------------------------------ */
/* the frame driver's entry                                            */
/* ------------------------------------------------------------------ */

int selftest_frame(void)
{
    switch (cpu_loop) {
    case SD_LOOP_ST2:     st2_frame();            return 1;
    case SD_LOOP_DIAG:    main_line_diag_frame(); return 1;
    case SD_LOOP_SIGANAL: sig_anal_pass(0);       return 1;
    default:              return 0;
    }
}
