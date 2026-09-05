/* earom.h - Space Duel C port: EAROM driver + buffer copies (A2EARO, $8747).
 *
 * The EAROM (ER-2055, 64 nybble-pair bytes at $0F00-$0F3F, data in at $0A00,
 * control at $0E80) holds two checksummed batches:
 *   batch bit 0: high scores + initials, EAROM $02-$1D, RAM buffer $0164
 *   batch bit 1: bookkeeping (ontime, games played), EAROM $1E-$3E, buffer $0192
 * A tick of the state machine (output_earom_erased_written) runs from the IRQ
 * every 16th 246 Hz tick. Reads run to completion inside one tick; writes take
 * two ticks per byte (erase, then write).
 */
#ifndef EAROM_H
#define EAROM_H

#include <stdint.h>

/* request entry points (set the pending-batch bits, return immediately) */
void zero_earom(void);                 /* ZeroEarom            $874F: zero bookkeeping   */
void eazhis(void);                     /* Eazhis               $8753: zero scores/initials */
void eazero(void);                     /* Eazero               $8757: zero both batches  */
void request_zero_earom(uint8_t a);    /* RequestZeroEarom     $8759: a = batch bits     */
void write_high_scores_initials(void); /* WriteHighScoresInitials $875D                  */
void request_bookkeeping_update(void); /* RequestBookkeepingUpdate $8761                 */

/* synchronous read of both batches into the RAM buffers (boot, self-test) */
void read_everything(void);            /* ReadEverything       $8777 */

/* one state-machine tick; called by sd_irq every 16th IRQ */
void output_earom_erased_written(void);/* OutputEaromErasedWritten $8781 */

/* buffer <-> live-cell copies */
void transfer_high_scores_buffer(void);/* TransferHighScoresBuffer $886F: live -> buffer */
void copy_from_buffer_back(void);      /* CopyFromBufferBack   $88B6: buffer -> live     */
void copy_ontime_from_buffer(void);    /* CopyOntimeFromBuffer $89A3: EABC -> EAREQU     */

/* game-end bookkeeping: fold elapsed game time into totals, bump games-
 * played, stage+start the bookkeeping EAROM write (tail-calls
 * request_bookkeeping_update). Call site: mainline.c chkst1() ($4397). */
void update_info_at_end(void);         /* UpdateInfoAtEnd      $893E                     */

#endif /* EAROM_H */
