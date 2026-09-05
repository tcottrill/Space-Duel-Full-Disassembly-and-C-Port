/* coins.h - Space Duel C port: the coin/credit routine (COIN65, $741A-$7528).
 *
 * One public entry: the anonymous per-IRQ routine at $741A, called from the
 * IRQ service ($8660 JSR L741A) whenever LANGBT bit 7 is clear and the
 * self-test switch is off. No register inputs; A/X/Y clobbered.
 *
 * The $741C address is only ever reached by the routine's own mech loop
 * (L74B0 JMP L741C) - it is loop control flow here, not a separate C entry.
 * Likewise InstructionsBracketsAreIllustration ($7428), GetBonusAdderMode
 * ($74B3), Extb ($74D7), L_2 ($74F8) and Ext ($74FA) have no external
 * callers (branch targets only) and live inside coin_routine's flow.
 */
#ifndef COINS_H
#define COINS_H

/* L741A: per-IRQ coin routine - debounce/validate the three coin mechs,
 * accumulate unit-coins and credits, run the EM coin-counter pulse timers. */
void coin_routine(void);

#endif /* COINS_H */
