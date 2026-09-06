/* mainline.h - Space Duel C port: boot + mainline frame loop
 * (AS2CO1 $4000-$43B2, attract/frame service $68CA-$6CA8, Gtoptn/Bigbang
 * $76CC-$772F, Poweron/StartThingsRunning/SetUpInitialsHigh $803F-$810F).
 *
 * Frame-loop model (see NOTES_mainline.md): sd_mainline_frame() is ONE pass
 * of the Start2 loop ($4012 up to the next arrival back at Start2 /
 * StartUpNewAsteroids / InitializePlayer1Start); the re-entry prologues
 * (Initialization, NewastStartNewAsteroids) run in tail position of the
 * pass whose JMP selected them, exactly as the ROM falls through them
 * before reaching Start2 again. sd_boot() is the Poweron game path through
 * Pwron, ending where Start2 would begin.
 */
#ifndef MAINLINE_H
#define MAINLINE_H

#include <stdint.h>

/* ---- the two harness entry points -------------------------------------- */
void sd_boot(void);           /* Poweron $803F (game path) .. Pwron $68CA   */
void sd_mainline_frame(void); /* one Start2 ($4012) pass = one VGGO frame   */

/* ---- routines with callers outside this module ------------------------- */
void pwron(void);                  /* Pwron $68CA (self-test JMPs here too) */
void set_up_initials_high(void);   /* SetUpInitialsHigh $80D4               */
void lsw_vector_address(void);     /* LswVectorAddress $6C96                */
int  check_for_start_end(void);    /* CheckForStartEnd $415A; returns C
                                    * flag: 1 = start pushed, new game      */
int  chkst1(void);                 /* Chkst1 $4357; returns C flag (0)      */
uint8_t nxtstep(void);             /* Nxtstep $43A3; returns A = new $34
                                    * (>>1 when the caberet LSR exited)     */
void gtoptn(void);                 /* Gtoptn $76DB                          */
void bigbang(void);                /* Bigbang $76CC                         */
void uses_temp1_temp11(void);      /* UsesTemp1Temp11 $68FD (frame service) */
void onslaught(void);              /* Onslaught $6AD1                       */
void quick_end_end_onslaught(void);/* QuickEndEndOnslaught $6B1C            */
void comet_calculations(void);     /* CometCalculations $6C65               */
void sub_6c79(uint8_t a);          /* L6C79 (comet-slot step, a = index;
                                    * slot = a + $11)                       */

/* ---- const tables (mainline_data.c, by tools/gen_mainline_data.py) ----- */
extern const uint8_t mainline_game_order[0x04]; /* TableGameOrder $43B3     */
extern const uint8_t mainline_evkm[0x06];       /* EndingValueKillerMine
                                                 * $6A9B + $6AA0 (X=5 read) */
extern const uint8_t mainline_kchend[0x06];     /* Kchend $6AA0 + $6AA5     */
extern const uint8_t mainline_comentable[0x02]; /* Comentable $6ACF: Inco10's
                                                 * lowest slot, per player  */
extern const uint8_t mainline_comet_ramp[0x0C]; /* $6D0F NewCometAngleChange
                                                 * (+0) / NewCometTopSpeed
                                                 * (+4) / FirstCometSTop
                                                 * (+8), indexed by DIFF  */
extern const uint8_t mainline_ttplayr[0x04];    /* Ttplayr $6CD5            */
extern const uint8_t mainline_bonus_optn[0x04]; /* BonusOptionSwitchesAssumed
                                                 * $7724                    */
extern const uint8_t mainline_fighters[0x08];   /* Fighters $7728 +
                                                 * SpaceStation $772C       */
extern const uint8_t mainline_ininitls[0x0F];   /* Ininitls $802D           */

#endif /* MAINLINE_H */
