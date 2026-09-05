/* vgutil.h - Space Duel C port: VG utility layer (VGUTR2, $8E42).
 *
 * Appends real AVG words to the display list through the real list pointer
 * (zp $01/$02). Carry-flag protocols are explicit int parameters/returns.
 */
#ifndef VGUTIL_H
#define VGUTIL_H

#include <stdint.h>

void vg_add2(uint8_t lo, uint8_t hi);            /* Add2WordsToVector $8EA5 */
void vg_add_rtsl(void);                          /* AddRtslToVector   $8E42 */
void vg_add_halt(void);                          /* AddHaltToVector   $8E46 */
void center_beam_in_middle(void);                /* CenterBeamInMiddle $8EA1 */
void vg_add_jmpl(uint8_t a_hi, uint8_t x_lo);    /* AddJmplToVector   $8E7D */
void vg_add_jsrl(uint8_t a_hi, uint8_t x_lo);    /* AddJsrlToVector   $8E8E */
void vglist_stat_from_black(void);               /* VglistVglist1Vector $8E95 */
void set_vg_status(uint8_t y);                   /* SetVectorGeneratorStatus $8E97 */
void set_holding_buffer_z(uint8_t y);            /* SetHoldingBufferZ $8E9D */
void set_vg_scale(uint8_t a_bshift, uint8_t y_linear); /* $8EBA */
void use_full_size(uint8_t a_bshift);            /* UseFullSize $8EB8 */
void vg_add_vector_from_zp(uint8_t x_index);     /* AddVectorToVector $8EF6 */
void vg_vctr(uint8_t a_dx, uint8_t x_dy);        /* Vgvtr1/Vgvtr3 $8EC5 (BLACK preset) */
void vg_vctr_dark(uint8_t a_dx, uint8_t x_dy);   /* UpdownVectorUpsideDown $8EC1 */
void vg_vctr_z(uint8_t a_dx, uint8_t x_dy, uint8_t y_z); /* ShortFormVgvctrCall $8EC3 */
void negate_a_long_vector(void);                 /* NegateALongVector $8F15 */
int  display_digit(uint8_t a);                   /* DisplayDigit $8E55; returns C=0 */
int  display_digit_with_zero(uint8_t a, int carry); /* $8E4F; returns C */
void save_input_parameters(uint8_t a_zp, uint8_t y_count, int carry); /* SaveInpuParameers $871C */
void vg_poke_list(uint8_t y, uint8_t v);         /* raw STA (BLUE),Y            */
void vg_advance_list(uint8_t y);                 /* AddY1ToVector $8EAD: +=y+1  */
int  vg_char(uint8_t char_index, int carry);     /* SaveCFlag $8E5A (glyph JSRL)*/

#endif /* VGUTIL_H */
