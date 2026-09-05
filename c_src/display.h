/* display.h - Space Duel C port: the display-builder module.
 *
 * The routines that write each frame's AVG display list: score headings and
 * score/lives areas, the high-score table, initials entry, every object
 * picture (rocks, mines, saucers, shots, ships incl. the non-AVG ship
 * pictures at $2800-$2FFF), the connecting rod and its fuse sparks.
 *
 * Routines that communicate through the 6502 carry flag return int
 * (1 = C set) - see each prototype's comment for the protocol.
 */
#ifndef DISPLAY_H
#define DISPLAY_H

#include <stdint.h>

/* GetPlayersInitials ($4DCD). Called from the mainline with C clear.
 * Returns C: 1 = initial entry finished (mainline restarts Start2),
 * 0 = keep going. (Getin2 $4DD8 is this routine's shared RTS.) */
int  get_players_initials(void);

/* Inset2 ($4FEE): ScoreColorBasedAbove + Inisou, falls into
 * InitializeScoreHeadings. Called from Pwron. */
void inset2(void);

/* InitializeScoreHeadings ($4FF4): fill the score areas with RTSLs and
 * rebuild each area's heading block + JMPL, then Inselo (rock slot init). */
void initialize_score_headings(void);

/* ScoreColorBasedAbove ($50C0): seed the default high-score entry
 * ($D5-$D8). */
void score_color_based_above(void);

/* Entparams ($5C80): bonus-level message during wave delay, comet-warning
 * color flash, and the fixed tail JSRLs of every frame's list. */
void entparams(void);

/* DisplayParameters ($5CF2): redraw any score+lives area whose
 * PL0SCFLAG/PL1SCFLAG/CMBSCFLAG bit 7 says it changed. */
void display_parameters(void);

/* Pictur ($5D6D): draw object x's picture. Caller protocol (Moti20_121):
 * x = object index ($00-$2F), XCOMP ($0C) already = x, and the object's
 * screen position is staged in RED/CHAN2V (X) and TWOPI/CHAN3V (Y). */
void pictur(uint8_t x);

/* CcCarrySetDisplaying ($6002): returns C = 0 (not displaying). */
int  cc_carry_set_displaying(void);

/* Scores ($6004): build the high-score table screen(s).
 * Returns C: 1 = table shown, 0 = nothing displayed. */
int  scores(void);

/* AmountAddRoutineLimits ($67B6): a = amount to add to the 16-bit game
 * timer LNGTIMER/$03BA, saturating at $04xx (sets LNGTIMER=$FF). */
void amount_add_routine_limits(uint8_t a);

/* DisplayShipPicture ($6259): shield STAT + JSRL, player color STAT, then
 * the reflected ship picture via Shpdisplays; falls into Drawrod.
 * x = object index ($21/$22), XCOMP already = x. */
void display_ship_picture(uint8_t x);

/* Expset ($623E): seed the 12 explosion-piece coordinate pairs for ship x
 * in the SH0XPCOORD area ($2700/$2718).  Also called from objects.c
 * (KillXShip $460C and $465D). */
void expset(uint8_t x);

/* Drawrod ($62C6): the connecting rod between the ship pair (combined
 * games), including the fuse-burn shrink and spark JSRL. Uses XCOMP. */
void drawrod(void);

/* Spark2 ($638F): rebuild the SPARKB ($22D0) spark-spoke vectors directly
 * in vector RAM (repoints the list pointer there). Every other frame. */
void spark2(void);

/* Shpdisplays ($63FE): emit ship-picture records as long vectors.
 * x = object index ($21/$22), y = index into the $2800 picture pointer
 * table (angle*2/4 + ShipAddressOffsets). Fall/BothReflects88Cycle/
 * Shpdi5/NoReflects76Cycle/ThenPartiallyDamagedOtherwise/
 * RoutineAlsoDoesBlanking/AlsoUsedFromBelow are its internal phases
 * (static in display.c). */
void shpdisplays(uint8_t x, uint8_t y);

#endif /* DISPLAY_H */
