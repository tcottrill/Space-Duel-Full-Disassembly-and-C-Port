/* selftest.h - Space Duel C port: the self-test module (AS2TST).
 *
 * Two ways in, both on IN0 d4 (the cabinet's SELF TEST switch, 0 = test):
 *
 *   power-on with the switch on   Poweron $8086 -> BeginningPattern $8110:
 *                                 RAM marches, ROM checksums, POKEY and
 *                                 EAROM checks, then MainLineDiagLoop $8590
 *                                 - the six operator screens, stepped with
 *                                 the DIAGNOSTIC STEP button. Leaving: the
 *                                 switch off parks the CPU in
 *                                 WatchDogResetExit $8618 until the watchdog
 *                                 resets it into the game.
 *   switch on while the game runs Start2 $4015 -> AllStopPlease $8A1D: the
 *                                 bookkeeping screen (St2 loop $8A8C):
 *                                 on-time, games and average time per game
 *                                 type, the option switches, coin mechs,
 *                                 and the START+SELECT option (reset / clear
 *                                 scores / clear times / clear both).
 *                                 Leaving: switch off -> Pwron $68CA.
 *
 * Frame model, as mainline.c's: one call of selftest_frame() is ONE pass of
 * whichever loop the CPU is parked in (St2, MainLineDiagLoop, or the
 * signature-analysis loop at $8D33) = one VGGO. The entry routines run the
 * loop's prologue and, where the ROM falls straight into the loop body, its
 * first pass. Which loop the CPU is in is PC state, not RAM: it is the one
 * thing this module keeps outside g (sd_cpu_loop()). See NOTES_selftest.md.
 */
#ifndef SELFTEST_H
#define SELFTEST_H

#include <stdint.h>

/* ---- where the CPU is parked (frame-granular program counter) --------- */
enum sd_cpu_loop {
    SD_LOOP_START2 = 0,   /* the game's Start2 loop: sd_mainline_frame()   */
    SD_LOOP_ST2,          /* bookkeeping screen, St2 $8A8C                  */
    SD_LOOP_DIAG,         /* diagnostics, MainLineDiagLoop $8590            */
    SD_LOOP_SIGANAL       /* signature analysis, $8D33 (never returns)      */
};
int  sd_cpu_loop(void);
void sd_cpu_loop_reset(void);          /* Poweron $803F: back to Start2     */

/* ---- entry points ------------------------------------------------------ */
void beginning_pattern(void);   /* BeginningPattern $8110 (from Poweron $808D):
                                 * runs through Ok2 $82B8 and parks in
                                 * MainLineDiagLoop (no pass run yet)        */
void all_stop_please(void);     /* AllStopPlease $8A1D (from Start2 $401C):
                                 * the prologue AND the first St2 pass       */
int  selftest_frame(void);      /* one pass of the parked loop; returns 0
                                 * when the CPU is in Start2 (nothing run)   */

/* ---- const tables (selftest_data.c, by tools/gen_selftest_data.py) ----- */
extern const uint8_t selftest_sftjsr[0x0C];     /* Sftjsr $861A            */
extern const uint8_t selftest_sndsel[0x12];     /* $83B8 + SoundTableLo +
                                                 * Sndfrq                  */
extern const uint8_t selftest_dollar[0x04];     /* DollarMechMultipliers   */
extern const uint8_t selftest_posbars[0x07];    /* PositionBars $840D      */
extern const uint8_t selftest_position[0x07];   /* Position $8414          */
extern const uint8_t selftest_badnws[0x04];     /* Badnws $841B            */
extern const uint8_t selftest_hlpos[0x08];      /* Hlpos $846F             */
extern const uint8_t selftest_vlpos[0x0C];      /* Vlpos $8477             */
extern const uint8_t selftest_avgidx[0x04];     /* CalculateAverageGameTime*/
extern const uint8_t selftest_timix[0x04];      /* Timix $89B5             */
extern const uint8_t selftest_dosel[0x08];      /* DoSelfTest $8C9E        */
extern const uint8_t selftest_bonus_disp[0x08]; /* BonusAddresTableDisplay */
extern const uint8_t selftest_fs_ypos[0x06];    /* PositionsFighters.. (3)
                                                 * + Y2pos (3)             */
extern const uint8_t selftest_tipos[0x08];      /* Tiposx(4) + Tiposy(4)   */
extern const uint8_t selftest_gmpos[0x08];      /* Gmposx(4) + Gmposy(4)   */
extern const uint8_t selftest_avpos[0x08];      /* Avposx(4) + Avposy(4)   */
extern const uint8_t selftest_langlt[0x04];     /* Langlt $8C5E            */
extern const uint8_t selftest_msg_x[0x11];      /* L0Normal0fMedium $8CEF  */
extern const uint8_t selftest_msg_y[0x11];      /* Y3pos $8D00             */
extern const uint8_t selftest_msg_color[0x11];  /* MessageColor $8D11      */
extern const uint8_t selftest_msg_num[0x11];    /* MessageNumberRealMessage*/

#endif /* SELFTEST_H */
