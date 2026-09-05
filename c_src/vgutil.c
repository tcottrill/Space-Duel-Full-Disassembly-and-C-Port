/* vgutil.c - Space Duel C port: the VG utility layer (module VGUTR2, $8E42).
 *
 * These routines append real AVG words to the display list through the real
 * zero-page list pointer (lo $01 = BLUE, hi $02 = EAC2), exactly as the ROM
 * did. Byte parity with the oracle is the contract; nothing is abstracted.
 *
 * The zero-page cells $00-$09 (Atari's names BLACK, BLUE, EAC2, CHAN2V, RED,
 * CHAN3V, TWOPI, WHITE, EACE, VGBRIT) are the VG scratch block: $01/$02 the
 * list pointer, $03-$06 the shifted 16-bit deltas of the long-vector builder,
 * $00 the z/status byte mixed into vector words.
 */
#include "sd_state.h"
#include "vgutil.h"

/* Generated vector ROM ($2800-$3FFF); the character JSRL tables the digit
 * writer copies from live at $324A (normal) / $3458 (flipped). */
extern const uint8_t sd_vecrom[0x1800];

/* ------------------------------------------------------------------ */
/* memory routing for the list pointer and the negate reader           */
/* ------------------------------------------------------------------ */

/* STA (BLUE),Y - the list pointer normally targets vector RAM; route by
 * address so a holding buffer in CPU RAM also works. */
static void vg_store(uint8_t y, uint8_t v)
{
    uint16_t a = (uint16_t)(VGLIST_ADDR + y);
    if (a >= 0x2000 && a < 0x2800) g.vram[a - 0x2000] = v;
    else if (a < 0x400)            g.ram[a] = v;
    /* else: write to nowhere, like the bus would */
}

/* LDA (ptr),Y over the addressable read space (NegateALongVector). */
static uint8_t mem_read(uint16_t a)
{
    if (a < 0x400)                 return g.ram[a];
    if (a >= 0x2000 && a < 0x2800) return g.vram[a - 0x2000];
    if (a >= 0x2800 && a < 0x4000) return sd_vecrom[a - 0x2800];
    return 0;
}

/* AddY1ToVector ($8EAD): list pointer += Y+1 (TYA/SEC/ADC BLUE). */
static void vg_advance(uint8_t y)
{
    unsigned s = (unsigned)g.ram[0x01] + y + 1u;
    g.ram[0x01] = (uint8_t)s;
    if (s > 0xFF) g.ram[0x02]++;           /* carry -> INC EAC2 */
}

/* ------------------------------------------------------------------ */
/* word appenders                                                      */
/* ------------------------------------------------------------------ */

/* Add2WordsToVector ($8EA5): append the word lo/hi, advance 2. */
void vg_add2(uint8_t lo, uint8_t hi)
{
    vg_store(0, lo);
    vg_store(1, hi);
    vg_advance(1);
}

/* AddRtslToVector ($8E42) / AddHaltToVector ($8E46) via Vghal1: the single
 * byte is written to BOTH halves of the word (opcode lives in the top
 * nibble; the low byte is a don't-care the ROM fills with the same value). */
void vg_add_rtsl(void) { vg_add2(0xC0, 0xC0); }
void vg_add_halt(void) { vg_add2(0x20, 0x20); }

/* CenterBeamInMiddle ($8EA1): CNTR word $8040. */
void center_beam_in_middle(void) { vg_add2(0x40, 0x80); }

/* AddJmplToVector ($8E7D) / AddJsrlToVector ($8E8E): a = high byte of the
 * CPU target address, x = low byte. The hardware word operand is the CPU
 * address >> 1 (13 bits), opcode $E (JMPL) or $A (JSRL) in the top nibble;
 * the ROM forms it with LSR a / ROR x so a's bit 0 rides into x's bit 7. */
static void vg_jump_word(uint8_t a, uint8_t x, uint8_t op)
{
    uint8_t carry = a & 1;
    uint8_t hi = (uint8_t)(((a >> 1) & 0x0F) | op);
    uint8_t lo = (uint8_t)((x >> 1) | (carry << 7));
    /* Vgjmp1 ($8E82): MSB at +1 first, then LSB at +0, advance 2. */
    vg_store(1, hi);
    vg_store(0, lo);
    vg_advance(1);
}
void vg_add_jmpl(uint8_t a_hi, uint8_t x_lo) { vg_jump_word(a_hi, x_lo, 0xE0); }
void vg_add_jsrl(uint8_t a_hi, uint8_t x_lo) { vg_jump_word(a_hi, x_lo, 0xA0); }

/* VglistVglist1Vector ($8E95): COLOR word from the current BLACK byte.
 * SetVectorGeneratorStatus ($8E97): COLOR word $64xx, low byte y
 *   (y = (luminance<<4)|color on this hardware).
 * SetHoldingBufferZ ($8E9D): STAT word $60xx, low byte y. */
void vglist_stat_from_black(void)      { vg_add2(g.ram[0x00], 0x64); }
void set_vg_status(uint8_t y)          { vg_add2(y, 0x64); }
void set_holding_buffer_z(uint8_t y)   { vg_add2(y, 0x60); }

/* UseFullSize ($8EB8) / SetVectorGeneratorScale ($8EBA): SCAL word -
 * a = binary shift (goes to the high byte with opcode $70), y = linear
 * scale low byte. UseFullSize is y = 0. */
void set_vg_scale(uint8_t a_bshift, uint8_t y_linear)
{
    vg_add2(y_linear, (uint8_t)(a_bshift | 0x70));
}
void use_full_size(uint8_t a_bshift) { set_vg_scale(a_bshift, 0); }

/* ------------------------------------------------------------------ */
/* the long-vector builder (Vgvtr family)                              */
/* ------------------------------------------------------------------ */

/* AddVectorToVector ($8EF6): emit a 2-word VCTR from the zero-page quad at
 * x_index: Y delta from zp[2+x]/zp[3+x], X delta from zp[0+x]/zp[1+x]
 * (16-bit, sign-extended), z field = top 3 bits of BLACK ($00) OR'd over
 * the X MSB. With the standard x_index 3 that is CHAN3V/TWOPI ($05/$06)
 * and CHAN2V/RED ($03/$04). Advances 4. */
void vg_add_vector_from_zp(uint8_t x_index)
{
    uint8_t black = g.ram[0x00];
    vg_store(0, g.ram[(uint8_t)(0x02 + x_index)]);                 /* Y LSB */
    vg_store(1, (uint8_t)(g.ram[(uint8_t)(0x03 + x_index)] & 0x1F)); /* Y MSB */
    vg_store(2, g.ram[(uint8_t)(0x00 + x_index)]);                 /* X LSB */
    /* (RED-style MSB & $1F) | (BLACK & $E0): EOR/AND/EOR combine at $8F08 */
    vg_store(3, (uint8_t)((g.ram[(uint8_t)(0x01 + x_index)] & 0x1F) |
                          (black & 0xE0)));
    vg_advance(3);
}

/* Vgvtr3 ($8EC7): a = signed X delta, x = signed Y delta (the second value
 * written becomes the AVG's first word, which is Y). Both are negated when
 * UPDOWN bit 7 is set (cocktail flip), sign-extended and shifted left 2
 * (so delta 1 at scale 0 = a dot), staged in the zp quad, then emitted.
 * BLACK must already hold the z byte (see the entry wrappers below). */
void vg_vctr(uint8_t a_dx, uint8_t x_dy)
{
    uint8_t updown = g.ram[A_UPDOWN];
    unsigned v;
    uint8_t lo, hi;

    v = a_dx;
    if (updown & 0x80) v = (uint8_t)(0u - v);          /* EOR #$FF / ADC #$01 */
    hi = (v & 0x80) ? 0xFF : 0x00;                     /* sign extend         */
    hi = (uint8_t)((hi << 2) | ((v & 0xC0) >> 6));     /* two ASL/ROL steps   */
    lo = (uint8_t)(v << 2);
    g.ram[0x04] = hi;                                  /* RED    = X MSB      */
    g.ram[0x03] = lo;                                  /* CHAN2V = X LSB      */

    v = x_dy;
    if (updown & 0x80) v = (uint8_t)(0u - v);
    hi = (v & 0x80) ? 0xFF : 0x00;
    hi = (uint8_t)((hi << 2) | ((v & 0xC0) >> 6));
    lo = (uint8_t)(v << 2);
    g.ram[0x06] = hi;                                  /* TWOPI  = Y MSB      */
    g.ram[0x05] = lo;                                  /* CHAN3V = Y LSB      */

    vg_add_vector_from_zp(3);                          /* Vgvtr2 ($8EF4)      */
}

/* UpdownVectorUpsideDown ($8EC1): z byte = 0 (dark move), then vg_vctr.
 * ShortFormVgvctrCall ($8EC3): z byte = y, then vg_vctr.
 * Vgvtr1 ($8EC5): BLACK left as the caller staged it. */
void vg_vctr_dark(uint8_t a_dx, uint8_t x_dy)
{
    g.ram[0x00] = 0;
    vg_vctr(a_dx, x_dy);
}
void vg_vctr_z(uint8_t a_dx, uint8_t x_dy, uint8_t y_z)
{
    g.ram[0x00] = y_z;
    vg_vctr(a_dx, x_dy);
}

/* NegateALongVector ($8F15): read a 4-byte VCTR through the pointer at
 * POKRAN/POTGO ($0A/$0B), append its two's-complement negation with the z
 * bits cleared (a dark return leg), advance 4. The 16-bit negation is done
 * exactly as the ROM chains it (EOR/ADC so the carry ripples). */
void negate_a_long_vector(void)
{
    uint16_t src = (uint16_t)(g.ram[0x0A] | ((uint16_t)g.ram[0x0B] << 8));
    unsigned c;
    uint8_t b0 = mem_read(src), b1 = mem_read((uint16_t)(src + 1));
    uint8_t b2 = mem_read((uint16_t)(src + 2)), b3 = mem_read((uint16_t)(src + 3));

    c = ((unsigned)(b0 ^ 0xFF) + 1u);
    vg_store(0, (uint8_t)c);
    c = ((unsigned)(b1 ^ 0xFF) + (c >> 8));
    vg_store(1, (uint8_t)(c & 0x1F));
    c = ((unsigned)(b2 ^ 0xFF) + 1u);
    vg_store(2, (uint8_t)c);
    c = ((unsigned)(b3 ^ 0xFF) + (c >> 8));
    vg_store(3, (uint8_t)(c & 0x1F));
    vg_advance(3);
}

/* ------------------------------------------------------------------ */
/* character / digit output                                            */
/* ------------------------------------------------------------------ */

/* SaveCFlag ($8E5A): copy character char_index's JSRL word from the glyph
 * table ($324A normal, $3458 when UPDOWN bit 7 says flipped) into the list.
 * Preserves and returns the caller's carry (zero-suppression state). */
static int save_c_flag(uint8_t char_index, int carry)
{
    uint16_t tbl = (g.ram[A_UPDOWN] & 0x80) ? 0x3458 : 0x324A;
    uint16_t e = (uint16_t)(tbl - 0x2800 + (uint8_t)(char_index << 1));
    vg_store(0, sd_vecrom[e]);
    vg_store(1, sd_vecrom[e + 1]);
    vg_advance(1);
    return carry;
}

/* DisplayDigit ($8E55): draw digit a&$0F (glyph 1..16; '0' is entry 1),
 * clearing the suppression carry. */
int display_digit(uint8_t a)
{
    return save_c_flag((uint8_t)((a & 0x0F) + 1), 0);
}

/* DisplayDigitWithZero ($8E4F): leading-zero suppression - with carry set,
 * a zero digit draws the blank glyph (entry 0) and keeps carry set; any
 * nonzero digit draws normally and clears carry from then on. */
int display_digit_with_zero(uint8_t a, int carry)
{
    if (!carry) return display_digit(a);
    if ((a & 0x0F) == 0) return save_c_flag(0, 1);
    return display_digit(a);
}

/* SaveInpuParameers ($871C, module A2IRQ but a display helper): draw the
 * multi-byte BCD number held in zero page. a = zp address such that
 * a + (y-1) is the most significant byte, y = byte count, carry = zero
 * suppression on entry. Walks from the MS byte down, high nibble then low;
 * the very last digit always displays (even 0). */
void save_input_parameters(uint8_t a_zp, uint8_t y_count, int carry)
{
    uint8_t nmrock = (uint8_t)(y_count - 1);            /* STY NMROCK */
    uint8_t temp1 = (uint8_t)(a_zp + nmrock);           /* ADC NMROCK */

    for (;;) {
        carry = display_digit_with_zero((uint8_t)(g.ram[temp1] >> 4), carry);
        if (nmrock == 0) carry = 0;                     /* last: show the 0 */
        carry = display_digit_with_zero(g.ram[temp1], carry);
        temp1--;
        if (nmrock-- == 0) break;                       /* DEC/BPL */
    }
    g.ram[0x11] = 0xFF;                                 /* NMROCK after loop */
    g.ram[0x10] = temp1;                                /* TEMP1 shadow      */
}

/* ------------------------------------------------------------------ */
/* public raw-list access for the message processor (AS2MSG writes    */
/* glyph words at successive (BLUE),Y offsets, then advances once)    */
/* ------------------------------------------------------------------ */

void vg_poke_list(uint8_t y, uint8_t v)   { vg_store(y, v); }     /* STA (BLUE),Y */
void vg_advance_list(uint8_t y)           { vg_advance(y); }      /* AddY1ToVector: ptr += y+1 */
int  vg_char(uint8_t char_index, int carry) { return save_c_flag(char_index, carry); } /* SaveCFlag $8E5A */
