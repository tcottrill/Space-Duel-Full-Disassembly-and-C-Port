/* objects.h - Space Duel C port: objects / physics / enemies.
 *
 * ROM $43B7-$4CB4 (collision, killer mines, saucer entry + fire control,
 * ship torpedoes), $4F1C-$4FED (ship placement, new-game Initialization),
 * $50D5-$50F9 (Inselo), $5154-$5C7F (motion update, ship control, the
 * tug-of-war bar, wave start-up, shields) and $672C-$67AA (killer-mine
 * start-up).  See NOTES_objects.md for the object-slot map, the per-routine
 * register protocols and the open questions.
 *
 * Register protocols: 6502 X is nearly always an object index, so it is an
 * explicit parameter; several routines return the 6502 X they leave behind
 * because the ROM's next routine indexes with it, and routines that talk
 * through the carry/zero flag return int and say so.  Every function's
 * comment names the ROM label and address.
 */
#ifndef OBJECTS_H
#define OBJECTS_H

#include <stdint.h>

/* ---- collisions ($43B7-$48EC) ------------------------------------------ */
void    collision_detector(void);        /* CollisionDetector $43B7          */
void    up_the_difficulty(void);         /* UpTheDifficulty   $46BE (X=OWNER)*/
void    get_comet_to_go(void);           /* GetCometToGo      $468C          */
void    kill_x_saucer(uint8_t x);        /* KillXSaucer       $53DB          */

/* ---- angle helpers ($48ED-$4933) --------------------------------------- */
/* GetWrapAroundAngle $48ED / FindDifferenceCoordinates $491F: in x = the
 * object doing the looking, y = the object looked at; out A = the arctan
 * angle from PartSignedNumberExit ($67D0). */
uint8_t get_wrap_around_angle(uint8_t x, uint8_t y);
uint8_t find_difference_coordinates(uint8_t x, uint8_t y);

/* ---- killer mines / enemy control ($4934-$4CB4) ------------------------ */
/* KillerMines $4937 (falls into DoEnemy $4934 -> CompetitiveWantWaitOther).
 * in  x = the mainline's live X (only read on the CompetitiveWantWaitOther_90
 *         early-out, which returns it unchanged);
 * out = the 6502 X on exit, which MotionUpdateRoutine ($5174) then uses. */
uint8_t killer_mines(uint8_t x);
/* AccHoldsAngleObject $4956: arctan(y relative to x), then Klmi7.
 * Cross-module entry from the comet module ($6C8D JMP, a tail call). */
uint8_t acc_holds_angle_object(uint8_t x, uint8_t y);
/* Klmi7 $4959: steer object XCOMP toward angle a and rebuild XINC/YINC.
 * Cross-module entry from the comet module ($6C93 JMP). Falls into
 * CompetitiveWantWaitOther, so it returns that routine's exit X. */
uint8_t klmi7(uint8_t a_angle);
uint8_t competitive_want_wait_other(uint8_t x);   /* $49E9; returns exit X   */
uint8_t scent5(uint8_t a, uint8_t x);    /* Scent5 $4AA1 (saucer entry)      */
uint8_t reset_timers(void);              /* ResetTimers $4B5C (X = WHITE)    */
uint8_t hasent(uint8_t x);               /* Hasent $4B5E; returns x          */
uint8_t enemy_fire_control(uint8_t a, int carry); /* EnemyFireControl $4B74  */
void    fire_ships_torpedos(uint8_t x);  /* FireShipsTorpedos $4C70          */
void    temp280_fast0(uint8_t x, uint8_t y);  /* Temp280Fast0 $4CB5          */
void    fire2(void);                     /* Fire2 $4CBF (a bare RTS)         */
void    fire3(uint8_t x, uint8_t y);     /* Fire3 $4CC0                      */

/* ---- start-up ($4F1C-$4FED, $50D5) ------------------------------------- */
void    shpplace(uint8_t x);             /* Shpplace   $4F1C                 */
void    zero_all_ram_past(void);         /* ZeroAllRamPast $4F4B             */
void    initialization(void);            /* Initialization $4F66             */
void    inselo(void);                    /* Inselo     $50D5                 */

/* ---- per-frame motion ($5174-$54A0) ------------------------------------ */
void    motion_update_routine(uint8_t x); /* MotionUpdateRoutine $5174       */
void    moti20(void);                    /* Moti20     $51A9                 */
void    sbttl_stcomet(uint8_t x);        /* SbttlStcomet $53C7               */
/* WaitForDirectedEnemies $53FD: in y = the object number to look for.
 * Returns the 6502 Z flag (1 = nothing directed at it - the caller's BEQ). */
int     wait_for_directed_enemies(uint8_t y);

/* ---- ship control ($54A1-$5915) ---------------------------------------- */
void    move_ship(uint8_t x);            /* MoveShip $54A1, x = ship 0/1     */
void    shipfriction(uint8_t x, int carry); /* Shipfriction $55C6            */
uint8_t out_range(uint8_t a);            /* OutRange $560D: clamp to +-$3F   */
void    dorigid(void);                   /* Dorigid $57CE (move the pair)    */
/* CheckForRocksNearby $5916 / ShipDeadSoWill $5918: x = ship 0/1, y = the
 * highest object to scan.  Returns the 6502 A on exit (= Y+1 from L_90):
 * zero means the area is clear (the callers test it with BNE). */
uint8_t check_for_rocks_nearby(uint8_t x);
uint8_t ship_dead_so_will(uint8_t x, uint8_t y);

/* ---- wave / object start-up ($5968-$5BB8) ------------------------------ */
/* Newp2 $5977 (place a new rock).  Returns the 6502 Y it leaves: on the
 * SAUMIN path (the only one attract takes) that is x & $0F, which
 * NewastStartNewAsteroids_10's next pass feeds to L80RandomWave0 ($6FDF
 * STY NOBJ).  On the GetNewVelocity path Y is untouched. */
uint8_t newp2(uint8_t x, uint8_t y);
void    newast_start_new_asteroids(void);/* NewastStartNewAsteroids $59C0    */
void    reset_enemy_timers(void);        /* ResetEnemyTimers $5AC6           */
void    copy_attributes_of_rock(uint8_t x, uint8_t y); /* $5B2B              */
void    new_random_velocity_using(uint8_t x, uint8_t y); /* $5B5E            */
uint8_t min_velocity(uint8_t a);         /* MinVelocity $5BA1                */

/* ---- shields + score area ($5BB9-$5C7F) -------------------------------- */
void    process_shields(void);           /* ProcessShields $5BB9             */
uint8_t twin_game_both_shields(uint8_t x); /* TwinGameBothShields $5BE9:
                                            * returns the 6502 Y (the shield
                                            * switch byte; bit 7 = pushed)   */
void    game23_shields(uint8_t x);       /* Game23Shields $5BFD              */
void    temp3_which_player0(uint8_t a);  /* Temp3WhichPlayer0 $5C24          */

/* ---- killer-mine start-up ($672C) -------------------------------------- */
void    initiate_killer_mine(void);      /* InitiateKillerMine $672D         */

/* ---- const tables (objects_data.c, by tools/gen_objects_data.py) ------- */
extern const uint8_t obj_coll_tab[0x45];      /* $448B collision radii/scan  */
extern const uint8_t obj_owner_tab[0x0F];     /* $4592 shot owner            */
extern const uint8_t obj_comet_table[0x02];   /* $472C CometTable            */
extern const uint8_t obj_angleshoot[0x02];    /* $4B72 AngleShoot            */
extern const uint8_t obj_saucer_tab[0x12];    /* $4C5E saucer speeds/slots   */
extern const uint8_t obj_fire_idx[0x09];      /* $4D6B torpedo slot windows  */
extern const uint8_t obj_clearsaucer[0x02];   /* $53FB saucer obj -> 0/1     */
extern const uint8_t obj_entdwarf[0x20];      /* $5154 onslaught counts      */
extern const uint8_t obj_initpos_m1[0x10];    /* $5967 rock start X, base-1  */
extern const uint8_t obj_wave_tab[0x14];      /* $5BA5 per-wave ramp         */
extern const uint8_t obj_rock_points[0x04];   /* $6611 SplitRockIntoFragments_110
                                               * points per new size; [3] is
                                               * the unreachable code byte   */
extern const uint8_t obj_toggles[0x08];       /* $6CCD LASTSW/$51 seeds      */
extern const uint8_t obj_km_tab[0x36];        /* $6CD9 killer-mine ramps     */

#endif /* OBJECTS_H */
