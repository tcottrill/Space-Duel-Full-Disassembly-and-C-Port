/* msgs.h - Space Duel C port: message/text writer (module AS2MSG, $7730).
 *
 * The message processor appends glyph JSRL words to the display list for
 * one packed, language-selected message. Language comes from g.ram[0xD1]
 * (0 = English, 1 = German, 2 = French, 3 = Spanish, set by Gtoptn $7701).
 *
 * Message numbering (register Y at the entry points):
 *   Y = $00-$14  bank 0 (21 messages) - pointer pair at $7803 + lang*4
 *   Y >= $15     bank 1 (up to 18)    - pointer pair at $7803 + lang*4 + 2,
 *                indexed with Y - $15 (the "second bank" split at $7786).
 * Each pointer targets a per-language offset table; entry Y is the byte
 * offset from the table base to the message's first packed byte.
 *
 * Packed text encoding (decoded by VectorMessage6_20, $77AC-$77CB):
 * each 2-byte pair B0,B1 carries three 5-bit character codes plus a stop
 * flag - 16 bits = 5+5+5+1:
 *   char 1 = B0[7:3]              (LSR,LSR then AND #$3E in VectorMessage2)
 *   char 2 = B0[2:0] : B1[7:6]    (the ROL/ROL TEMP2/ROL/ROL/ASL chain)
 *   char 3 = B1[5:1]
 *   B1[0]  = 1 -> last pair of the message (LSR TEMP2 / BCC at $77C9)
 * A character code of 0 terminates the message early (AND #$3E == 0 in
 * VectorMessage2 purges the return and exits through VectorMessage0).
 * Codes 1-4 index glyph words at $3248 + 2*code ($3456 upside down);
 * codes >= 5 get 14 added to the doubled code first (ADC #$0D with carry
 * set at $77E3), skipping the 7 digit glyphs so code 5 = 'A', 6 = 'B', ...
 */
#ifndef MSGS_H
#define MSGS_H

#include <stdint.h>

/* ---- generated tables (msgs_data.c, by tools/gen_msgs_data.py) --------- */
#define MSGS_OFFSET_BASE 0x7744u  /* CPU address of msgs_offset_rom[0] */
#define MSGS_TEXT_BASE   0x7803u  /* CPU address of msgs_text_rom[0]   */
extern const uint8_t msgs_offset_rom[0x001C]; /* Offset $7744: 7 rows x 4 */
extern const uint8_t msgs_text_rom[0x0502];   /* $7803-$7D04: ptrs + text */

/* ---- routines ---------------------------------------------------------- */
void aux_routine_add_offset(uint8_t x_row);      /* AuxRoutineAddOffset $7730 */
void mesgpos(uint8_t a_dx, uint8_t x_dy);        /* Mesgpos $7760 */
void vector_generator_message_processor(uint8_t y_msg); /* $7770 (yellow) */
void brightness(uint8_t x_color, uint8_t y_msg); /* Brightness $7772 */
void pass_color(uint8_t a_color, uint8_t y_msg); /* PassColor $7773 */
void vector_message5(uint8_t y_msg);             /* VectorMessage5 $7779 (green) */
void vector_message7(uint8_t y_color);           /* VectorMessage7 $777D; TEMP2
                                                  * ($0A) = message number */
void vector_message6(uint8_t y_msg);             /* VectorMessage6 $7782 */

#endif /* MSGS_H */
