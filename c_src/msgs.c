/* msgs.c - Space Duel C port: message/text writer (module AS2MSG, $7730).
 *
 * Draws the language-selected packed messages (see msgs.h for the message
 * numbering and the 3-characters-per-2-bytes encoding). Glyph JSRL words
 * are poked at successive (VGLIST),Y offsets WITHOUT advancing the list
 * pointer; Y is tracked across the whole message and the final
 * DEY / JMP AddY1ToVector advances the pointer once by the exact byte
 * count - modeled here with vg_poke_list()/vg_advance_list() so the
 * pointer arithmetic stays byte-identical to the ROM.
 *
 * Scratch RAM used (all reproduced): TEMP1 $07 / EACE $08 = the indirect
 * text pointer, TEMP2 $0A = saved message number, then per-pair shift
 * scratch. Language register: g.ram[0xD1].
 */
#include "sd_state.h"
#include "vgutil.h"
#include "sd_vecrom.h"
#include "msgs.h"

/* LDA abs,X / LDA (TEMP1,X) over the module's ROM span. The TEMP1/EACE
 * pointer and the table indexing only ever land in $7803-$7D04; anything
 * else reads 0 like the open bus would. */
static uint8_t msg_rom(uint16_t addr)
{
    if (addr >= MSGS_TEXT_BASE &&
        addr < MSGS_TEXT_BASE + sizeof msgs_text_rom)
        return msgs_text_rom[addr - MSGS_TEXT_BASE];
    return 0;
}

/* The 16-bit text pointer the ROM keeps in TEMP1 (lo) / EACE (hi). */
#define WPTR() ((uint16_t)(TEMP1 | ((uint16_t)EACE << 8)))

/* AuxRoutineAddOffset ($7730): language-dependent X reposition before a
 * message. In: X = table row 0-6 (call sites $4284/$4D7D/$4D8E/$4D9F/
 * $4DB0/$5C9D/$603C/$604F/$75B2 pass #$00-#$06). Reads g.ram[$D1]
 * (language); English returns without drawing. Else emits a dark vector
 * dx = Offset[4*row + lang], dy = 0. */
void aux_routine_add_offset(uint8_t x_row)
{
    uint8_t y;
    if (g.ram[0xD1] == 0)                       /* $D1: language 0-3 */
        return;                                 /* L7734 RTS (English) */
    y = (uint8_t)((uint8_t)(x_row << 2) + g.ram[0xD1]); /* TXA ASL ASL ADC */
    vg_vctr_dark(msgs_offset_rom[y], 0x00);     /* L7741 JMP UpdownVector.. */
}

/* Mesgpos ($7760): position the beam for a message. In: A = dx, X = dy
 * (signed screen deltas; every message caller loads these immediately
 * before the JSR). Emits JSRL word $AF61 (target CPU $3EC2, the message
 * origin stub) then the dark positioning vector. */
void mesgpos(uint8_t a_dx, uint8_t x_dy)
{
    vg_add2(0x61, 0xAF);                        /* L7767 Add2WordsToVector */
    vg_vctr_dark(a_dx, x_dy);                   /* L776D JMP UpdownVector.. */
}

/* ------------------------------------------------------------------ */
/* the decoder core                                                    */
/* ------------------------------------------------------------------ */

/* VectorMessage0 ($77CD): DEY, then AddY1ToVector -> list ptr += Y. */
static void vector_message0(uint8_t y)
{
    y--;                                        /* L77CD DEY */
    vg_advance_list(y);                         /* L77CE JMP AddY1ToVector */
}

/* VectorMessage2 ($77D7): emit one character's glyph JSRL word at the
 * current Y offsets (no pointer advance). In: A = raw shifted code,
 * *y = running list offset. Returns 1 when the code is the terminator
 * (the ROM's PLA/PLA purge -> VectorMessage0), else 0.
 * Carry at RTS = UPDOWN bit 7 (from the ASL at $77E9) - the ROL chain in
 * VectorMessage6_20 consumes it, harmlessly (see there). */
static int vector_message2(uint8_t a, uint8_t *y)
{
    uint8_t x;
    uint16_t tbl;

    a &= 0x3E;                                  /* L77D7: code*2, 5 bits */
    if (a == 0)                                 /* L77D9 BNE: end of list */
        return 1;                               /* L77DB PLA/PLA purge    */
    if (a >= 0x0A)                              /* L77DF CMP #$0A (C=1)   */
        a = (uint8_t)(a + 0x0E);                /* L77E3 ADC #$0D: +14    */
    x = a;                                      /* L77E5 TAX              */
    /* L77E6 LDA UPDOWN / ASL: carry = flip bit */
    tbl = (UPDOWN & 0x80) ? 0x3456u : 0x3248u;  /* upside-down table      */
    vg_poke_list(*y, sd_vecrom[tbl + x - SD_VECROM_BASE]);     /* L77F2   */
    (*y)++;                                     /* L77F4 INY              */
    vg_poke_list(*y, sd_vecrom[tbl + 1 + x - SD_VECROM_BASE]); /* L77FD   */
    (*y)++;                                     /* L77FF INY (LDX #$00)   */
    return 0;
}

/* UpdateIndirectPointerCharacters ($77D1): step the TEMP1/EACE text
 * pointer, then emit the character in A via VectorMessage2. */
static int update_indirect_pointer_characters(uint8_t a, uint8_t *y)
{
    TEMP1++;                                    /* L77D1 INC TEMP1 */
    if (TEMP1 == 0)
        EACE++;                                 /* L77D5 INC EACE  */
    return vector_message2(a, y);
}

/* VectorMessage6 ($7782): the message processor body. In: Y = message
 * number (TEMP2 already holds it when entered through VectorMessage7,
 * but this entry takes Y directly). Uses g.ram[$D1] = language.
 * Emits every character's glyph word, then advances the list pointer by
 * the total byte count via VectorMessage0. */
void vector_message6(uint8_t y_msg)
{
    uint8_t a, x, y, c, nc, b1;

    a = (uint8_t)(g.ram[0xD1] << 2);            /* L7782 LDA $D1, ASL,ASL */
    y = y_msg;
    if (y >= 0x15) {                            /* L7786 CPY #$15 (C=1)   */
        x = (uint8_t)(a + 0x02);                /* L778A ADC #$01: +2     */
        y = (uint8_t)(y - 0x15);                /* L778E SEC / SBC #$15   */
    } else {
        x = a;                                  /* L7794 TAX              */
    }

    EACE  = msg_rom((uint16_t)(0x7804 + x));    /* L7795 table ptr hi     */
    TEMP1 = msg_rom((uint16_t)(0x7803 + x));    /* L779A ptr lo (Language-
                                                 * TablePointersSee)      */
    /* L779F CLC / ADC (TEMP1),Y: message = table base + offsets[Y] */
    {
        unsigned s = (unsigned)TEMP1 + msg_rom((uint16_t)(WPTR() + y));
        TEMP1 = (uint8_t)s;
        if (s > 0xFF)
            EACE++;                             /* L77A6 INC EACE         */
    }

    y = 0;                                      /* L77A8 LDY #$00 (list   */
                                                /* offset; X stays 0)     */
    for (;;) {                                  /* VectorMessage6_20      */
        a = msg_rom(WPTR());                    /* L77AC LDA (TEMP1,X)    */
        TEMP2 = a;                             /* L77AE STA TEMP2       */
        a >>= 2;                                /* L77B0 LSR / LSR        */
        /* char 1 = B0[7:3] */
        if (update_indirect_pointer_characters(a, &y))
            break;                              /* pointer now past B0    */

        /* char 2 = B0[2:0]:B1[7:6], assembled by the literal ROL chain.
         * Carry entering the chain = UPDOWN bit 7 (VectorMessage2's ASL);
         * it lands only in a discarded intermediate A. */
        b1 = msg_rom(WPTR());                   /* L77B5 LDA (TEMP1,X)=B1 */
        a = b1;
        c = (uint8_t)(UPDOWN >> 7);
        nc = (uint8_t)(a >> 7);                 /* L77B7 ROL A            */
        a = (uint8_t)((a << 1) | c); c = nc;
        nc = (uint8_t)(TEMP2 >> 7);            /* L77B8 ROL TEMP2       */
        TEMP2 = (uint8_t)((TEMP2 << 1) | c); c = nc;
        nc = (uint8_t)(a >> 7);                 /* L77BA ROL A            */
        a = (uint8_t)((a << 1) | c); c = nc;
        a = TEMP2;                             /* L77BB LDA TEMP2       */
        nc = (uint8_t)(a >> 7);                 /* L77BD ROL A            */
        a = (uint8_t)((a << 1) | c); c = nc;
        a <<= 1;                                /* L77BE ASL (carry dead) */
        if (vector_message2(a, &y))             /* L77BF                  */
            break;

        /* char 3 = B1[5:1]; B1[0] = stop flag */
        a = msg_rom(WPTR());                    /* L77C2 LDA (TEMP1,X)=B1 */
        TEMP2 = a;                             /* L77C4 STA TEMP2       */
        if (update_indirect_pointer_characters(a, &y))
            break;                              /* pointer now past B1    */
        c = (uint8_t)(TEMP2 & 1);              /* L77C9 LSR TEMP2       */
        TEMP2 >>= 1;
        if (c)                                  /* L77CB BCC ..._20       */
            break;
    }
    vector_message0(y);                         /* DEY + AddY1ToVector    */
}

/* ------------------------------------------------------------------ */
/* entry points (color wrappers)                                       */
/* ------------------------------------------------------------------ */

/* VectorMessage7 ($777D): STAT/COLOR word from Y, then run the message
 * whose number is already parked in TEMP2 ($0A). In: Y = color byte. */
void vector_message7(uint8_t y_color)
{
    set_vg_status(y_color);                     /* L777D JSR SetVGStatus  */
    vector_message6(TEMP2);                    /* L7780 LDY TEMP2       */
}

/* PassColor ($7773): In: A = color byte, Y = message number.
 * Call sites: $4096 (bonus-level msg, A=$E1), $506D (combined score,
 * color from $50C4 table), $75F9/$7668 (credits/select screens),
 * $8CEC (self-test exit). */
void pass_color(uint8_t a_color, uint8_t y_msg)
{
    TEMP2 = y_msg;                             /* L7773 STY TEMP2       */
    vector_message7(a_color);                   /* L7775 TAY / JMP VM7    */
}

/* Brightness ($7772): In: X = color/brightness byte, Y = message number.
 * Call sites: $428B (X=TEMP9 fade level), $5CA4 (X=$A7, "BONUS LEVEL"),
 * $6043 (X=$C2, "HIGH SCORES", msg 0). */
void brightness(uint8_t x_color, uint8_t y_msg)
{
    pass_color(x_color, y_msg);                 /* L7772 TXA              */
}

/* VectorGeneratorMessageProcessor ($7770): default yellow ($D6).
 * In: Y = message number. Call sites: $4175 (msg 7 GAME OVER),
 * $4D82/$4D93/$4DA4/$4DB5 (instructions msgs 2-5). */
void vector_generator_message_processor(uint8_t y_msg)
{
    brightness(0xD6, y_msg);                    /* L7770 LDX #$D6         */
}

/* VectorMessage5 ($7779): green messages ($D2). In: Y = message number.
 * Call sites: $607D (1/2 player msg), $760B (select-game msgs). */
void vector_message5(uint8_t y_msg)
{
    TEMP2 = y_msg;                             /* L7779 STY TEMP2       */
    vector_message7(0xD2);                      /* L777B LDY #$D2         */
}
