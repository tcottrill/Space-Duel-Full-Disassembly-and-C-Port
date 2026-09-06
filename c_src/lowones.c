/* lowones.c - Space Duel C port: per-frame "low ones" service + trig
 * (module AST2RT: math pack $67D0-$68C9, star service $6EE5-$703B).
 *
 * The star service rotates/recolors the eight persistent picture stubs in
 * vector RAM (VROCK1-8 at $2290-$22C3, SAU11-13 at $22C4-$22CF) that the
 * per-frame display lists JSRL into: it clobbers the VG list pointer
 * VGLIST/EAC2 ($01/$02), pointing it at each stub, exactly as the ROM does
 * (the mainline rebuilds the pointer afterwards).
 *
 * The math pack is the sin/cos + multiply kernel everything downstream
 * (thrust, torpedoes, sparks, the tug-of-war bar) depends on; register
 * protocols are derived from all call sites and documented per function.
 */
#include "sd_state.h"
#include "vgutil.h"
#include "lowones.h"

/* ================================================================== */
/* math pack                                                           */
/* ================================================================== */

/* Comp ($684D): A -> -A (two's complement: EOR #$FF / CLC / ADC #$01).
 * In: A. Out: A (callers also branch on the result's N flag).
 * Comp1 ($6852) is the bare RTS this falls through to - no C function. */
uint8_t comp(uint8_t a)
{
    return (uint8_t)((a ^ 0xFF) + 1);
}

/* EntryInputExitAbsolute ($684B): A -> |A| (BPL Comp1, else negate).
 * In: A signed. Out: A = absolute value ($80 stays $80: -(-128) wraps). */
uint8_t entry_input_exit_absolute(uint8_t a)
{
    if (!(a & 0x80)) return a;          /* L684B BPL Comp1 (RTS) */
    return comp(a);
}

/* Sin1 ($683E): quarter/half-wave sine lookup. In: A = angle, MUST be
 * $00-$7F (only PiAngle0 calls it; 256 angle units per full circle).
 * Out: A = sin(angle) scaled to $00-$7F. Clobbers X in the ROM (TAX for
 * the table index) - callers reload X ("SIN USES X", $49E4). */
uint8_t sin1(uint8_t a)
{
    if (a >= 0x41) {                    /* L683E CMP #$41 / BCC        */
        /* SIN(PI/2+A) = SIN(PI/2-A): EOR #$7F / ADC #$00 with C set   */
        a = (uint8_t)((a ^ 0x7F) + 1);  /* = $80 - a, lands in $01-$3F */
    }
    return lowones_sin07[a];            /* Sin1_10: TAX / LDA Sin07,X  */
}

/* PiAngle0 ($6834): full-circle sine. In: A = angle ($00-$FF = 0..2*PI).
 * Out: A = sin(angle), signed, -$7F..+$7F. Clobbers X (via Sin1). */
uint8_t pi_angle0(uint8_t a)
{
    if (a & 0x80) {                     /* L6834 BPL Sin1              */
        /* SIN(PI+A) = -SIN(A) */
        return comp(sin1((uint8_t)(a & 0x7F)));
    }
    return sin1(a);
}

/* CosSinPi2 ($6831): full-circle cosine, COS(A) = SIN(A + PI/2).
 * In: A = angle. Out: A = cos(angle), signed. Clobbers X (via Sin1). */
uint8_t cos_sin_pi2(uint8_t a)
{
    return pi_angle0((uint8_t)(a + 0x40));   /* CLC / ADC #$40 */
}

/* OutputTemp2Temp21 ($686D): 8x8 multiply, A signed x TEMP1 ($07)
 * UNsigned, through the 256-byte nibble-product table at $6D5C.
 * In:  A = signed multiplicand, TEMP1 = unsigned multiplier.
 * Out: A = POTGO ($0B) = high byte of the signed 16-bit product
 *      (i.e. A * TEMP1 / 256); TEMP2 ($0A) = product low byte.
 * RAM: TEMP4 ($10) clobbered (holds A, then the cross-term sum >> 4);
 *      TEMP2/POTGO hold intermediate nibble products before the final
 *      bytes. TEMP1 preserved. X/Y clobbered in the ROM.
 * The entry sign flag is saved (TAX/PHP) and, restored at the end, selects
 * the signed fixup high -= TEMP1 (A treated as A-256 when negative).
 * L_90_68C7 ($68C7) is the shared store-and-return tail (no outside
 * callers - folded into the function). */
uint8_t output_temp2_temp21(uint8_t a)
{
    unsigned s;
    uint8_t x, y;
    int n_in = (a & 0x80) != 0;         /* L686E PHP: N flag of entry A */

    TEMP4 = a;                          /* L686F STA TEMP4              */
    /* index (TEMP1 & $F0) | (A >> 4): LSR x4, EOR/AND #$0F/EOR merge   */
    x = (uint8_t)((((a >> 4) ^ TEMP1) & 0x0F) ^ TEMP1);
    POTGO = lowones_nibmul[x];          /* L687F: Ahi * Whi             */
    /* index ((A & $0F) << 4) | (TEMP1 & $0F): ASL x4, EOR/AND #$F0/EOR */
    x = (uint8_t)(((uint8_t)((uint8_t)(TEMP4 << 4) ^ TEMP1) & 0xF0) ^ TEMP1);
    TEMP2 = lowones_nibmul[x];         /* L6891: Alo * Wlo             */
    /* index (TEMP1 & $F0) | (A & $0F) -> Whi * Alo (Y register)        */
    y = (uint8_t)(((TEMP4 ^ TEMP1) & 0x0F) ^ TEMP1);
    /* index ((A & $F0)) | (TEMP1 & $0F) -> Ahi * Wlo                   */
    x = (uint8_t)(((TEMP4 ^ TEMP1) & 0xF0) ^ TEMP1);
    /* cross-term sum, 9 bits (ADC carry recovered by the ROR at $68AD) */
    s = (unsigned)lowones_nibmul[x] + (unsigned)lowones_nibmul[y];
    x = (uint8_t)s;                     /* L68AC TAX (low 8 bits)       */
    TEMP4 = (uint8_t)(s >> 4);          /* ROR/LSR/LSR/LSR -> STA TEMP4 */
    /* low byte: (cross & $0F) << 4 + Alo*Wlo, carry into the high byte */
    s = (unsigned)((uint8_t)(x << 4)) + (unsigned)TEMP2;
    TEMP2 = (uint8_t)s;                /* L68BB: product low byte      */
    a = (uint8_t)(POTGO + TEMP4 + (uint8_t)(s >> 8));
    if (n_in)                           /* L68C1 PLP / BPL L_90_68C7    */
        a = (uint8_t)(a - TEMP1);       /* SEC / SBC TEMP1: sign fixup  */
    POTGO = a;                          /* L_90_68C7: STA POTGO         */
    return a;
}

/* SignedBySignedMult ($6853): A signed x TEMP1 signed -> high byte.
 * In:  A, TEMP1 both signed. Out: as OutputTemp2Temp21.
 * Side effect kept from the ROM: when TEMP1 is negative it is REWRITTEN
 * as |TEMP1| (clamped $80 -> $7F), and A is negated (clamped -128 -> $7F)
 * before the unsigned-multiplier core runs. */
uint8_t signed_by_signed_mult(uint8_t a)
{
    if (TEMP1 & 0x80) {                 /* L6853 BIT TEMP1 / BPL       */
        uint8_t w = comp(TEMP1);
        if (w & 0x80) w = 0x7F;         /* L685D BPL / LDA #$7F        */
        TEMP1 = w;                      /* L6861 STA TEMP1             */
        a = comp(a);
        if (a == 0x80) a = 0x7F;        /* L6867 CMP #$80 / BNE        */
    }
    return output_temp2_temp21(a);
}

/* ================================================================== */
/* signed arctangent ($67D0-$6830)                                     */
/* ================================================================== */
/* Sits just BELOW the sine/multiply pack in the ROM, but is the same
 * math pack and its only external entry is PartSignedNumberExit, so it
 * lives here.  It is written after comp() because every stage of the
 * sign folding is a `JSR Comp` / `JMP Comp`.                          */

/* Temp21DivisorUnsigned ($681F): the 4-bit restoring divide the arctangent
 * runs on.  A = dividend, POTGO ($0B) = divisor, entry CARRY matters (it
 * is rolled into TEMP2 by the first iteration).  Out: A = TEMP2's four
 * quotient bits shifted up one, so the caller's AND #$0F recovers them.
 *
 * TEMP2 ($0A) is the quotient register and the ROM never clears it: each
 * `ROL TEMP2` shifts TEMP2's old bit 7 out through the carry and into
 * the dividend's low bit, so the effective dividend is
 * (A << 4) | (old TEMP2 >> 4) - the divide's low-order noise really is
 * the previous contents of TEMP2.  That is reproduced, not smoothed
 * over, and TEMP2's shifted value is left in RAM exactly as the ROM
 * leaves it (the oracle diffs it).  Divi20 ($6821) / Divi20_20 ($682A)
 * are this loop's local labels. */
static uint8_t temp21_divisor_unsigned(uint8_t a, int c)
{
    uint8_t y;
    int nc;

    for (y = 0x04; y != 0; y--) {       /* L681F LDY #$04 / Divi20     */
        nc = (TEMP2 >> 7) & 1;         /* L6821 ROL TEMP2            */
        TEMP2 = (uint8_t)((TEMP2 << 1) | (c & 1));
        c = nc;
        nc = (a >> 7) & 1;              /* L6823 ROL (A)               */
        a = (uint8_t)((a << 1) | (c & 1));
        c = nc;
        c = (a >= POTGO);               /* L6824 CMP POTGO             */
        if (c)                          /* L6826 BCC Divi20_20         */
            a = (uint8_t)(a - POTGO);   /* L6828 SBC: leaves C set     */
    }                                   /* L682A DEY / BNE Divi20      */
    /* L682D LDA TEMP2 / L682F ROL: shift in the last quotient bit. */
    return (uint8_t)((TEMP2 << 1) | (c & 1));
}

/* L4BitDivide ($6805): divide, keep 4 bits, look the angle up.
 * In: A = dividend (< POTGO), POTGO = divisor, carry as above.
 * Out: A = arctan(A/POTGO) in $00-$1F (0-45 degrees).  Clobbers X. */
static uint8_t l4_bit_divide(uint8_t a, int c)
{
    a = temp21_divisor_unsigned(a, c);
    a &= 0x0F;                          /* L6808 AND #$0F              */
    return lowones_atan16[a];           /* L680A TAX / LDA L03,X       */
}

/* Divisor2 ($67EB): arctangent of two NON-NEGATIVE values, folded into
 * the first 45-degree octant.  In: A = |x| (denominator), y = |y|
 * (numerator).  Out: A = angle $00-$40 (0-90 degrees).
 * RAM: POTGO ($0B) = the divisor, TEMP2 ($0A) as above.
 * Divisor2_10 ($6802) is the y == x case: exactly 45 degrees ($20). */
static uint8_t divisor2(uint8_t a, uint8_t y)
{
    int c;

    POTGO = a;                          /* L67EB STA POTGO: divisor    */
    a = y;                              /* L67ED TYA: dividend         */
    c = (a >= POTGO);                   /* L67EE CMP POTGO             */
    if (a == POTGO)
        return 0x20;                    /* L67F0 BEQ Divisor2_10       */
    if (!c)
        return l4_bit_divide(a, 0);     /* L67F2 BCC: y < x, C clear   */
    /* L67F4-L67F8: y > x, so swap and use the complementary octant. */
    y = POTGO;                          /* LDY POTGO ( = |x| )         */
    POTGO = a;                          /* STA POTGO ( = |y| )         */
    a = y;                              /* TYA                         */
    a = l4_bit_divide(a, 1);            /* L67F9 JSR, C set by the CMP */
    a = (uint8_t)(a - 0x40);            /* L67FC SEC / SBC #$40        */
    return comp(a);                     /* L67FF: $40 - arctan(x/y)    */
}

/* Divisor ($67DC): fold the sign of the DENOMINATOR.
 * In: A = |numerator|, x = the signed denominator.  Out: A = angle. */
static uint8_t divisor(uint8_t a, uint8_t x)
{
    uint8_t y = a;                      /* L67DC TAY: the dividend     */
    a = x;                              /* L67DD TXA                   */
    if (!(a & 0x80))                    /* L67DE BPL Divisor2          */
        return divisor2(a, y);
    a = comp(a);                        /* L67E0 JSR Comp: x = -x      */
    a = divisor2(a, y);                 /* L67E3 arctan(y/-x)          */
    a ^= 0x80;                          /* L67E6 EOR #$80              */
    return comp(a);                     /* L67E8: $80 - arctan(y/-x)   */
}

/* PartSignedNumberExit ($67D0): the game's signed arctangent - the routine
 * every enemy aims with.
 *   in   x = the X (denominator) difference, signed
 *        y = the Y (numerator)   difference, signed
 *   out  A = atan2(y, x) as an ANGLE, 256 units per full circle, the same
 *        units PiAngle0/CosSinPi2 take ($40 = 90 degrees, CCW from +X).
 *   clobbers X and Y (l4_bit_divide's TAX, divisor's TAY); writes POTGO
 *        ($0B) and TEMP2 ($0A).
 * Call sites, all three agreeing on that protocol:
 *   $48B9 CollisionBounce_80 - LDX XINC,Y / LDA YINC,Y / TAY / JSR, then
 *         LDX TEMP5 / LDY FOURPI to restore its own registers;
 *   $4931 NumeratorAtan     - TAY (the Y difference) / PLA / TAX (the X
 *         difference) / JMP: a tail call, so A is the caller's result;
 *   $4C26 Efire3            - TAY / PLA / TAX / JSR, then LDX TEMP3 /
 *         STA ANGLE,X.
 * Sign folding, in the ROM's own words: arctan(y/x) = -arctan(-y/x) for
 * y < 0, = $80 - arctan(y/-x) for x < 0, = $40 - arctan(x/y) for y > x.
 * DEGENERATE CASE: x == y == 0 returns $20 (45 degrees) - the BEQ at
 * $67F0 fires before anything looks at the magnitudes.  That is the ROM's
 * answer for "no difference at all", not an error, and it is reproduced. */
uint8_t part_signed_number_exit(uint8_t x, uint8_t y)
{
    uint8_t a = y;                      /* L67D0 TYA                   */
    if (!(a & 0x80))                    /* L67D1 BPL Divisor           */
        return divisor(a, x);
    a = comp(a);                        /* L67D3 JSR Comp: +y = -y     */
    a = divisor(a, x);                  /* L67D6 arctan(-y/x)          */
    return comp(a);                     /* L67D9: -arctan(-y/x)        */
}

/* ================================================================== */
/* per-frame star/saucer picture service                               */
/* ================================================================== */

/* SaveLater ($7017): stash the star loop index for the star-stub loops.
 * In:  X = star index 0-3.
 * Out: TEMP2 ($0A) = X saved; TEMP3 ($0C) = X*2 (word offset into the
 *      RSOURC/dest tables); returns Y (= A = X*2). */
uint8_t save_later(uint8_t x)
{
    uint8_t a;
    TEMP2 = x;                         /* L7017 STX TEMP2            */
    a = (uint8_t)(x << 1);              /* TXA / ASL                   */
    TEMP3 = a;                          /* L701B STA TEMP3             */
    return a;                           /* TAY                         */
}

/* GetRotationColorCode ($701F): copy one star picture's 2-byte AVG JMPL
 * word from RSOURC ($6E8D) into the star's vgram stub.
 * In:  X = rotation counter index 0-3 (ASTERS..ASTERS+3, $3D6-$3D9);
 *      TEMP3 = slot offset (star*2, +8 for the top pictures);
 *      VGLIST/EAC2 ($01/$02) -> destination stub in vector RAM.
 * Out: returns Y = 2 (list offset past the word; the caller keeps
 *      writing at (VGLIST),Y from there). A/X clobbered.
 * GetRotationColorCode_11 ($702B) is a local label (no outside refs). */
uint8_t get_rotation_color_code(uint8_t x)
{
    uint8_t a, y;
    /* code = (ASTERS,X & 3) << 4: 2 words/pic x 8 slots per code row */
    a = (uint8_t)((g.ram[A_ASTERS + x] & 0x03) << 4);  /* L701F-L7027 */
    a = (uint8_t)(a + TEMP3);           /* L7028 CLC / ADC TEMP3       */
    x = a;                              /* GetRotationColorCode_11 TAX */
    y = 0;                              /* L702C LDY #$00              */
    vg_poke_list(y, lowones_rsourc[x]); /* LSB: STA (VGLIST),Y           */
    y++; x++;
    vg_poke_list(y, lowones_rsourc[x]); /* MSB                         */
    y++;
    return y;                           /* = 2                         */
}

/* MoveSaucerPicColor ($6F92): every 4th frame bump SAUCIX ($3ED); every
 * 16th frame rotate the three saucer COLOR-word bytes SAU11/SAU12/SAU13
 * (vector RAM $22C4/$22C8/$22CC) one step. No inputs/outputs. */
void move_saucer_pic_color(void)
{
    uint8_t a, x, y;
    if ((ZP_44 & 0x03) != 0)            /* L6F92-L6F96 (BEQ .. RTS)    */
        return;
    SAUCIX++;                           /* L6F99 INC SAUCIX            */
    a = (uint8_t)(SAUCIX & 0x03);
    SAUCIX = a;                         /* L6FA1 STA SAUCIX            */
    if (a != 0)
        return;                         /* BNE MoveSaucerPicColor_5    */
    a = VRAM(A_SAU11);                  /* L6FA6                       */
    x = VRAM(A_SAU12);
    y = VRAM(A_SAU13);                  /* move color                  */
    VRAM(A_SAU13) = a;
    VRAM(A_SAU11) = x;
    VRAM(A_SAU12) = y;
}

/* Toppic ($6F6E): recopy the four "top" single-word picture stubs
 * (VROCK5-8, $22BC-$22C2) from the RSOURC rows, using only the slow
 * rotation counters ($3D8/$3D9). Falls into MoveSaucerPicColor.
 * No inputs; clobbers A/X/Y, TEMP2, TEMP3, VGLIST/EAC2. */
void toppic(void)
{
    uint8_t a, x, y;
    x = 3;                              /* L6F6E LDX #$03              */
    for (;;) {                          /* Toppic_10                   */
        y = save_later(x);              /* TEMP2=x, TEMP3=y=x*2       */
        VGLIST = lowones_stardest[8 + y]; /* L6F73 LDA $6E85,Y ($6E7D+8) */
        EAC2 = lowones_stardest[9 + y]; /* where to build picture      */
        /* adjust TEMP3 to point at the top-4 slot words               */
        TEMP3 = (uint8_t)(0x08 + TEMP3);/* L6F7D-L6F82 CLC ADC         */
        a = (uint8_t)(x & 0x01);        /* L6F84 TXA / AND #$01        */
        x = (uint8_t)(a + 2);           /* TAX/INX/INX: slow rotations */
        (void)get_rotation_color_code(x);
        x = TEMP2;                     /* L6F8D restore star index    */
        if (x == 0) break;              /* DEX / BPL Toppic_10         */
        x--;
    }
    move_saucer_pic_color();            /* fall-through at $6F92       */
}

/* DoLowOnesEvery ($6EE5): the per-frame star-picture service, called at
 * the top of every mainline frame ($4024). No inputs; clobbers A/X/Y,
 * TEMP2, POTGO, TEMP3, VGLIST/EAC2 (the VG list pointer!), and the star
 * state cells $3D6-$3DD. Falls into Toppic -> MoveSaucerPicColor.
 *
 * Star state (ASTERS = $3D6):
 *   $3D6/$3D8  clockwise rotation counters (fast pair / slow pair),
 *              INCed here ($3D8 only every 4th frame); low 2 bits pick
 *              the RSOURC picture row.
 *   $3D7/$3D9  counter-clockwise counters, DECed on the same schedule.
 *   $3DA/$3DC  color-cycle counters for the clockwise stars: INC every
 *              4th rotation step, reloaded to $FD (3 colors) / $FC
 *              (4 colors) when they go non-negative; low 2 bits = color.
 *   $3DB/$3DD  picture-select countdown for the CCW stars (reload 2/3
 *              when a CCW counter leaves its first picture); their low
 *              2 bits double as the color codes for star stubs 1 and 3.
 *
 * Each of the four rock stubs VROCK1-4 ($2290/$229E/$22AC/$22BA) is
 * rewritten as: [2-byte AVG JMPL to the picture] then, for stars 0-2,
 * three 4-byte {COLOR word lo,$64; RTSL $C0,$C0} groups (CVRxx cells);
 * star 3's stub is the 2-byte word only. */
void do_low_ones_every(void)
{
    uint8_t a, x, y;

    x = 0;                              /* L6EE5: do low ones every frame */
    if ((ZP_44 & 0x03) == 0)            /* L6EE7-L6EEB                 */
        x = 2;                          /* L6EED: will do both         */

    for (;;) {                          /* DoLowOnesEvery_1            */
        g.ram[A_ASTERS + x]++;          /* L6EEF INC ASTERS,X          */
        if ((g.ram[A_ASTERS + x] & 0x03) == 0) {
            g.ram[0x3DA + x]++;         /* $3DA,X: color counter (ASTERS+4) */
            if (!(g.ram[0x3DA + x] & 0x80)) {   /* L6EFC BMI _5        */
                a = 0xFD;               /* 3 colors                    */
                if (x == 2)             /* L6F00 CPX #$02 / BNE        */
                    a = 0xFC;           /* 4 colors here               */
                g.ram[0x3DA + x] = a;   /* DoLowOnesEvery_2            */
            }
        }
        /* DoLowOnesEvery_5 */
        g.ram[0x3D7 + x]--;             /* $3D7,X: CCW counter (ASTERS+1) */
        if ((g.ram[0x3D7 + x] & 0x03) == 0x03) {  /* just left first pic? */
            g.ram[0x3DB + x]--;         /* $3DB,X: pic select (ASTERS+5) */
            if (g.ram[0x3DB + x] & 0x80) {        /* L6F18 BPL _6      */
                a = 0x02;
                if (x == 2)             /* L6F1C CPX #$02 / BNE        */
                    a = 0x03;
                g.ram[0x3DB + x] = a;   /* DoLowOnesEvery_7            */
            }
        }
        /* DoLowOnesEvery_6: DEX / DEX / BPL _1 */
        if (x == 0) break;
        x -= 2;
    }

    /* DoLowOnesEvery_8: rotate and recopy all 4 rock stubs */
    x = 3;                              /* L6F29 LDX #$03              */
    for (;;) {                          /* DoLowOnesEvery_10           */
        y = save_later(x);              /* TEMP2=x, TEMP3=y=x*2       */
        VGLIST = lowones_stardest[y];     /* L6F2E: stub LSB ($6E7D,Y)   */
        EAC2 = lowones_stardest[y + 1]; /* MSB                         */
        y = get_rotation_color_code(x); /* JMPL word written; y = 2    */
        x = TEMP2;                     /* L6F3B recall X              */
        POTGO = 0x02;                   /* L6F3D-L6F3F: 3 color words  */
        a = (uint8_t)(g.ram[0x3DA + x] & 0x03);   /* color code        */
        if (x < 3) {                    /* L6F46 CPX #$03 / BCS _20    */
            if (x >= 2)                 /* L6F4A CPX #$02 / BCC _12    */
                a = (uint8_t)(a + 0x05 + 1);  /* ADC #$05, C=1 from CPX:
                                           +6 -> Barco2 4-color table  */
            x = a;                      /* DoLowOnesEvery_12 TAX       */
            do {                        /* DoLowOnesEvery_15           */
                vg_poke_list(y, lowones_colortab[x]);   /* proper color */
                y++; x++;
                vg_poke_list(y, 0x64);  /* finish COLOR (STAT) word    */
                y++;
                vg_poke_list(y, 0xC0);  /* now add an RTSL             */
                y++;
                vg_poke_list(y, 0xC0);  /* 2 bytes                     */
                y++;
                POTGO--;                /* L6F65 DEC POTGO             */
            } while (!(POTGO & 0x80));  /* BPL _15                     */
        }
        x = TEMP2;                     /* DoLowOnesEvery_20 restore X */
        if (x == 0) break;              /* DEX / BPL _10               */
        x--;
    }

    toppic();                           /* fall-through at $6F6E       */
}

/* L80RandomWave0 ($6FDD): pick the picture code for a newly spawned rock
 * for the current WAVE ($3AF, clamped to 18).
 * In:  X, Y = caller registers (STASHED to $17 and TEMP7 ($15) - real RAM
 *      stores the oracle diff sees - then restored, so the C caller keeps
 *      its own copies); WAVE, MODNUM ($3F8).
 * Out: A = picture code from the $6EDD table; MODNUM cycled down (with
 *      reload from the Mod table) on the "random" waves flagged $80 in
 *      TableRandomPictureSelect.
 * NOTE: both lookups use base-1 addressing (LDA $6FB8,X / LDY $6FCA,X
 *      with X >= 1); with WAVE = 0 the ROM would read the RTS opcode at
 *      $6FB8 ($60) and index $6EDD+$60 into code - assumed unreachable
 *      (callers spawn rocks only after WAVE is bumped past 0). */
uint8_t l80_random_wave0(uint8_t x, uint8_t y)
{
    uint8_t a;
    g.ram[0x17] = x;                    /* L6FDD STX $17 (scratch save) */
    TEMP7 = y;                           /* L6FDF STY TEMP7              */
    x = WAVE;                           /* L6FE1 LDX WAVE              */
    if (x >= 0x12)                      /* L6FE4 CPX #$12 / BCC        */
        x = 0x12;
    a = lowones_mod_m1[x];              /* L6FEA: get modulo (Mod[x-1]) */
    if (lowones_randsel_m1[x] & 0x80) { /* L6FED LDY / BPL L7000       */
        MODNUM--;                       /* L6FF2 DEC MODNUM: next pic  */
        if (MODNUM & 0x80)              /* BPL L6FFD                   */
            MODNUM = lowones_mod_m1[x]; /* L6FF7 restore               */
        a = MODNUM;                     /* L6FFD LDA MODNUM            */
    }
    a = lowones_piccode[a];             /* L7000 TAX / LDA $6EDD,X     */
    /* L7004/L7006: LDX $17 / LDY TEMP7 - X,Y restored for the caller   */
    return a;                           /* L7008 RTS                   */
}
