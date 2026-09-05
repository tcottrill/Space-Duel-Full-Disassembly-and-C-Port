/* sd_state.h - Space Duel C port: the whole machine state.
 *
 * Phase-1 state model (see DESIGN.md): the real memory arrays, byte-diffable
 * against tools/oracle.py running the real ROMs. Named cells are accessed
 * through the generated aliases in sd_state_defs.h; unnamed cells met during
 * translation get a documented macro below until their meaning is proven.
 */
#ifndef SD_STATE_H
#define SD_STATE_H

#include <stdint.h>

typedef struct {
    uint8_t ram[0x400];      /* $0000-$03FF: zero page + stack + game RAM   */
    uint8_t vram[0x800];     /* $2000-$27FF: real AVG display-list bytes    */

    /* ---- hardware-seam shadows (not CPU RAM; owned by translated code) -- */
    uint8_t out1;            /* $0C00 latch: coin counters, lamps, flip     */
    uint32_t irq_count;      /* IRQs serviced since reset (oracle-diffable) */
    uint32_t frame_count;    /* VGGO count since reset                      */
} sd_state;

extern sd_state g;

#include "sd_state_defs.h"

/* Generic accessors for indexed/indirect idioms. */
#define RAM(a)   (g.ram[(a) & 0x3FF])
#define VRAM(a)  (g.vram[(a) - 0x2000])   /* a = CPU address $2000-$27FF */

/* ---- unnamed cells (upgrade to real names as meanings are proven) ------ */
/* $33: ~61.5 Hz frame gate; IRQ does INC $33 every 4th tick, mainline
 *      consumes bits with LSR $33/BCC ($4027). */
#define ZP_33          (g.ram[0x33])
/* $34: selected game type (0-3, game-select switch); $35: game-active flag
 *      ($00 = attract, minus = game in progress); both from CheckForStartEnd. */
#define ZP_34          (g.ram[0x34])
#define ZP_35          (g.ram[0x35])
/* $38/$39: initials-entry state per player (minus = not entering).         */
#define ZP_38          (g.ram[0x38])
#define ZP_39          (g.ram[0x39])
/* $44: master frame counter (attract flash timing); $45: attract stage.    */
#define ZP_44          (g.ram[0x44])
#define ZP_45          (g.ram[0x45])
/* $51: two-player/ship-2 active flag (BIT $51 gates ship 1 processing).    */
#define ZP_51          (g.ram[0x51])
/* Self-test cells (AS2TST.MAC's own allocations, which spaceduel_defines
 * leaves unnamed): $12/$16/$17 are the BCD scratch above NMROCK/NOBJ that
 * Averag/HexBcd/Times4Decimal widen into, and $17 doubles as the crosshatch
 * color index; $1A = selected bookkeeping option, $1B = SELECT debounce;
 * $81-$83 = ERPLC+1..3, the bad-POKEY1 / bad-POKEY2 / bad-EAROM flags
 * (ERPLC+0 is COCKBI $80 = bad RAM); $A1 = FRAME, the diagnostic-loop frame
 * counter (TESTNM $A0 is aliased OBJ). */
#define ZP_12          (g.ram[0x12])
#define ZP_16          (g.ram[0x16])
#define ZP_17          (g.ram[0x17])
#define ZP_1A          (g.ram[0x1A])
#define ZP_1B          (g.ram[0x1B])
#define ZP_ERPLC1      (g.ram[0x81])
#define ZP_ERPLC2      (g.ram[0x82])
#define ZP_ERPLC3      (g.ram[0x83])
#define ZP_FRAME       (g.ram[0xA1])

/* The VG display-list pointer is the real zero-page pair the ROM used:
 * lo at $01 (alias BLUE), hi at $02 (alias EAC2). Access as a 16-bit CPU
 * address through these helpers (vgutil.c owns all writes through it). */
#define VGLIST_ADDR    ((uint16_t)(g.ram[0x01] | ((uint16_t)g.ram[0x02] << 8)))

#endif /* SD_STATE_H */
