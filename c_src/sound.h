/* sound.h - Space Duel C port: the sound module (AS2SAC/AS2POK, $703C-$7419).
 *
 * Register protocols (derived from all call sites; see NOTES_soundcoins.md):
 *
 * - The trigger stubs ($72B9-$72EF) and high_score_tune/badhab park the
 *   caller's live 6502 X and Y in TEMPA/TEMPB ($1C/$1D) before the channel
 *   scan and restore them after (Badhab $72FA: STX TEMPA / STY TEMPB ...
 *   LDX TEMPA / LDY TEMPB). The registers themselves are preserved, but the
 *   RAM stores are oracle-visible, so every trigger takes the caller's X/Y
 *   as (x_in, y_in) and the C caller must pass its live values. A is
 *   clobbered (it carries the sound code).
 *
 * - In attract mode ($35 bit 7 clear) with HSCFLG bit 7 clear the triggers
 *   return without touching RAM at all (HighScoreTune $72F1 early-out).
 */
#ifndef SOUND_H
#define SOUND_H

#include <stdint.h>

/* AlwaysRemainsSameBoth ($703C): super-saucer twin activation. Called from
 * Pictur ($5D71) with X = object index $1F; X is saved/restored on the
 * stack (register-only, no RAM effect), A and Y are clobbered. No-op unless
 * SUPRSAC bit 7 is set. */
void always_remains_same_both(void);

/* L2Saucers ($7091): step both saucer X velocities ($21F/$220) one count
 * toward their signed minimum velocities ($D3/$D4). Called from Frame07
 * ($6A4E); clobbers A and X, no inputs. */
void l2_saucers(void);

/* RandomFuzz ($6B45): 1-in-8 fuse crackle for the surviving rigid-pair
 * ship.  Reads POKEY1 RANDOM on every call; x_in/y_in are the caller's
 * live 6502 X/Y (they reach TEMPA/TEMPB through the FusePlyr trigger). */
void random_fuzz(uint8_t x_in, uint8_t y_in);

/* StopFuseSound ($6B57): stop the fuse - channels 0/1/6/7 script pointers
 * cleared, POKEY1 AUDC1/AUDC4 written 0. No register protocol. */
void stop_fuse_sound(void);

/* ---- sound trigger stubs ($72B9-$72EF): LDA #code / BNE HighScoreTune ---- */
void popsn(uint8_t x_in, uint8_t y_in);         /* Popsn       $72B9 code $DF */
void fuse_plyr1(uint8_t x_in, uint8_t y_in);    /* FusePlyr1   $72BD code $9F */
void fuse_plyr0(uint8_t x_in, uint8_t y_in);    /* FusePlyr0   $72C1 code $8F */
void reenter(uint8_t x_in, uint8_t y_in);       /* Reenter     $72C5 code $4F */
void reenter2(uint8_t x_in, uint8_t y_in);      /* Reenter2    $72C9 code $3F */
void sh0sn(uint8_t x_in, uint8_t y_in);         /* Sh0sn       $72CD code $BF */
void sh1sn(uint8_t x_in, uint8_t y_in);         /* Sh1sn       $72D1 code $CF */
void saucer_fire(uint8_t x_in, uint8_t y_in);   /* SaucerFire  $72D5 code $0F */
void player0_fire(uint8_t x_in, uint8_t y_in);  /* Player0Fire $72D9 code $1F */
void player1_fire(uint8_t x_in, uint8_t y_in);  /* Player1Fire $72DD code $2F */
void extra_life2(uint8_t x_in, uint8_t y_in);   /* ExtraLife2  $72E1 code $5F */
void explosion(uint8_t x_in, uint8_t y_in);     /* Explosion   $72E5 code $6F */
void thrust_sound(uint8_t x_in, uint8_t y_in);  /* ThrustSound $72E9 code $7F */
void gates(uint8_t x_in, uint8_t y_in);         /* Gates       $72ED code $AF */

/* HighScoreTune ($72F1): gate a sound code - play only in game ($35 bit 7)
 * or while the high-score tune flag (HSCFLG bit 7) is up, then fall into
 * Badhab. code = the A the stubs load. */
void high_score_tune(uint8_t code, uint8_t x_in, uint8_t y_in);

/* Badhab ($72FA): unconditionally start the channels mapped to the code by
 * the $70C1 table (16 rows scanned, channel 15 down to 0). */
void badhab(uint8_t code, uint8_t x_in, uint8_t y_in);

/* ContinuesPreviouslyStartedSound ($731D): the per-IRQ sound-channel
 * update - walk channels 15..0 and feed the POKEYs. Clobbers A/X/Y.
 * (The anonymous loop entries sub_731f/$731F and sub_73a1/$73A1 are only
 * reached by internal JMPs - they are this function's loop, not entries.) */
void continue_sounds(void);

/* Inisou ($73A8): silence both POKEYs (SKCTL 0 then 7, audio registers and
 * AUDCTL cleared) and kill the channel-0..7 script state. Channels 8-15
 * scripts are deliberately NOT cleared (ROM quirk - LDX #$07 loop). */
void inisou(void);

/* ForceFieldUp ($73D4): mainline force-field hum / drone ($4107). Drives
 * POKEY2 AUDF2/AUDC2 + AUDCTL and POKEY1 AUDF3/AUDC3 (unless sound
 * channel 4 ($5A, alias $005A) is scripted). Clobbers A/X/Y. */
void force_field_up(void);

#endif /* SOUND_H */
