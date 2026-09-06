/* score.c - Space Duel C port: the live score, high-score table
 * maintenance and the game-select screen (AddPointsToScore $5F68,
 * UpdateHighScoreTable $6614, Display4Names $7529).
 *
 * AddPointsToScore keeps the live 3-byte BCD score that
 * UpdateHighScoreTable reads at game end - the two are the write and read
 * ends of the same $3A-$42 cells, which is why they share this file.
 * UpdateHighScoreTable sits in the object/rock-splitting address range but
 * is pure score-table logic; Display4Names is the labelled A2NAME module.
 * Both share the same live-score/high-score-table cells that earom.c's
 * buffer copies also touch - see NOTES_score.md for the full memory map
 * this file was reverse-engineered against.  The addresses this file spells
 * in raw hex - $3B-$3F and $DA-$DC - are interior bytes of SCORE ($3A, six
 * bytes) and of HSCORE-3, the source slot of the high-score shift-down.
 * They looked like unrelated variables until the RAM map was corrected (the
 * page 0 table used to sit 9 bytes high); the hex is kept because the
 * aliases name only the first byte of each array.
 */
#include "sd_state.h"
#include "sd_hw.h"
#include "sd_bcd.h"
#include "vgutil.h"
#include "score_data.h"
#include "sound.h"
#include "score.h"

/* ---- cross-module externs (translated elsewhere) ------------------------ */
extern void bigbang(void);                       /* Bigbang $76CC (mainline.c) */
extern void mesgpos(uint8_t a, uint8_t x);        /* Mesgpos $7760 (msgs.c)     */
extern void pass_color(uint8_t a, uint8_t y);     /* PassColor $7773 (msgs.c)   */
extern void vector_message5(uint8_t y);           /* VectorMessage5 $7779 (msgs.c) */
extern void aux_routine_add_offset(uint8_t x);    /* AuxRoutineAddOffset $7730 (msgs.c) */
extern void extra_life2(uint8_t x, uint8_t y);     /* ExtraLife2 $72E1 (sound.c) */

/* ---- tiny high-score-table lookup tables (byte-checked by
 * tools/gen_score_data.py against ../disasm/build/spacduel_64k.bin;
 * ROM base $6156) --- */
/* FifthValueUpdateCheck ($6156): high-score-table start offset per game
 * type 0-3 (5th entry $3C is unused - never indexed by a 0-3 game type). */
#define FIFTH_VALUE_UPDATE_CHECK(y) (score_rom_6156[(0x6156 + (y)) - 0x6156])
/* Hscend ($615B): initials-shift end offset (last valid slot) per game type. */
#define HSCEND(y) (score_rom_6156[(0x615B + (y)) - 0x6156])

/* ------------------------------------------------------------------ */
/* AddPointsToScore ($5F68)                                            */
/* ------------------------------------------------------------------ */

/* AddPointsToScore ($5F68): the live running score.  Adds a BCD point
 * value to the owning player's 3-byte score, propagates the BCD carry,
 * mirrors the same points into the combined-game score, and hands out a
 * bonus life whenever a player crosses his next bonus threshold.
 *
 * Register protocol (derived from all five ROM call sites - $450A/$466B
 * DestructionDuringCollision/DestroyXShip, $53DF KillXSaucer, $6572/$65AA
 * SplitRockIntoFragments - and matching objects.c's existing extern):
 *   in  A = the BCD point value in tens ($10 = 100 points, $20 = 200,
 *           $25 = crippled ship, $30 = saucer, $50 = full ship).  The
 *           value actually banked is A + $CF - 1 in BCD, i.e. the points
 *           stepped up by the current difficulty level.
 *   out nothing.  X is CLOBBERED (it ends up as OWNER, or as the score
 *           slot 0/3 on the combined path); every ROM call site that
 *           still needs X reloads it from TEMP3/TEMP1 afterwards, and
 *           objects.c already flags that at its two affected sites.
 *           Y is preserved (never touched here).  The D and C flags are
 *           cleaned up by the CLD at _80/_90.
 *
 * THE SCORE CELLS (see NOTES_score.md):
 *   $3A,X / $3B,X / $3C,X are the 3-byte live score for slot X (0 =
 *   right/solo player, 3 = left player) - that is SCORE and its two
 *   following bytes.  The combined-game slot is slot 6, which the ROM
 *   spells out absolutely as CMBSCORE ($40) / $41 / $42.  Raw hex is used
 *   for the interior bytes because the aliases name only the first byte
 *   of each array.  BONLVA ($DB) and NXTBON ($D9) are read as themselves
 *   here (bonus-life step and per-player bonus threshold), so they keep
 *   their macros.
 *
 * The whole body from L5F72 (SED) to the CLD at _80/_90 runs in decimal
 * mode: every ADC/SBC below goes through sd_bcd.h.  CMP/INC/DEC are not
 * affected by the D flag and stay plain binary.
 *
 * The opening `BIT $35 / BMI` makes the whole routine a no-op outside a
 * game, which is why tests/ref/coverage_attract.md never shows the ROM
 * inside it - the temporary stub this replaces was safe for exactly that
 * reason. */
void add_points_to_score(uint8_t a)
{
    uint8_t owner, x;
    bcd_res r;
    int c;

    if (!(ZP_35 & 0x80))                    /* L5F68/A: BIT $35 / BMI _5    */
        return;                             /* L5F6C _1: no score in attract */
    owner = OWNER;                          /* L5F6D                        */
    if (owner & 0x80)                       /* L5F70 BMI _1: nobody owns it */
        return;

    /* L5F72 SED - decimal from here to the CLD at _80/_90. */
    r = bcd_adc(a, g.ram[0xCF], 0);         /* L5F73/4: CLC / ADC $CF (diffcty) */
    r = bcd_sbc(r.r, 0x01, 1);              /* L5F76/7: SEC / SBC #$01      */
    a = r.r;
    TEMPA = a;                              /* L5F79: kept for the combined score */

    g.ram[A_PL0SCFLAG + owner]--;           /* L5F7B: tell the IRQ this score changed */
    x = (owner == 0) ? 0 : 3;               /* L5F7E-82: 3 score bytes/slot */

    /* AddPointsToScore_10 ($5F84) */
    r = bcd_adc(a, g.ram[0x3A + x], 0);     /* L5F84/5: CLC ("MAY NOT BE NEEDED") */
    g.ram[0x3A + x] = r.r;                  /* L5F87: score byte 0 (tens)   */
    c = r.c;
    if (!c)
        goto aps_60;                        /* L5F89 BCC: no extra 1000     */

    /* LDA #$00 / ADC: the ROM cannot INC in decimal mode, so it adds 0+C. */
    r = bcd_adc(0x00, g.ram[0x003B + x], c);  /* L5F8B-8D: score byte 1   */
    g.ram[0x003B + x] = r.r;              /* L5F8F                        */
    TEMP9 = r.r;                             /* L5F91: saved for the bonus compare */
    r = bcd_adc(0x00, g.ram[0x003C + x], r.c);  /* L5F93-95: score byte 2   */
    g.ram[0x003C + x] = r.r;                /* L5F97                        */

    if (TOGCOMB & 0x80)                      /* L5F99/9B BIT/BMI: was combined */
        goto aps_65;
    if (BONLVA == 0)                          /* L5F9D/9F: bonus allowed?     */
        goto aps_90;
    x = OWNER;                              /* L5FA1                        */
    a = g.ram[A_NXTBON + x];                 /* L5FA4: this player's next bonus */
    if (a != TEMP9)                          /* L5FA6/A8: cannot pass on one hit */
        goto aps_90;
    r = bcd_adc(a, BONLVA, 0);                /* L5FAA/AB: step to next level */
    g.ram[A_NXTBON + x] = r.r;               /* L5FAD                        */
    g.ram[A_PL0SCFLAG + x] = 0xBF;          /* L5FAF-B1: redraw lives+score */
    if (g.ram[0x47 + x] < 0x0A)             /* L5FB4-B8: limit lives        */
        g.ram[0x47 + x]++;                  /* L5FBA: one more life         */
    goto aps_80;                            /* L5FBC BNE _80 (always)       */

aps_60:                                     /* AddPointsToScore_60 ($5FBE)  */
    if (!(TOGCOMB & 0x80))                   /* L5FBE/C0 BPL: not combined   */
        goto aps_90;
    /* falls into _65 */

aps_65:                                     /* AddPointsToScore_65 ($5FC2)  */
    CMBSCFLAG--;                            /* L5FC2: tell the IRQ it changed */
    r = bcd_adc(TEMPA, g.ram[0x40], 0);     /* L5FC5-C8: combined byte 0    */
    g.ram[0x40] = r.r;                      /* L5FCA CMBSCORE = slot 6 + 0   */
    if (!r.c)                               /* L5FCC BCC _90                */
        goto aps_90;
    r = bcd_adc(0x00, g.ram[0x41], r.c);    /* L5FCE-D0: combined byte 1    */
    g.ram[0x41] = r.r;                      /* L5FD2 CMBSCORE+1 = slot 6 + 1 */
    r = bcd_adc(0x00, g.ram[0x42], r.c);    /* L5FD4-D6: combined byte 2    */
    g.ram[0x42] = r.r;                      /* L5FD8                        */
    if (BONLVA == 0)                          /* L5FDA/DC: no bonus allowed   */
        goto aps_90;
    a = NXTBON;                              /* L5FDE: player 0's is used for combined */
    if (a != g.ram[0x41])                   /* L5FE0/E2: achieved?          */
        goto aps_90;
    r = bcd_adc(a, BONLVA, 0);                /* L5FE4/E5: step to next level */
    NXTBON = r.r;                            /* L5FE7                        */
    if (g.ram[0x47] < 0x0A) {               /* L5FE9-ED: limit lives        */
        g.ram[0x47]++;                      /* L5FEF: give new lives        */
        g.ram[0x48]++;                      /* L5FF1: both players share    */
    }
    /* AddPointsToScore_75 ($5FF3) */
    CMBSCFLAG = 0xBF;                       /* L5FF3-F5: change lives and score */

aps_80:                                     /* AddPointsToScore_80 ($5FF8)  */
    /* L5FF8 CLD, then L5FF9 JMP ExtraLife2 - a tail call, so the sound
     * routine's RTS is this routine's.  X here is OWNER on the per-player
     * path and the score slot (0/3) on the combined path; Badhab parks it
     * in TEMPA (overwriting the point value staged above) and parks the
     * caller's Y in TEMPB.  Y is unknowable from this signature - see
     * NOTES_score.md open question 1a, the same issue NOTES_objects.md q3
     * and NOTES_soundcoins.md q1 already track - so 0 is passed, as at
     * every other cross-module sound trigger in the port. */
    extra_life2(x, 0x00);                   /* L5FF9: EXTRA LIFE SOUND      */
    return;

aps_90:                                     /* AddPointsToScore_90 ($5FFC)  */
    return;                                 /* L5FFC CLD, L5FFD _95 RTS     */
}

/* ------------------------------------------------------------------ */
/* UpdateHighScoreTable ($6614)                                        */
/* ------------------------------------------------------------------ */

/* JmpUpda20/UpdateUpdateHighScore ($6644-$6729): scan the current game
 * type's slice of the high-score table for an entry the live score beats;
 * if found, shift every lower entry down one slot, insert the new score,
 * flag initials entry, and clear the field (JMP Bigbang - modelled as a
 * plain call since nothing else runs between it and the eventual RTS in
 * either the ROM or this translation).
 *
 * In: x = live-score slot (3 = left/2P-fighter score, 0 = right/1P score
 *     or the game1/game3 solo path, 6 = the combined game2 path);
 *     TEMP4 ($10, already set by the caller: 1 for the game0-left call,
 *     0 otherwise) selects which of ZP_38/ZP_39 (initials-entry flag per
 *     player) receives the hit; SPFLG ($3EA, already set by the caller:
 *     $00 only for game type 2) gates the "special" second initials
 *     array and the extra $39-adjustment tail.
 * The live score being compared is SCORE itself: $3A,x / $3B,x / $3C,x,
 * the 3-byte score staged by the caller before UpdateHighScoreTable runs.
 * Likewise $DA/$DB/$DC are HSCORE minus 3 - the source slot of the
 * shift-down copy - not variables in their own right. (Both read as
 * mysteries until the RAM map was corrected; see NOTES_score.md.) */
static void jmp_upda20(uint8_t x)
{
    uint8_t game = ZP_34;
    uint8_t y;
    uint8_t idx;

    TEMP5 = FIFTH_VALUE_UPDATE_CHECK(game + 1);  /* L6646-9: end boundary  */
    y = FIFTH_VALUE_UPDATE_CHECK(game);          /* L664B-E: start offset */

    for (;;) {
        /* L664F-L665E: 24-bit unsigned magnitude compare (no SED here -
         * CMP/SBC are pure binary), table entry (LSB $DD,y .. MSB $DF,y)
         * vs the live score (LSB $3A,x .. MSB $003C+x); only the final
         * carry is ever tested (no N/Z/V use afterward), so this is
         * behaviourally identical to a widened compare. */
        uint32_t table = ((uint32_t)g.ram[0xDF + y] << 16)
                        | ((uint32_t)g.ram[0xDE + y] << 8)
                        |  (uint32_t)g.ram[0xDD + y];
        uint32_t score = ((uint32_t)g.ram[0x003C + x] << 16)
                        | ((uint32_t)g.ram[0x003B + x] << 8)
                        |  (uint32_t)g.ram[0x3A + x];
        if (table < score)
            break;                        /* L665E BCC: NEW HIGH GENDING    */
        y = (uint8_t)(y + 3);             /* L6660-2 INY x3               */
        if (y >= TEMP5)                   /* L6663/5 CPY TEMP5/BCC        */
            return;                       /* L6667 RTS: past end, no hit  */
    }

    /* UpdateUpdateHighScore_30 ($6668): found a new high score at slot y. */
    TEMP2 = x;                           /* L6668                        */
    POTGO = y;                            /* L666A                        */
    g.ram[0x38 + TEMP4] = y;              /* L666C-6F: ZP_38/ZP_39 (TYA/STA $38,X) */
    g.ram[A_FLSFLG + TEMP4] = y;          /* L6671                        */
    if (!(SPFLG & 0x80))                  /* L6674/7 BIT/BMI: special?    */
        ZP_39 = y;                        /* L6679: mark "do both"        */

    /* UpdateUpdateHighScore_35/_40/_44 ($667B-$66C7): shift every lower
     * entry down one slot from Hscend[game] to y (== POTGO). The search
     * loop above guarantees idx always lands exactly on y (both are
     * always multiples of 3 within the same game slice), so the ROM's
     * two loop-exit tests (CPX POTGO at the top, BNE idx!=0 at the
     * bottom) collapse into the single top-tested loop below. */
    idx = HSCEND(game);                   /* L667D-81                     */
    while (idx != y) {
        g.ram[0x119 + idx]     = g.ram[0x116 + idx];     /* L6686-9       */
        g.ram[0x119 + idx + 1] = g.ram[0x117 + idx];     /* L668C-F       */
        g.ram[0x119 + idx + 2] = g.ram[0x118 + idx];     /* L6692-5       */
        g.ram[0xDD + idx] = g.ram[0xDA + idx];  /* L6698-B: HSCORE-3 -> HSCORE */
        g.ram[0xDE + idx] = g.ram[0xDB + idx];  /* L669E-A1: HSCORE+1-3      */
        g.ram[0xDF + idx] = g.ram[0xDC + idx];  /* L66A4-7: HSCORE+2-3       */
        if (!(SPFLG & 0x80)) {                  /* L66AA/D: special?     */
            g.ram[0x137 + idx]     = g.ram[0x134 + idx]; /* L66AF-B2      */
            g.ram[0x138 + idx] = g.ram[0x135 + idx];     /* L66B5-8       */
            g.ram[0x139 + idx] = g.ram[0x136 + idx];     /* L66BB-E       */
        }
        idx = (uint8_t)(idx - 3);         /* L66C1-6                      */
    }

    /* UpdateUpdateHighScore_45 ($66C9): seed the new top-of-slot initials. */
    g.ram[0x119 + idx] = 0x0B;            /* L66C9-B: start letters at 'A'*/
    g.ram[0x11A + idx] = 0x00;            /* L66CE-D0                     */
    g.ram[0x11B + idx] = 0x00;            /* L66D3                        */
    if (!(SPFLG & 0x80)) {                /* L66D6/9                      */
        g.ram[0x138 + idx] = 0x00;        /* L66DB                        */
        g.ram[0x139 + idx] = 0x00;        /* L66DE                        */
        g.ram[0x137 + idx] = 0x0B;        /* L66E1-3                      */
    }

    /* UpdateUpdateHighScore_46 ($66E6): 1-minute initials-entry timeout,
     * then move the live score into its new table slot. */
    ZP_45 = 0xED;                          /* L66E6-8                      */
    g.ram[0xDF + POTGO] = g.ram[0x003C + TEMP2];    /* L66EA-F0          */
    g.ram[0xDE + POTGO] = g.ram[0x003B + TEMP2];  /* L66F3-5           */
    g.ram[0xDD + POTGO] = g.ram[0x3A + TEMP2];      /* L66F8-A           */

    /* UpdateUpdateHighScore_28/_29 ($66FD): player-2 cancellation, only
     * for the non-special (TEMP4==0, SPFLG==$FF) case. */
    if (TEMP4 == 0 && (SPFLG & 0x80) && !(ZP_39 & 0x80) && ZP_39 >= ZP_38) {
        uint8_t a2 = (uint8_t)(ZP_39 + 3);   /* L670E: ADC #$02, C=1 here */
        if (a2 >= TEMP5)                      /* L6710/2                  */
            a2 = 0xFF;                        /* L6714                    */
        ZP_39 = a2;                           /* L6716                    */
        g.ram[A_FLSFLG + 1] = a2;             /* L6718: $03EC = FLSFLG+1  */
    }

    /* UpdateUpdateHighScore_29 ($671B): shared tail. */
    g.ram[0x36] = 0x00;                   /* L671B-D: first-initial index */
    g.ram[0x37] = 0x00;                   /* L671F: (unnamed, per-player) */
    HSCFLG = 0xFF;                        /* L6721-3                      */
    SPECEX = 0xFF;                        /* L6726                        */
    bigbang();                            /* L6729: JMP Bigbang           */
}

/* UpdateHighScoreTable ($6614): game-end high-score check. No arguments;
 * call site: mainline.c chkst1() ($439A), right after update_info_at_end().
 * Dispatches to jmp_upda20() once (games 1/2/3) or twice (game 0: left
 * player then right player - the ROM's JSR-then-fallthrough and its
 * JMP-tail-call both just resume normal execution afterward, which a
 * plain sequential call/call reproduces exactly). */
void update_high_score_table(void)
{
    uint8_t game;

    ZP_45 = 0xFF;                         /* L6614-6: put up high score table next */
    ZP_38 = 0xFF;                         /* L6618                        */
    ZP_39 = 0xFF;                         /* L661A: clear flags           */
    SPFLG = 0xFF;                         /* L661C: guess no special      */
    game = ZP_34;                         /* L661F                        */

    if (game == 0) {
        TEMP4 = 1;                        /* L6623-5                      */
        jmp_upda20(3);                    /* L6627-9: left player's score */
        TEMP4 = 0;                        /* L662C-E                      */
        jmp_upda20(0);                    /* L6630: right player's score  */
        return;
    }
    if (game == 1) {
        TEMP4 = 0;                        /* L662C-E (via _30 -> _20)     */
        jmp_upda20(0);
        return;
    }
    if (game == 2)
        SPFLG = 0x00;                     /* L6639-B: special case        */
    TEMP4 = 0;                            /* L663E/40                     */
    jmp_upda20(6);                        /* L6642-4: combined score      */
}

/* ------------------------------------------------------------------ */
/* HexBcdConversionInput ($8C62)                                       */
/* ------------------------------------------------------------------ */

/* Binary -> BCD "double dabble" conversion (8 shift-and-decimal-double
 * steps). In: a = binary value. Out: TEMP7 = low 2 BCD digits, g.ram[0x16]
 * = BCD hundreds digit (unnamed scratch, always 0 for the credit counts
 * this is actually used on); TEMP9 is clobbered (shift register). Call
 * sites: Display4Names $766F (below), self-test $8BA6 (not yet
 * translated - that module should extern this rather than duplicate it). */
void hex_bcd_conversion_input(uint8_t a)
{
    int i;
    uint8_t hi = 0;                       /* $16: BCD hundreds scratch    */

    TEMP9 = a;                             /* L8C62: shift register        */
    TEMP7 = 0;                             /* L8C66-8                      */
    /* SED (L8C6C): decimal mode for the 8 double-and-add steps. */
    for (i = 0; i < 8; i++) {             /* L8C64: LDY #$07 .. DEY/BPL   */
        int carry = (TEMP9 & 0x80) != 0;   /* L8C6D: ASL TEMP9, carry out   */
        bcd_res r;
        TEMP9 = (uint8_t)(TEMP9 << 1);
        r = bcd_adc(TEMP7, TEMP7, carry);   /* L8C6F-73                     */
        TEMP7 = r.r;
        r = bcd_adc(hi, hi, r.c);         /* L8C75-79                     */
        hi = r.r;
    }                                      /* L8C7E: CLD                   */
    g.ram[0x16] = hi;
}

/* ------------------------------------------------------------------ */
/* Display4Names ($7529, module A2NAME)                                */
/* ------------------------------------------------------------------ */

/* Display4Names ($7529): the game-select screen - draws the box, picture,
 * flashing selection box, and status message for each of up to 4 games
 * (2 for a caberet cabinet), then falls into the anonymous credit-display
 * tail at $765D (reached only from here - kept inline, not a function).
 * No arguments (LDY #$03 on entry - any caller-computed Y is dead, see
 * mainline.c's call-site comment). */
void display_4_names(void)
{
    uint8_t x, y, a, cab;

    TEMP9 = 3;                             /* L7529-B: display 4 names     */
    set_vg_status(0xC1);                  /* L752D-F: boxes are blue      */
    cab = sd_hw_in1(7);                   /* L7532: BIT CABERE            */
    if (cab & 0x40) { a = 0x14; x = 0xA8; }               /* L7535-3B     */
    else             { a = 0x00; x = 0xA8; }              /* L753E-40     */
    vg_add2(a, x);                        /* L7542                        */

    for (;;) {
        /* Display4Names_10 ($7545) */
        y = TEMP9;
        x = score_rom_761E[(0x761E + y) - 0x761E];   /* _100: position    */
        a = score_rom_761E[(0x7622 + y) - 0x761E];   /* _110               */
        cab = sd_hw_in1(7);                          /* L754D BIT CABERE  */
        if (cab & 0x40)
            a = score_rom_761E[(0x763A + y) - 0x761E]; /* _170: caberet X (always 0) */
        mesgpos(a, x);                                /* L7555             */

        y = TEMP9;                                     /* L7558 (reload)    */
        x = score_rom_761E[(0x764E + y) - 0x761E];    /* Creddis+1,Y       */
        a = score_rom_761E[(0x7652 + y) - 0x761E];    /* Creddis+5,Y       */
        vg_add2(a, x);                                 /* L7560: pic JSRL   */

        if (DIAGBI != 0 && !(ZSAUCE & 0x80) && !(STRTLOK & 0x80)) {
            y = FLASHCOL;                              /* L7570             */
            set_vg_status(y);                          /* L7573: flash color*/
            y = ZP_34;                                  /* L7576             */
            x = score_rom_761E[(0x762E + y) - 0x761E]; /* _140              */
            a = score_rom_761E[(0x7632 + y) - 0x761E]; /* _150              */
            cab = sd_hw_in1(7);                         /* L757E             */
            if (cab & 0x40)
                a = score_rom_761E[(0x763E + y) - 0x761E]; /* _180          */
            mesgpos(a, x);                               /* L7586             */
            a = (uint8_t)(ZP_44 & 0x1C);                 /* L7589-B           */
            if (a < 0x10) {                              /* L758D/F: off time?*/
                y = (uint8_t)(a >> 2);                   /* L7591-3           */
                x = score_rom_761E[(0x7646 + y) - 0x761E]; /* Picadh (y==3 -> Mesg2[0], both $A8) */
                a = score_rom_761E[(0x764A + y) - 0x761E]; /* Mesg2+1,Y      */
                vg_add2(a, x);                              /* L759A: box pic */
            }
        }

        /* Display4Names_14 ($759D) */
        y = TEMP9;
        x = score_rom_761E[(0x7626 + y) - 0x761E];   /* _120               */
        a = score_rom_761E[(0x762A + y) - 0x761E];   /* _130               */
        cab = sd_hw_in1(7);
        if (cab & 0x40)
            a = score_rom_761E[(0x7642 + y) - 0x761E]; /* _185             */
        mesgpos(a, x);                                 /* L75AD             */
        aux_routine_add_offset(6);                     /* L75B0-2           */

        x = 0;                                          /* L75B5: guess push start */
        y = 0xC7;                                        /* L75B7             */
        if (DIAGBI != 0) {                                /* L75B9/BB           */
            if (ZSAUCE & 0x80)                            /* L75C1/3           */
                goto d4n_17;
            if (!(STRTLOK & 0x80) && TEMP9 == ZP_34)       /* L75C5/8, CA/CE    */
                goto d4n_30;
            /* Display4Names_12 ($75D0): falls through here */
            x = 1;                                        /* L75D0             */
            y = 0xE5;                                      /* L75D1             */
            if (!(ZP_44 & 0x08))                            /* L75D3/5/7         */
                y = 0xE3;                                   /* L75D9             */
            /* Display4Names_15 ($75DB) */
            if (TEMP5 & 0x80)                               /* L75DB/D           */
                goto d4n_30;
            if (DIAGBI >= 2)                                 /* L75DF-E3          */
                goto d4n_30;
            if (TEMP9 & 0x01)                                /* L75E5-8: odd = 1-player */
                goto d4n_30;
            x = 2;                                          /* L75EA             */
            goto d4n_16;
        }
    d4n_17:                                                 /* Display4Names_17 ($75BD) */
        x = 2;
    d4n_16:                                                 /* Display4Names_16 ($75EB) */
        y = 0xE6;
        if (!(ZP_44 & 0x04))                                /* L75ED-F1          */
            y = 0xE4;
    d4n_30:                                                 /* Display4Names_30 ($75F5) */
        a = y;                                              /* L75F5 TYA         */
        y = score_rom_761E[(0x7656 + x) - 0x761E];         /* Creddis+9,X: message # */
        pass_color(a, y);                                   /* L75F9             */
        x = 0x20;                                            /* L75FC             */
        y = g.ram[0xD1];                                     /* L75FE: language ($D1, unnamed) */
        a = score_rom_761E[(0x7636 + y) - 0x761E];          /* _160: language correction */
        vg_vctr_dark(a, x);                                  /* L7603             */
        x = TEMP9;                                            /* L7606             */
        y = score_rom_761E[(0x7659 + x) - 0x761E];          /* Creddis+12,X       */
        vector_message5(y);                                  /* L760B             */

        y = TEMP9;                                            /* L760E             */
        cab = sd_hw_in1(7);                                  /* L7610             */
        if (cab & 0x40)
            y--;                                              /* L7615: down by 2 (extra) */
        y--;                                                  /* L7616: down by 2 (always)*/
        TEMP9 = y;                                             /* L7617             */
        if (y & 0x80)                                          /* L7619: done?      */
            break;
        /* L761B: JMP Display4Names_10 - continue the for(;;) loop */
    }

    /* anonymous credit-display tail ($765D), entered only from above -
     * kept inline (CONVENTIONS rule 1: not a separate function). */
    mesgpos(0xE4, 0x40);                   /* L765D-61                     */
    pass_color(0xE3, 0x18);                /* L7664-8                      */
    if (DIAGBI != 0) {                      /* L766B/D                      */
        int carry;
        hex_bcd_conversion_input(DIAGBI);    /* L766F                        */
        carry = display_digit_with_zero((uint8_t)(TEMP7 >> 4), 1); /* L7672-9 */
        (void)display_digit_with_zero(TEMP7, carry);              /* L767C-E */
    }
    if ((g.ram[0x0026]) != 0)                         /* L7681/3: any half-credit?    */
        vg_add2(0x6D, 0xA9);                /* L7685-9: put out half        */
}
