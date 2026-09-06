/* display.c - Space Duel C port: the display-builder module.
 *
 * One C function per named ROM routine (label + address on each), covering
 * the code that writes each frame's AVG display list: score headings and
 * score/lives areas ($4FF4/$5C24/$5CF2), the high-score table + initials
 * entry ($4DCD/$6004), every object picture ($5D6D Pictur and its children),
 * the ship pictures ($6259/$63FE - NOT AVG data, see NOTES_display.md), the
 * connecting rod ($62C6) and the fuse sparks ($638F).
 *
 * Everything goes through the real list pointer (zp $01/$02, VGLIST/EAC2) via
 * the vgutil layer, or straight into g.vram where the ROM wrote vector RAM
 * directly (score areas, rock slots, SH0XPCOORD piece coordinates).
 */
#include "sd_state.h"
#include "sd_hw.h"
#include "sd_bcd.h"
#include "vgutil.h"
#include "sd_vecrom.h"
#include "display_data.h"
#include "display.h"
#include "objects.h"   /* Inselo $50D5, Temp3WhichPlayer0 $5C24 live there */

/* ---- cross-module externs (translated elsewhere) ----------------------- */
/* message layer (AS2MSG) */
extern void mesgpos(uint8_t a, uint8_t x);       /* Mesgpos $7760: A=X pos, X=Y pos */
extern void vector_generator_message_processor(uint8_t y); /* $7770: Y=msg#, yellow */
extern void brightness(uint8_t x, uint8_t y);    /* Brightness $7772: X=color, Y=msg# */
extern void pass_color(uint8_t a, uint8_t y);    /* PassColor $7773: A=color, Y=msg# */
extern void vector_message5(uint8_t y);          /* VectorMessage5 $7779: Y=msg#, green */
extern void aux_routine_add_offset(uint8_t x);   /* AuxRoutineAddOffset $7730: X=offset idx */
/* trig / multiply (A2MATH) */
extern uint8_t pi_angle0(uint8_t a);             /* PiAngle0 $6834: A=angle -> A=sin */
extern uint8_t cos_sin_pi2(uint8_t a);           /* CosSinPi2 $6831: A=angle -> A=cos */
extern uint8_t output_temp2_temp21(uint8_t a);   /* OutputTemp2Temp21 $686D: A*TEMP1,
                                                  * returns POTGO (hi); also writes
                                                  * TEMP4/TEMP2/POTGO */
/* game/sound modules */
extern void always_remains_same_both(void);      /* AlwaysRemainsSameBoth $703C (X preserved) */
extern void random_fuzz(uint8_t x_in, uint8_t y_in); /* RandomFuzz $6B45
                                                  * (sound.c): caller's live
                                                  * X/Y reach TEMPA/TEMPB */
extern void stop_fuse_sound(void);               /* StopFuseSound $6B57 (sound.c) */
extern void explosion(uint8_t x_in, uint8_t y_in); /* Explosion $72E5 (sound.h:
                                                  * trigger stubs park the
                                                  * caller's live X/Y in
                                                  * TEMPA/TEMPB - oracle-
                                                  * visible, must be passed) */
extern void get_comet_to_go(void);               /* GetCometToGo $468C */
extern void bigbang(void);                       /* Bigbang $76CC */
extern void inisou(void);                        /* Inisou $73A8 */
extern void transfer_high_scores_buffer(void);   /* TransferHighScoresBuffer $886F (A2EARO) */
extern void write_high_scores_initials(void);    /* WriteHighScoresInitials $875D (A2EARO) */

/* ---- addressing helpers ------------------------------------------------ */

/* LDA/STA (zp),Y through a zero-page pointer pair, routed like the bus:
 * CPU RAM below $0400, vector RAM $2000-$27FF, vector ROM $2800-$3FFF. */
static uint8_t rd_pair(uint8_t zp, uint8_t y)
{
    uint16_t a = (uint16_t)((g.ram[zp] | ((uint16_t)g.ram[zp + 1] << 8)) + y);
    if (a < 0x400)                 return g.ram[a];
    if (a >= 0x2000 && a < 0x2800) return g.vram[a - 0x2000];
    if (a >= 0x2800 && a < 0x4000) return sd_vecrom[a - 0x2800];
    return 0;
}
static void wr_pair(uint8_t zp, uint8_t y, uint8_t v)
{
    uint16_t a = (uint16_t)((g.ram[zp] | ((uint16_t)g.ram[zp + 1] << 8)) + y);
    if (a < 0x400)                      g.ram[a] = v;
    else if (a >= 0x2000 && a < 0x2800) g.vram[a - 0x2000] = v;
}

/* LDA (VGLIST),Y - read back from the list under construction. */
static uint8_t list_peek(uint8_t y) { return rd_pair(0x01, y); }

/* LsbByte ($8EA7) entered with Y preset: word at (VGLIST)+y, advance y+2. */
static void lsb_byte(uint8_t y, uint8_t a, uint8_t x)
{
    vg_poke_list(y, a);
    vg_poke_list((uint8_t)(y + 1), x);
    vg_advance_list((uint8_t)(y + 1));
}
/* MsbByte ($8EAB) entered with Y preset: byte at (VGLIST)+y, advance y+1. */
static void msb_byte(uint8_t y, uint8_t a)
{
    vg_poke_list(y, a);
    vg_advance_list(y);
}

/* ====================================================================== */
/* initials entry (GET PLAYERS INITIALS screen)                            */
/* ====================================================================== */

/* Getin4 ($4D74): the four GET-INITIALS instruction messages + balance
 * positioning. Position/color protocols per the message layer externs. */
static void getin4(void)
{
    mesgpos(0xE0, 0x48);                    /* L4D74 */
    aux_routine_add_offset(1);
    vector_generator_message_processor(2);  /* instructions */
    mesgpos(0xB3, 0x38);
    aux_routine_add_offset(2);
    vector_generator_message_processor(3);
    mesgpos(0xAA, 0x2E);
    aux_routine_add_offset(3);
    vector_generator_message_processor(4);
    mesgpos(0x96, 0x24);
    aux_routine_add_offset(4);
    vector_generator_message_processor(5);  /* END message */
    vg_vctr_dark(0xC2, 0x80);               /* L4DB8: balance display */
    vg_vctr_dark(0x96, 0x00);
    vg_vctr_dark(0x6A, 0x00);               /* full balance */
}

/* EntryIndexCharacter0 ($5140): y = 2*character code; copy the glyph JSRL
 * word from $324A (or $3458 flipped) into the list. */
static void entry_index_character0(uint8_t y)
{
    uint16_t tbl = (UPDOWN & 0x80) ? 0x3458 : 0x324A;
    uint8_t x = sd_vecrom[tbl + 1u + y - 0x2800];   /* LDX $324B,Y */
    uint8_t a = sd_vecrom[tbl + y - 0x2800];        /* LDA $324A,Y */
    vg_add2(a, x);
}

/* DisplayAnInitial ($50FC): y = index into the initials tables ($0119 or,
 * for player 2 in the special two-column game, $0137). A blank draws an
 * underline cursor while entry is active. Inita3 ($50FA) is the entry that
 * takes the index from SKCTL ($0F). Both bump SKCTL. */
static void display_an_initial(uint8_t y)
{
    uint8_t a;
    SKCTL++;                                /* L50FC INC SKCTL */
    if (TEMP5 != 0 && !(SPFLG & 0x80))
        a = g.ram[0x137 + y];               /* special initials column */
    else
        a = g.ram[0x119 + y];               /* initials table */
    if (a >= 0x25 || a < 0x0B)              /* clamp outside blank..Z */
        a = 0x00;
    y = (uint8_t)(a << 1);
    if (y == 0 && !((g.ram[0x38] & g.ram[0x39]) & 0x80)) {
        /* blank while updating: underline cursor */
        a = (UPDOWN & 0x80) ? 0x1C : 0xA8;  /* VCTR 8,0,7 */
        vg_add2(a, 0x40);
        a = (UPDOWN & 0x80) ? 0x38 : 0x04;  /* VCTR 4,0,0 spacing */
        vg_add2(a, 0x40);
        return;
    }
    entry_index_character0(y);
}
static void inita3(void) { display_an_initial(SKCTL); }  /* Inita3 $50FA */

/* PreventTimeoutBothPlayers ($4E7E): returns C (1 = both done, mainline
 * restarts). The ROM's STA HALT ($0800) write is a bus no-op - dropped. */
static int prevent_timeout_both_players(void)
{
    ZP_45 = 0xF1;                           /* bring up high score table */
    if (!((g.ram[0x38] & g.ram[0x39]) & 0x80))
        return 0;                           /* L4E9C CLC RTS */
    SHHIGH = 0xF1;                          /* show score flag */
    /* L4E8B STA HALT: write to the IN0 address - hardware artifact */
    initialize_score_headings();
    transfer_high_scores_buffer();
    write_high_scores_initials();
    bigbang();
    return 1;                               /* L4E9A SEC */
}

/* Gotit ($4E9E): a letter was entered; C is clear on every exit. */
static int gotit(void)
{
    uint8_t x = POTGO;                      /* index of current initial */
    ZP_45 = 0xF4;                           /* reset ~64 s timeout */
    if (TEMP5 != 0 && !(SPFLG & 0x80)) {
        g.ram[0x138 + x] = 0x0B;            /* init next to A (special) */
        return 0;
    }
    g.ram[0x11A + x] = 0x0B;                /* set next initial to A */
    return 0;
}

/* letter stepper shared by Getstp's two columns: a = letter code after the
 * +/-1 add; returns the stored code, *cout = the flags path's carry. */
static uint8_t step_letter(uint8_t a, int *cout)
{
    if (a & 0x80) {                         /* before blank: make it Z */
        *cout = 0;                          /* $24 < $25 */
        return 0x24;
    }
    if (a >= 0x0B) {                        /* in A..Z (or past) */
        *cout = (a >= 0x25);
        return (a >= 0x25) ? 0x00 : a;      /* past Z: back to blank */
    }
    *cout = a & 1;                          /* LSR */
    a >>= 1;
    return (a != 0) ? 0x00 : 0x0B;          /* blank, or up from blank: A */
}

/* Getstp ($4EB9): rotate stick steps the letter every 8th frame.
 * x = TEMP5 (player), c = carry from the debounce CMP #$07. Returns C. */
static int getstp(uint8_t x, int c)
{
    uint8_t r, a, y;
    int cout = c;
    if ((ZP_44 & 0x07) != 0)
        return c;                           /* Getstp_90 keeps C */
    y = 0xFF;                               /* assume letters go down */
    r = sd_hw_in1((uint8_t)(2 + x));        /* ROTL,X */
    if (!(r & 0x80)) {
        r = sd_hw_in1((uint8_t)(2 + x));    /* Getstp_70 re-reads ROTL,X */
        c = (r >> 7) & 1;                   /* ASL carry-out */
        if (!((uint8_t)(r << 1) & 0x80))
            return c;                       /* not rotating right */
        y = 0x01;
    }
    /* Getstp_75 */
    a = y;
    x = TEMP5;
    if (x != 0 && !(SPFLG & 0x80)) {        /* special player-2 column */
        x = POTGO;
        a = (uint8_t)(a + g.ram[0x137 + x]);
        a = step_letter(a, &cout);
        g.ram[0x137 + x] = a;               /* Getstp_15 */
        return cout;                        /* LDA #$00; RTS */
    }
    /* Getstp_76 */
    x = POTGO;
    a = (uint8_t)(a + g.ram[0x119 + x]);
    a = step_letter(a, &cout);
    g.ram[0x119 + x] = a;                   /* Getstp_85 */
    return cout;                            /* Getstp_90 */
}

/* Getin6 ($4DFB): draw + edit one player's three initials. x = TEMP5.
 * Returns C (only the last player's pass reaches the mainline's BCC). */
static int getin6(uint8_t x)
{
    uint8_t cab, a, xx, base, deb;
    int c;
    if (g.ram[0x38 + x] & 0x80)
        return 0;                           /* to RTS (Getin2) */
    cab = sd_hw_in1(7);                     /* CABERE */
    if (cab & 0x80) {
        UPDOWN = dsp_rom_4F1A[x];           /* Updowtable,X */
        getin4();
    }
    center_beam_in_middle();
    use_full_size(0);                       /* double size */
    cab = sd_hw_in1(7);                     /* BIT CABERE */
    if (cab & 0x40)
        goto flipped;                       /* caberet cab */
    cab = sd_hw_in1(7);                     /* LDA CABERE */
    if (!(cab & 0x80)) {                    /* upright */
        a = 0x14; xx = 0x04;                /* Getin6_25 */
        if (TEMP5 != 0)
            a = 0xD8;                       /* second player */
        goto position;
    }
flipped:
    a = 0xF0; xx = 0x08;                    /* Getin6_21: flipped position */
    if (TEMP5 != 0)
        a = 0x00;
position:
    vg_vctr_dark(a, xx);                    /* position beam */
    x = TEMP5;
    base = g.ram[0x38 + x];                 /* LDY $38,X */
    TEMP2 = base;
    POTGO = (uint8_t)(base + g.ram[0x36 + x]); /* index of the initial */
    display_an_initial(base);
    display_an_initial((uint8_t)(TEMP2 + 1));
    display_an_initial((uint8_t)(TEMP2 + 2));
    /* Getin6_50: any button enters the letter (debounced over 5 frames) */
    x = TEMP5;
    a = (uint8_t)(sd_hw_in1(x) << 1);       /* HYPSW,X; ROL (bit6 -> 7) */
    a |= sd_hw_in1(x);                      /* ORA HYPSW,X */
    a |= sd_hw_in1((uint8_t)(4 + x));       /* ORA STRT1,X */
    c = (a >> 7) & 1;                       /* ROL: switch into carry */
    deb = g.ram[0x49 + x];                  /* LASTSW,X as debounce */
    g.ram[0x49 + x] = (uint8_t)((deb << 1) | (uint8_t)c); /* ROL LASTSW,X */
    a = (uint8_t)(g.ram[0x49 + x] & 0x1F);
    if (a != 0x07)                          /* on exactly last 3 of 5 */
        return getstp(x, a >= 0x07);        /* C from CMP #$07 */
    g.ram[0x36 + x]++;                      /* advance to next letter */
    if (g.ram[0x36 + x] < 0x03)
        return gotit();                     /* BCC Gotit */
    g.ram[0x38 + x] = 0xFF;                 /* done updating */
    if (x == 1)
        SPFLG = 0xFF;                       /* clear this one also */
    return prevent_timeout_both_players();
}

/* PutMessageUpOnce ($4DD9): one pass of the initials screen. Returns C. */
static int put_message_up_once(void)
{
    uint8_t a = ZP_45;                      /* entry timeout/stage */
    int c;
    if (!(a & 0x80)) {
        if (a != 0)
            return 0;                       /* not doing this (Getin2) */
        g.ram[0x38] = 0xFF;                 /* timed out - close both */
        g.ram[0x39] = 0xFF;
        return prevent_timeout_both_players();
    }
    if (!(sd_hw_in1(7) & 0x80))             /* CABERE: upright cabinet */
        getin4();
    TEMP5 = 1;                              /* L4DF0 */
    c = getin6(1);
    (void)c;                                /* player 1's C is overwritten */
    TEMP5 = 0;
    return getin6(0);                       /* falls into Getin6 */
}

/* GetPlayersInitials ($4DCD): returns C, 1 = entry finished.
 * Getin2 ($4DD8) is the shared RTS (C as left by the path taken; the
 * mainline arrives with C clear - see NOTES_display.md). */
int get_players_initials(void)
{
    if (!((g.ram[0x38] & g.ram[0x39]) & 0x80))
        return put_message_up_once();       /* someone is entering */
    HSCFLG = 0x00;                          /* L4DD3 */
    return 0;                               /* Getin2 */
}

/* ====================================================================== */
/* score headings + score/lives areas                                      */
/* ====================================================================== */

/* ScoreColorBasedAbove ($50C0): seed the default lowest high score
 * ($D5-$D7 = 03 FD 05... BCD bytes) and $00D8. */
void score_color_based_above(void)
{
    g.ram[0xD7] = 0x05;                     /* default high score byte */
    (g.ram[0x00D8]) = 0xFB;                          /* $D8 */
    g.ram[0xD5] = 0x03;
    g.ram[0xD6] = 0xFD;
}

/* Inselo ($50D5) lives in objects.c (declared in objects.h); display.c's
 * InitializeScoreHeadings falls into it at $4FF4->$50D5. */

/* InitializeScoreHeadings ($4FF4): fill $2300-$2350 (PL0SET..) with RTSLs,
 * then for each score area (2..0, +1 extra on cocktail) build heading
 * position + color + PLAYER-x block and the JMPL into the live area, and
 * repoint the live area's own start. Ends in Inselo. */
void initialize_score_headings(void)
{
    uint8_t x, a, cab, y;
    x = 0x50;
    do {
        g.vram[0x300 + x] = 0xC0;           /* STA PL0SET,X ($2300) */
        x--;
    } while (!(x & 0x80));
    x = 0x02;
    cab = sd_hw_in1(7);                     /* CABERE */
    if ((cab & 0x80) && ZP_34 != 0x03)
        x = 0x03;                           /* extra message if cocktail */
    for (;;) {
        FOURPI = x;                         /* which area */
        VGLIST = dsp_rom_50A8[(0x50B0 + x) - 0x50A8];  /* _115: list lo */
        EAC2 = dsp_rom_50A8[(0x50AC + x) - 0x50A8];  /* _110: list hi */
        x = FOURPI;
        if (x == 0)
            goto heading;                   /* this score for sure */
        if (x >= 2 && (TOGCOMB & 0x80))
            goto heading14;                 /* combined score areas */
        if (x >= 2)
            goto rtsl_only;
    heading14:                              /* _14 */
        if (ZP_34 == 0x01)
            goto rtsl_only;                 /* game 1: one score only */
        goto heading;
    rtsl_only:                              /* _16 */
        vg_add_rtsl();
        goto next_area;                     /* _90 */
    heading:                                /* _20 */
        vg_add2(0x61, 0xAF);                /* JSRL $3EC2 */
        a = sd_hw_in1(7);                   /* CABERE: flip? */
        if (a & 0x80) {
            if (ZP_34 == 0x03)
                a = ZP_34;                  /* no flip on game 3 */
            else
                a = dsp_rom_50A8[(0x50BC + FOURPI) - 0x50A8]; /* _130 */
        }
        UPDOWN = a;                         /* _25 */
        set_vg_status(dsp_rom_50A8[(0x50D1 + FOURPI) - 0x50A8]); /* Scrclr */
        vg_vctr_dark(dsp_rom_50A8[(0x50A8 + FOURPI) - 0x50A8], 0x5B);
        if (FOURPI >= 0x02) {               /* combined-score message */
            use_full_size(2);
            pass_color(dsp_rom_50A8[(0x50C4 + 0x0F) - 0x50A8], 0x0F);
            vg_vctr_dark(0xE0, 0xFA);
        }
        /* _26: JMPL to the live area, then build there */
        y = FOURPI;
        vg_add_jmpl(dsp_rom_50A8[(0x50B4 + y) - 0x50A8],   /* _120 hi */
                    dsp_rom_50A8[(0x50B8 + y) - 0x50A8]);  /* _125 lo */
        EAC2 = dsp_rom_50A8[(0x50B4 + y) - 0x50A8];
        VGLIST = dsp_rom_50A8[(0x50B8 + y) - 0x50A8];
        use_full_size(1);                   /* _30 */
        vg_vctr_dark(0xE4, 0xFA);           /* down & left, chars 24 tall */
    next_area:                              /* _90 */
        x = FOURPI;
        if (ZP_34 == 0x03)
            break;                          /* game 3: no other scores */
        x--;
        if (x & 0x80)
            break;
    }
    inselo();
}

/* Inset2 ($4FEE): ScoreColorBasedAbove + Inisou, falls into
 * InitializeScoreHeadings. */
void inset2(void)
{
    score_color_based_above();
    inisou();                               /* init sounds */
    initialize_score_headings();            /* fallthrough at $4FF4 */
}

/* Temp3WhichPlayer0 ($5C24) lives in objects.c (declared in objects.h);
 * display.c's DisplayParameters stages TEMP3 / the list pointer /
 * UPDOWN and calls it. */

/* DisplayParameters ($5CF2): rebuild any changed score+lives area, writing
 * straight into its vector-RAM block. */
void display_parameters(void)
{
    TEMP3 = 0x00;                           /* player tracker for lives */
    if (PL0SCFLAG & 0x80) {
        VGLIST = 0x80;                        /* list -> $2380 (PL0ARE) */
        EAC2 = 0x23;
        PL0SCFLAG = 0x00;
        UPDOWN = 0x00;                      /* no flip here */
        temp3_which_player0(0x3A);          /* player 0 score at $3A */
    }
    TEMP3++;                                /* _10 */
    if (PL1SCFLAG & 0x80) {
        PL1SCFLAG = 0x00;
        VGLIST = 0xC0;                        /* list -> $23C0 (PL1ARE) */
        EAC2 = 0x23;
        UPDOWN = sd_hw_in1(7);              /* CABERE: possible flip */
        if (ZP_34 == 0x03)
            UPDOWN = ZP_34;                 /* game 3: no flip */
        temp3_which_player0(0x3D);          /* _15: player 1 score */
    }
    if (CMBSCFLAG & 0x80) {                 /* _20 */
        UPDOWN = 0x00;                      /* always upright */
        CMBSCFLAG = 0x00;
        VGLIST = 0x80;                        /* list -> $2780 (CMBARE) */
        EAC2 = 0x27;
        TEMP3++;                            /* 2 = combined lives */
        temp3_which_player0(0x40);          /* combined score at $40 */
        UPDOWN = 0x80;                      /* flipped copy for cocktail */
        VGLIST = 0x36;                        /* list -> $2736 (CMSBAR) */
        EAC2 = 0x27;
        temp3_which_player0(0x40);
    }
    UPDOWN = 0x00;                          /* _40: restore */
}

/* ====================================================================== */
/* per-frame parameter display + list tail                                 */
/* ====================================================================== */

/* Entparams ($5C80): BONUS LEVEL message while the wave delay runs, the
 * comet-warning color pulse, and the fixed JSRLs that end every frame. */
void entparams(void)
{
    uint8_t a, cab;
    if (RDELAY != 0 && (ZP_35 & 0x80) && (ZP_44 & 0x04)) {
        UPDOWN = 0x00;                      /* up message */
        for (;;) {                          /* _20 */
            mesgpos(0xE0, 0x10);
            aux_routine_add_offset(1);
            brightness(0xA7, 0x14);         /* BONUS LEVEL */
            save_input_parameters(0xCF, 1, 1);  /* bonus amount at $CF */
            (void)display_digit(0);         /* phantom zero */
            if (UPDOWN & 0x80)
                break;                      /* already did extra */
            cab = sd_hw_in1(7);             /* CABERE */
            if (!(cab & 0x80))
                break;                      /* no extra message needed */
            UPDOWN = cab;                   /* upside down message */
            if (ZP_34 == 0x03)
                break;                      /* not for game 3 */
        }
    }
    if (COMTIMER != 0) {                    /* _80: comet warning pulse */
        a = (uint8_t)(ZP_44 >> 4);
        if (a == 0)
            a = 0x01;                       /* no black */
        set_vg_status((uint8_t)(a | INTEN));
        vg_add2(0x62, 0xA8);                /* JSRL $30C4 */
    }
    vg_add2(0x5E, 0xA8);                    /* _85: JSRL $30BC */
    vg_add2(0x8A, 0xA1);                    /* JSRL $2314 (CMBSET) */
}

/* AmountAddRoutineLimits ($67B6): a += 16-bit LNGTIMER/$03BA, limit $04xx. */
void amount_add_routine_limits(uint8_t a)
{
    unsigned t = (unsigned)a + LNGTIMER;
    LNGTIMER = (uint8_t)t;
    a = (uint8_t)(g.ram[0x3BA] + (t >> 8)); /* timer high + carry */
    if (a >= 0x04) {
        LNGTIMER = 0xFF;                    /* _10: set to max */
        return;
    }
    g.ram[0x3BA] = a;
}

/* ====================================================================== */
/* high score table                                                        */
/* ====================================================================== */

/* CcCarrySetDisplaying ($6002): C = 0, not doing anything here. */
int cc_carry_set_displaying(void)
{
    return 0;                               /* CLC */
}

/* Scores ($6004): the high-score table screen(s). Returns C = 1 while
 * displaying. */
int scores(void)
{
    uint8_t a, x, y, cab;
    TEMP9 = 0xFF;                            /* no need to STAT green yet */
    g.ram[0x14] = 0x01;                     /* show 2 tables */
s13:                                        /* Scores_13 */
    a = (uint8_t)(LASTG & 0x02);
    if (SHHIGH == 0) {                      /* Scores_12 */
        if (!(ZP_45 & 0x04))
            return cc_carry_set_displaying();
        a = (uint8_t)(ZP_45 >> 1);          /* show both tables */
        a = (uint8_t)((a & 0x01) << 1);     /* _15: 0 or 2 */
    }
    a = (uint8_t)(a + g.ram[0x14]);         /* _17: 0..3 */
    x = a;                                  /* _16 */
    g.ram[0x0E] = dsp_rom_6152[(0x6156 + x) - 0x6152];  /* score index */
    SKCTL = g.ram[0x0E];                    /* initials index */
    TEMP3 = 0x01;                           /* place indicator */
    TEMP5 = x;
    mesgpos(0xDC, 0x3C);
    aux_routine_add_offset(5);
    brightness(0xC2, 0x00);                 /* HIGH GENDING message */
    vg_vctr_dark(0xDD, 0xF0);
    aux_routine_add_offset(6);              /* to move ship pics */
    y = (uint8_t)(TEMP5 & 0x02);
    cab = sd_hw_in1(7);                     /* BIT CABERE */
    if (cab & 0x40)
        y++;
    vg_add2(dsp_rom_764E[(0x7652 + y) - 0x764E],   /* ship picture JSRL */
            dsp_rom_764E[(0x764E + y) - 0x764E]);
    cab = sd_hw_in1(7);                     /* BIT CABERE */
    if (!(cab & 0x40)) {                    /* player message needed */
        x = g.ram[0x14];
        mesgpos(dsp_rom_5FFE[(0x6000 + x) - 0x5FFE], 0x1C);
        x = TEMP5;
        y = dsp_rom_6152[(0x6152 + x) - 0x6152];  /* Scores_110: msg # */
        UPDOWN = y;                         /* always normal */
        vector_message5(y);                 /* 1/2 PLAYER, green */
    }
    FOURPI = 0x00;                          /* _19: starting Y per line */
s20:                                        /* Scores_20 */
    x = g.ram[0x0E];
    if ((g.ram[0xDD + x] | g.ram[0xDE + x] | g.ram[0xDF + x]) == 0)
        goto s80;                           /* empty entry: table done */
    center_beam_in_middle();                /* _21 */
    x = g.ram[0x14];
    a = dsp_rom_5FFE[(0x5FFE + x) - 0x5FFE];    /* line start X */
    cab = sd_hw_in1(7);
    if (cab & 0x40)
        a = 0xDA;
    vg_vctr_dark(a, FOURPI);                /* position line start */
    a = SKCTL;                              /* initials index */
    if (a == FLSFLG || a == g.ram[0x3EC]) { /* last entered? */
        set_vg_status(FLASHCOL);            /* _23: slow flash color */
        TEMP9 = 0x00;                        /* need-green flag */
    } else if (!(TEMP9 & 0x80)) {
        y = 0xC2;                           /* back to yellow */
        cab = sd_hw_in1(7);
        if (cab & 0x40)
            y = 0xC4;
        TEMP9 = y;                           /* already-green flag */
        set_vg_status(y);
    }
    if (TEMP5 == 0x02) {                    /* _24: game 2 second column */
        SPFLG = 0x00;                       /* special flag for Inita3 */
        inita3();
        inita3();
        inita3();
        SPFLG = 0xFF;                       /* restore */
        entry_index_character0(0);          /* add a space */
        SKCTL = (uint8_t)(SKCTL - 3);       /* back up initials index */
    }
    y = g.ram[0x0E];                        /* _22 */
    for (x = 0; x < 3; x++)                 /* zp,X wrap: TWOPI+$FD.. */
        g.ram[0x03 + x] = g.ram[0xDD + y + x];  /* score -> $03-$05 */
    save_input_parameters(0x03, 3, 1);      /* display score */
    (void)display_digit(0);                 /* trailing zero */
    entry_index_character0(0);              /* blank after score */
    inita3();
    inita3();
    inita3();
    FOURPI = (uint8_t)(FOURPI - 0x08);      /* next line down */
    g.ram[0x0E] = (uint8_t)(g.ram[0x0E] + 3);
    {                                       /* place: BCD increment */
        bcd_res r = bcd_adc(TEMP3, 0x01, 0);
        TEMP3 = r.r;
    }
    if (TEMP3 < 0x06)
        goto s20;
s80:                                        /* Scores_80 */
    cab = sd_hw_in1(7);
    if (cab & 0x40)
        g.ram[0x14] = (uint8_t)(g.ram[0x14] - 2);
    else
        g.ram[0x14] = (uint8_t)(g.ram[0x14] - 1);
    if (!(g.ram[0x14] & 0x80))
        goto s13;
    return 1;                               /* Scores_81 SEC */
}

/* ====================================================================== */
/* object pictures (Pictur and children)                                   */
/* ====================================================================== */

/* Expset ($623E): seed the 12 explosion-piece coordinate pairs for ship x
 * in the SH0XPCOORD area ($2700/$2718) - direct vector-RAM writes. */
void expset(uint8_t x)
{
    uint8_t y = dsp_rom_6257[(0x6236 + x) - 0x6257];  /* Shpcor,X-$21 */
    uint8_t i;
    for (i = 0; i < 0x0C; i++) {
        g.vram[0x700 + y] = dsp_rom_6CB5[i];          /* ChangeDirection */
        y++;
        g.vram[0x700 + y] = dsp_rom_6CB5[0x0C + i];   /* HoldsSign2Byte */
        y++;
    }
}

/* ShipExplodingPictures ($6169): flashing ship and/or drifting pieces.
 * x = exploding ship's object index ($21/$22) = TEMP3. */
static void ship_exploding_pictures(uint8_t x)
{
    uint8_t a, sx;
    unsigned t;
    if (ZP_34 == 0x00) {                    /* fighters? */
        if (!(g.ram[0x39A + x] & 0x80))     /* WHOSHOT,X: killed by rock */
            goto pieces;
    } else if (ZP_34 == 0x01) {
        goto pieces;                        /* this game always pieces */
    }
    /* _1 */
    if (!(g.ram[0x3CE + x] & 0x80))         /* EXPDEC,X: pieces only? */
        goto pieces;
    if (ZP_44 & 0x04)                       /* flash rate */
        display_ship_picture(x);
    if (ZP_34 == 0x00)                      /* _3: not space station */
        return;                             /* just flash */
pieces:                                     /* _5 */
    use_full_size(1);
    x = TEMP3;
    a = (x == 0x21) ? 0xF4 : 0xF2;
    vg_add2(a, 0x64);                       /* _6: piece color */
    x = TEMP3;
    if (g.ram[0x97 + x] < 0xA2)             /* first explosion frame */
        expset(x);                          /* init pieces */
    x = TEMP3;                              /* _20 */
    TEMP4 = (uint8_t)((((g.ram[0x97 + x] ^ 0xFF) & 0x70) >> 3) & 0xFE);
    TEMP1 = dsp_rom_6257[(0x6236 + x) - 0x6257];  /* piece coord ptr lo */
    EACE = 0x27;                            /* ptr hi -> $27xx */
    NMROCK = 0x00;
    do {                                    /* _25: one piece per pass */
        TEMP2 = VGLIST;                      /* save list pos for the */
        POTGO = EAC2;                       /*   negated return leg */
        x = NMROCK;
        a = dsp_rom_6CB5[(0x6CB5 + x) - 0x6CB5];  /* Y velocity */
        sx = (uint8_t)((a & 0x80) ? 0xFF : 0x00); /* sign extension */
        t = (unsigned)a + rd_pair(0x07, 0); /* pos lo += vel */
        wr_pair(0x07, 0, (uint8_t)t);
        t = (unsigned)sx + rd_pair(0x07, 1) + (t >> 8);
        wr_pair(0x07, 1, (uint8_t)t);       /* pos hi */
        vg_poke_list(0, (uint8_t)t);        /* pos hi as VCTR Y lsb */
        vg_poke_list(1, (uint8_t)(sx & 0x1F));    /* Y msb = sign bits */
        x = NMROCK;
        a = dsp_rom_6CB5[(0x6CB6 + x) - 0x6CB5];  /* X velocity */
        sx = (uint8_t)((a & 0x80) ? 0xFF : 0x00);
        t = (unsigned)a + rd_pair(0x07, 2);
        wr_pair(0x07, 2, (uint8_t)t);
        t = (unsigned)sx + rd_pair(0x07, 3) + (t >> 8);
        wr_pair(0x07, 3, (uint8_t)t);
        vg_poke_list(2, (uint8_t)t);        /* pos hi as VCTR X lsb */
        vg_poke_list(3, (uint8_t)(sx & 0x1F));
        vg_advance_list(3);                 /* position vector done */
        x = (uint8_t)(NMROCK << 1);         /* _60: copy the piece VCTR */
        for (a = 0; a < 4; a++)
            vg_poke_list(a, sd_vecrom[0x3668 + x + a - 0x2800]);
        vg_advance_list(3);
        negate_a_long_vector();             /* dark return leg */
        TEMP1 = (uint8_t)(TEMP1 + 4);       /* next piece coordinates */
        NMROCK = (uint8_t)(NMROCK + 2);
    } while (NMROCK < TEMP4);
}

/* Pictur ($5D6D): draw object x. Entry: x = TEMP3 = object index; the
 * object's position is staged in RED/XCOMP (X) and TWOPI/CHAN3V (Y)
 * by MotionUpdateRoutine. First emits JSRL $30B6 + centered position
 * VCTR, then dispatches on object class. */
void pictur(uint8_t x)
{
    uint8_t a, xx, y, c;
    if (x == 0x1F)                          /* just in case super saucer */
        always_remains_same_both();
    /* Pictur_1: position words, raw (VGLIST),Y stores */
    a = (uint8_t)(RED - 0x10);              /* X pos to 2's complement */
    c = (uint8_t)(a & 1);
    a >>= 1;
    XCOMP = (uint8_t)((XCOMP >> 1) | (c << 7));  /* ROR XCOMP */
    vg_poke_list(5, (uint8_t)(a & 0x1F));   /* brightness of 0 */
    vg_poke_list(4, XCOMP);
    a = (uint8_t)(TWOPI - 0x0C);            /* Y pos to 2's complement */
    c = (uint8_t)(a & 1);
    a >>= 1;
    CHAN3V = (uint8_t)((CHAN3V >> 1) | (c << 7));  /* ROR CHAN3V */
    vg_poke_list(3, (uint8_t)(a & 0x1F));   /* instruction of 0 */
    vg_poke_list(2, CHAN3V);
    vg_poke_list(1, 0xA8);                  /* JSRL $30B6 */
    vg_poke_list(0, 0x5B);
    vg_advance_list(5);                     /* VGLIST += 6 */
    /* Pictur_20 */
    if (g.ram[0x97 + x] & 0x80) {           /* exploding */
        if (x >= 0x21 && x < 0x23) {
            ship_exploding_pictures(x);     /* explode ship */
            return;
        }
        /* Pictur_32: generic explosion picture */
        a = (uint8_t)(g.ram[0x97 + x] ^ 0xF0);
        if (!(SPECEX & 0x80))
            a = (uint8_t)(a + 0x10);
        xx = (uint8_t)((a >> 4) | 0x70);    /* SCAL */
        vg_add2(0x00, xx);
        x = TEMP3;
        y = (uint8_t)(g.ram[0x97 + x] & 0x0E);  /* explosion phase (PHA) */
        if (SPECEX & 0x80) {                /* special explosions */
            a = (uint8_t)(x & 0x07);
            if (a == 0)
                a = 0x04;                   /* default red */
            vg_add2((uint8_t)(a | 0xF0), 0x64);
            vg_add2(dsp_rom_6E5C[(0x6E6C + y) - 0x6E5C],  /* special JSRL */
                    dsp_rom_6E5C[(0x6E6D + y) - 0x6E5C]);
            return;
        }
        vg_add2(dsp_rom_6E5C[(0x6E5C + y) - 0x6E5C],      /* normal JSRL */
                dsp_rom_6E5C[(0x6E5D + y) - 0x6E5C]);
        return;
    }
    /* Pictur_35 */
    if (x < 0x11) {                         /* rocks/obstacles */
        if (SPECEX & 0x80) {                /* special explosion mode */
            vg_add2(0x00, 0x72);            /* SCAL */
            vg_add2(0x88, 0xAF);            /* JSRL $3F10 */
            return;
        }
        /* Pictur_8: scale + color + picture, raw stores then advance */
        vg_poke_list(0, 0x00);              /* full linear scale */
        y = (uint8_t)(g.ram[0x97 + x] & 0x07);  /* size */
        a = dsp_rom_5F46[(0x5F46 + y) - 0x5F46];    /* SCAL hi byte */
        g.ram[0x17] = a;                    /* save for attract letters */
        vg_poke_list(1, a);
        a = (uint8_t)(x & 0x07);            /* only 7 colors */
        if (a == 0)
            a = 0x03;                       /* Pictur_5 */
        vg_poke_list(2, (uint8_t)(a | 0xE0));   /* COLOR + intensity */
        vg_poke_list(3, 0x64);
        if (ATSTG & 0x80) {                /* attract wants letters */
            vg_poke_list(4, 0xC1);          /* word $ACC1 = JSRL $3982 */
            vg_poke_list(5, 0xAC);
        } else {                            /* Pictur_7/_10 */
            xx = (uint8_t)((g.ram[0x97 + x] & 0x38) >> 2);  /* pic *2 */
            vg_poke_list(4, dsp_rom_6E5C[(0x6ECD + xx) - 0x6E5C]);
            vg_poke_list(5, dsp_rom_6E5C[(0x6ECE + xx) - 0x6E5C]);
        }
        vg_advance_list(5);                 /* _15: VGLIST += Y+1 */
        if (ATSTG & 0x80) {                /* _37: attract special */
            g.ram[0x17]++;                  /* next scale size */
            use_full_size(g.ram[0x17]);
            (void)vg_char(dsp_rom_5F46[(0x5F57 + (TEMP3 & 0x0F)) - 0x5F46],
                          0);               /* Cubltr,X -> SaveCFlag */
        }
        return;                             /* Pictur_39 */
    }
    /* Pictur_40 */
    if (x >= 0x24) {                        /* shots */
        if ((ZP_44 & 0x03) == 0)
            g.ram[0x97 + x]--;              /* shell life counter */
        a = (uint8_t)((uint8_t)(g.ram[0x97 + x] << 3) & 0xF0);
        a = (uint8_t)(a + dsp_rom_5F46[(0x5F27 + x) - 0x5F46]); /* + color */
        vg_poke_list(0, a);                 /* STAT: fade with life */
        vg_poke_list(1, 0x64);
        if (x < 0x28) {                     /* ship shot */
            lsb_byte(2, 0x00, 0x73);        /* SCAL */
            vg_add2(0xC7, 0x64);            /* COLOR white */
            vg_add2(0x68, 0xA1);            /* JSRL $22D0 (SPARKB) */
            return;
        }
        lsb_byte(2, 0x42, 0xAF);            /* _86: JSRL $3E84 */
        return;
    }
    if (x >= 0x21) {                        /* Pictur_74: ships */
        display_ship_picture(x);
        return;
    }
    /* Pictur_70: $11-$20 */
    if (x >= 0x1F) {                        /* saucers */
        if (!(g.ram[0x97 + x] & 0x40)) {    /* which pic? */
            vg_poke_list(0, 0x00);
            vg_poke_list(1, 0x72);          /* SCAL */
            xx = (uint8_t)(SAUCIX << 1);    /* pic code */
            vg_poke_list(2, sd_vecrom[0x3E46 + xx - 0x2800]);  /* SAUCRC */
            msb_byte(3, sd_vecrom[0x3E47 + xx - 0x2800]);
            return;
        }
        a = (x == 0x1F) ? 0xD4 : 0xD2;      /* _71: saucer color */
        lsb_byte(0, a, 0x64);
        use_full_size(2);                   /* _73 */
        vg_add2(0x27, 0xAF);                /* JSRL $3E4E */
        vg_add2(0x68, 0xA1);                /* JSRL $22D0 (SPARKB) */
        return;
    }
    if (x >= 0x19) {                        /* Pictur_80: killer mines */
        vg_poke_list(0, (uint8_t)(INTEN | g.ram[0xB0 + x])); /* pulse */
        vg_poke_list(1, 0x64);
        lsb_byte(2, 0x34, 0xAF);            /* _79: JSRL $3E68 (MINE) */
        return;
    }
    /* Pictur_90: mines $11-$18 */
    if (g.ram[0x37E + x] & 0x80) {          /* grown up: $037E,X is the
                                             * per-object comet flag set by
                                             * SbttlStcomet ($53CC, STA
                                             * $037E,X #$80) - NOT COMTYP
                                             * ($038F, a different, per-
                                             * comet-slot array indexed 0-7) */
        vg_poke_list(0, FLASHCOL);          /* _95 */
        vg_poke_list(1, 0x64);
        lsb_byte(2, 0xB6, 0xAE);            /* JSRL $3D6C */
        return;
    }
    lsb_byte(0, 0xE1, 0xAE);                /* small: JSRL $3DC2, Y=0 */
}

/* ====================================================================== */
/* ship pictures (NOT AVG data - signed (dy,dx) byte pairs at $2800-$2FFF) */
/* ====================================================================== */

/* RoutineAlsoDoesBlanking ($652F): called after every emitted record;
 * counts TEMPA down and inserts a 2-word STAT - black at the damage spot
 * (Shpd4table) when PRTDAMAGE says so, white when the thrust flame starts
 * (TEMPA == $FE). Y (list offset) in/out. AlsoUsedFromBelow ($6553) is
 * the shared RTS. */
static uint8_t routine_also_does_blanking(uint8_t y)
{
    uint8_t x = TEMP3, a;
    TEMPA--;                                /* another vector */
    a = TEMPA;
    if (a == dsp_rom_63F0[(0x63DB + x) - 0x63F0] &&   /* Shpd4table */
        (g.ram[0x367 + x] & 0x80)) {        /* PRTDAMAGE,X: damaged? */
        a = 0x00;                           /* black STAT */
    } else if (TEMPA == 0xFE) {             /* _10: time for thrust */
        a = 0xF7;                           /* white thrust */
    } else {
        return y;                           /* AlsoUsedFromBelow */
    }
    y++;                                    /* _15 */
    vg_poke_list(y, a);
    y++;
    vg_poke_list(y, 0x64);
    return y;
}

/* ThenPartiallyDamagedOtherwise ($64A4): after the record loop - clear the
 * z bits of the last record (dark return leg), of the record at TEMPB and
 * TEMPB+4 (flame bridge), and of the first record's X word (the dark
 * centre-to-hull offset, the SHPDI8 codicil), then advance the list. */
static void then_partially_damaged(uint8_t y)
{
    if (y >= 0x1E) {
        vg_poke_list(y, (uint8_t)(list_peek(y) & 0x1F));
        TEMP2 = y;                         /* STY TEMP2 */
        y = TEMPB;                          /* WhereFirstByteBlank */
        vg_poke_list(y, (uint8_t)(list_peek(y) & 0x1F));
        y = (uint8_t)(y + 4);
        vg_poke_list(y, (uint8_t)(list_peek(y) & 0x1F));
    }
    /* _60: first record's X msb (offset 3) goes dark */
    vg_poke_list(3, (uint8_t)(list_peek(3) & 0x1F));
    vg_advance_list(TEMP2);                /* LDY TEMP2; AddY1ToVector.
                                             * If y<$1E TEMP2 still holds
                                             * the picture pointer lo -
                                             * never reached for real ship
                                             * counts (y >= $5B). */
}

/* Fall ($6437) + BothReflects88Cycle ($6474) + Shpdi5 ($64CF) +
 * NoReflects76Cycle ($6501): emit ycount+1 picture records as 2-word long
 * vectors. Reflect flags ride in $12: bit 7 = negate the X byte, bit 6 =
 * negate the Y byte. Each record: raw byte as delta lsb, msb = sign bits
 * only ($00/$1F for Y, $20/$3F for X - the $20 is SHPLUM's z=1 "use the
 * COLOR intensity"). Picture bytes stream through (TEMP2),0 with 8-bit
 * INC TEMP2 (never carries into POTGO). */
static void fall(uint8_t ycount)
{
    uint8_t y = 0xFF, flags = g.ram[0x12];  /* BIT $12 */
    int neg_y = (flags & 0x40) != 0;        /* V: Y reflect */
    int neg_x = (flags & 0x80) != 0;        /* N: X reflect */
    TEMP1 = ycount;                         /* STY TEMP1 */
    for (;;) {
        uint8_t b, v;
        y++;
        b = rd_pair(0x0A, 0);               /* LDA (TEMP2,X): YY byte */
        v = neg_y ? (uint8_t)(0u - b) : b;
        vg_poke_list(y, v);                 /* Y delta lsb */
        y++;
        vg_poke_list(y, (uint8_t)((v & 0x80) ? 0x1F : 0x00)); /* Y msb */
        TEMP2++;                           /* 8-bit page-local advance */
        y++;
        b = rd_pair(0x0A, 0);               /* XX byte */
        v = neg_x ? (uint8_t)(0u - b) : b;
        vg_poke_list(y, v);                 /* X delta lsb */
        y++;
        vg_poke_list(y, (uint8_t)((v & 0x80) ? 0x3F : 0x20)); /* X msb+z */
        TEMP2++;
        y = routine_also_does_blanking(y);  /* color thrust check */
        TEMP1--;
        if (TEMP1 & 0x80)                   /* DEC TEMP1 / BPL */
            break;
    }
    then_partially_damaged(y);
}

/* Shpdisplays ($63FE): x = object index ($21/$22), y = index into the
 * picture pointer table at $2800 (CKUM4/ROCKA). Loads the picture pointer
 * into TEMP2/POTGO, the fixed record counts (SHPD2TABLE model - see
 * disasm/NOTES.md), and emits via Fall. Thrust adds SHPD3TABLE's 4 records
 * when the thrust switch is down mid-game on the flash phase. */
void shpdisplays(uint8_t x, uint8_t y)
{
    uint8_t cnt;
    TEMP3 = x;                              /* save X */
    TEMP2 = sd_vecrom[y];                  /* LDA CKUM4,Y ($2800+Y) */
    POTGO = sd_vecrom[1u + y];              /* LDA ROCKA,Y ($2801+Y) */
    cnt = dsp_rom_63F0[(0x63D7 + x) - 0x63F0];  /* CountWholeShipVectors */
    TEMPA = cnt;                            /* for color thrust */
    TEMPB = dsp_rom_63F0[(0x63D5 + x) - 0x63F0];/* WhereFirstByteBlank */
    TEMPA = cnt;                            /* Shpdisplays_20 reload */
    if ((ZP_35 & 0x80) &&                   /* no thrust in attract */
        (sd_hw_in1((uint8_t)(x - 0x1D)) & 0x80) && /* thrust sw $08E3,X */
        !(g.ram[0x97 + x] & 0x80) &&        /* not suspended animation */
        (ZP_44 & 0x04) &&                   /* flame flash phase */
        !(x == 0x22 && (ZP_51 & 0x80)))     /* drone never thrusts */
        cnt = dsp_rom_63F0[(0x63D9 + x) - 0x63F0]; /* CountShipWithThrust */
    fall(cnt);
}

/* DisplayShipPicture ($6259): shield STAT + shield JSRL, player color,
 * then fold SANGLE into a 0-$20 picture index + reflect flags ($12) and
 * draw via Shpdisplays. Falls into Drawrod. x = object index = TEMP3. */
void display_ship_picture(uint8_t x)
{
    uint8_t a, c;
    a = (uint8_t)(g.ram[0x2E + x] & 0x80);  /* $4F/$50: shield up? */
    if (a != 0)
        a = (uint8_t)((g.ram[0x252 + x] & 0xF0) | 0x07); /* SHLDENG,X,
                                                          * shield white */
    vg_poke_list(0, a);                     /* intensity register */
    vg_poke_list(1, 0x64);
    lsb_byte(2, 0x50, 0xAF);                /* JSRL $3EA0 (SHIELD) */
    x = TEMP3;
    if (!(ZP_44 & 0x04) && g.ram[0x3C6 + x] != 0) {  /* ENTER,X flash */
        a = (uint8_t)(((g.ram[0x3C6 + x] ^ 0xF0) & 0xF0) | 0x07);
    } else {
        a = (x == 0x21) ? 0xD4 : 0xD2;      /* _45: ship color */
    }
    vg_add2(a, 0x64);                       /* _50 */
    x = TEMP3;
    /* _90: angle -> quadrant + reflects */
    a = g.ram[0x282 + x];                   /* SANGLE,X */
    c = 0;                                  /* CLC: reflect Y off */
    if (a & 0x80) {
        a = (uint8_t)(0u - a);              /* 256-angle */
        c = 1;                              /* reflect Y on */
    }
    TEMPA = a;                              /* _10: 0 to $80 */
    g.ram[0x12] = (uint8_t)((g.ram[0x12] >> 1) | (c << 7)); /* ROR $12 */
    c = 0;                                  /* CLC: reflect X off */
    if (TEMPA & 0xC0) {                     /* BMI or BVS: sectors 2/3 */
        a = (uint8_t)(0x80 - TEMPA);        /* _15: 128-angle */
        c = 1;                              /* reflect X on */
    }
    g.ram[0x12] = (uint8_t)((g.ram[0x12] >> 1) | (c << 7)); /* _20 */
    a = (uint8_t)((a & 0xFC) >> 1);         /* picture number * 2 */
    shpdisplays(x, (uint8_t)(a + dsp_rom_63F0[(0x63D3 + x) - 0x63F0]));
    drawrod();                              /* fallthrough at $62C6 */
}

/* ====================================================================== */
/* connecting rod + sparks                                                 */
/* ====================================================================== */

/* WhiteSparkles ($637C): STAT white + big scale + JSRL $22D0 (SPARKB). */
static void white_sparkles(void)
{
    vg_add2(0xF7, 0x64);                    /* white sparkles */
    use_full_size(1);                       /* make fuse sparks large */
    vg_add2(0x68, 0xA1);                    /* JSRL $22D0 */
}

/* Drawrod ($62C6): the rod between the rigid pair, once per frame (via
 * RODSTATUS). While SPARKTIME >= 0 the fuse burns: rod scaled by
 * 2*SPARKTIME/128 with crackle sound, ending in the ship explosion. */
void drawrod(void)
{
    uint8_t x, d, c;
    unsigned t;
    if (!(TOGCOMB & 0x80))
        return;                             /* not the rigid pair */
    if (RODSTATUS & 0x80)
        return;                             /* already drew a rod */
    vg_add2(0xF6, 0x64);                    /* _12: yellow rod */
    x = TEMP3;
    if (g.ram[0x97 + x] & 0x80)
        return;                             /* skip if exploding */
    RODSTATUS--;                            /* will have drawn the rod */
    if (!(SPARKTIME & 0x80)) {              /* somebody died: fuse burns */
        random_fuzz(x, TEMP2);             /* crackle: X=TEMP3, Y=TEMP2
                                             * leftover (same pair the
                                             * Explosion below carries) */
        SPARKTIME--;
        if (SPARKTIME == 0) {               /* dead now */
            stop_fuse_sound();
            g.ram[0x97 + x] = 0xA0;         /* explode */
            explosion(x, TEMP2);           /* JSR Explosion: X=TEMP3 still
                                             * live; TEMP2 holds Shpdisplays'
                                             * final list-offset Y (STY TEMP2
                                             * in ThenPartiallyDamagedOtherwise,
                                             * $64AE), untouched since - the
                                             * real Y the ROM carries in here */
            g.ram[0x24C + x] = 0x20;        /* SDELAY area */
            g.ram[0x3CE + x] = 0x20;        /* EXPDEC,X: pieces only */
            get_comet_to_go();
            return;
        }
    }
    /* _20: delta to the pair object ($23), wrapped, halved into the
     * long-vector zp quad */
    t = (unsigned)g.ram[A_OBJXL + 0x23] - g.ram[0x320 + x];   /* $0343 */
    XCOMP = (uint8_t)t;
    d = (uint8_t)(g.ram[A_OBJXH + 0x23]     /* $02D8 */
                  - g.ram[0x2B5 + x] - ((t >> 8) & 1));
    if (!((uint8_t)(d - 0x10) & 0x80))      /* CMP #$10 / BMI */
        d = (uint8_t)(d - 0x20);            /* carry was set */
    if ((uint8_t)(d - 0xF0) & 0x80)         /* _30: CMP #$F0 / BPL */
        d = (uint8_t)(d + 0x20);            /* carry was clear */
    c = (uint8_t)(d & 1);                   /* _40: LSR */
    RED = (uint8_t)(d >> 1);
    XCOMP = (uint8_t)((XCOMP >> 1) | (c << 7)); /* ROR XCOMP */
    t = (unsigned)g.ram[A_OBJYL + 0x23] - g.ram[0x352 + x];   /* $0375 */
    CHAN3V = (uint8_t)t;
    d = (uint8_t)(g.ram[A_OBJYH + 0x23]     /* $030A */
                  - g.ram[0x2E7 + x] - ((t >> 8) & 1));
    if (!((uint8_t)(d - 0x0C) & 0x80))      /* CMP #$0C / BMI */
        d = (uint8_t)(d - 0x18);
    if ((uint8_t)(d - 0xF4) & 0x80)         /* _50: CMP #$F4 / BPL */
        d = (uint8_t)(d + 0x18);
    c = (uint8_t)(d & 1);                   /* _60: LSR */
    TWOPI = (uint8_t)(d >> 1);
    CHAN3V = (uint8_t)((CHAN3V >> 1) | (c << 7)); /* ROR CHAN3V */
    VGBRIT = 0xAF;                           /* z byte for the rod */
    if (SPARKTIME & 0x80) {                 /* nobody died yet */
        vg_add_vector_from_zp(3);           /* full rod (exit) */
        return;
    }
    /* _70: rod shrinking - each component * (2*SPARKTIME)/128 */
    TEMP1 = (uint8_t)(SPARKTIME << 1);      /* multiplier */
    x = 0x02;                               /* start with Y component */
    for (;;) {
        uint8_t a;
        NMROCK = x;                         /* _75 */
        c = (uint8_t)(g.ram[0x04 + x] & 1); /* LSR RED,X */
        g.ram[0x04 + x] >>= 1;
        a = (uint8_t)((g.ram[0x03 + x] >> 1) | (c << 7)); /* ROR A */
        a = output_temp2_temp21(a);         /* * TEMP1 -> POTGO/TEMP2 */
        x = NMROCK;
        g.ram[0x04 + x] = 0x00;             /* STA RED,X */
        if (a & 0x80)                       /* POTGO sign */
            g.ram[0x04 + x] = 0xFF;         /* DEC RED,X */
        c = (uint8_t)((a >> 7) & 1);        /* _77: ASL carry */
        g.ram[0x04 + x] = (uint8_t)((g.ram[0x04 + x] << 1) | c);
        g.ram[0x03 + x] = (uint8_t)(a << 1);/* STA XCOMP,X */
        if (x == 0)
            break;                          /* DEX DEX BPL */
        x = (uint8_t)(x - 2);
    }
    vg_add_vector_from_zp(3);
    white_sparkles();                       /* fallthrough at $637C */
}

/* Spark2 ($638F): every other frame, rebuild the four spark spokes as
 * paired out-and-back vectors directly in the SPARKB slot ($22D0) -
 * repoints the list pointer there. Spoke angle re-randomized every 16
 * (frame/2) counts, length = phase * sin/cos. */
void spark2(void)
{
    uint8_t a, y;
    if (!(sd_hw_in0() & 0x10))
        return;                             /* self-test: don't run */
    if (!(ZP_44 & 0x01))
        return;                             /* every other frame */
    VGLIST = 0xD0;                            /* list -> $22D0 (SPARKB) */
    EAC2 = 0x22;
    FOURPI = 0x03;                          /* _5: spark spokes */
    do {                                    /* _10 */
        y = FOURPI;
        a = (uint8_t)(((ZP_44 >> 1) +       /* group phase offset */
                       dsp_rom_63F0[(0x63F0 + y) - 0x63F0]) & 0x0F);
        TEMP1 = a;
        if (a == 0)                         /* restart this sparklet */
            g.ram[A_SPARKANGLE + y] = sd_hw_pokey_random(0); /* $100A */
        a = pi_angle0(g.ram[A_SPARKANGLE + y]);   /* _50: sin */
        a = output_temp2_temp21(a);         /* * phase */
        g.ram[0x14] = a;                    /* X result */
        y = FOURPI;
        a = cos_sin_pi2(g.ram[A_SPARKANGLE + y]); /* cos */
        a = output_temp2_temp21(a);
        TEMP5 = a;                          /* Y result */
        vg_vctr_z(TEMP5, g.ram[0x14], 0x20);      /* out */
        vg_vctr_z((uint8_t)(0u - TEMP5),          /* and back */
                  (uint8_t)(0u - g.ram[0x14]), 0x20);
        FOURPI--;
    } while (!(FOURPI & 0x80));             /* DEC / BPL */
}
