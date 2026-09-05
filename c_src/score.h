/* score.h - Space Duel C port: scoring / high-score table / game-select
 * screen (UpdateHighScoreTable $6614, Display4Names $7529, module A2NAME).
 *
 * UpdateHighScoreTable lives in the object/rock-splitting address range
 * ($6614, right after SplitRockIntoFragments) but is pure high-score-table
 * maintenance with no other home; Display4Names is the labelled A2NAME
 * module. Both operate on the same live-score/high-score-table RAM cells
 * ($00DD-$0118 scores, $0119-$0163ish initials) that earom.c's
 * TransferHighScoresBuffer/CopyFromBufferBack already touch (see
 * NOTES_score.md), so they are grouped here rather than in display.c.
 */
#ifndef SCORE_H
#define SCORE_H

#include <stdint.h>

/* UpdateHighScoreTable ($6614): called at game end (mainline.c chkst1(),
 * right after update_info_at_end()) to check the just-finished game's
 * live score against the running high-score table for the selected game
 * type, insert it if it beats an entry, and flag initials entry. No
 * arguments; reads ZP_34 (game type) and a live 3-byte score staged by
 * the caller at $3A/$3B/$3C (+3/+6 per slot - see NOTES_score.md for the
 * zero-page reuse this depends on). */
void update_high_score_table(void);

/* Display4Names ($7529, A2NAME): draws the up to 4 game-select boxes,
 * pictures, flashing selection box, per-game status message, and the
 * credit display. No arguments (LDY #$03 on entry makes any caller-
 * computed Y dead - see mainline.c's call sites). */
void display_4_names(void);

/* HexBcdConversionInput ($8C62): binary -> 2-3 digit BCD "double dabble"
 * conversion, In: a = binary value. Out: NOBJ = low 2 BCD digits,
 * g.ram[0x16] = BCD hundreds digit (unnamed scratch). Exposed (not
 * static) because the self-test module ($8BA6, not yet on disk) shares
 * this exact routine - it should extern this instead of duplicating it. */
void hex_bcd_conversion_input(uint8_t a);

/* AddPointsToScore ($5F68): add a BCD points value to the scoring player's
 * live 3-byte score, carry into its thousands bytes, mirror the same
 * points into the combined-game score, and award a bonus life when the
 * player crosses his next threshold.  This is the routine that STAGES the
 * $3A/$3B/$3C(+3/+6) live score which update_high_score_table() reads at
 * game end.  In: a = the BCD points in tens ($10 = 100 points); OWNER
 * ($038E) names the player (bit 7 = nobody -> immediate RTS); $CF (the
 * difficulty level) is added in and decremented.  Out: nothing; the ROM
 * clobbers X (callers reload it from XCOMP/WHITE) and preserves Y.
 * A no-op outside a game (`BIT $35 / BMI`). */
void add_points_to_score(uint8_t a);

#endif /* SCORE_H */
