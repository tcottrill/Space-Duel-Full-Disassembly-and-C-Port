/* objects.c - Space Duel C port: objects / physics / enemies.
 *
 * ROM $43B7-$4CB4, $4F1C-$4FED, $50D5-$50F9, $5154-$5C7F, $672C-$67AA.
 * This is the game itself: the collision matrix, killer mines, saucer
 * entry and fire control, ship torpedoes, the per-frame motion integrator
 * (Moti20), ship thrust/friction, the two-ship tug-of-war bar, wave
 * start-up and the shields.  Attract mode plays a real demo game, so all
 * of it runs on the oracle path.
 *
 * The object model (see NOTES_objects.md): 48 slots, index $00-$2F.  Every
 * slot has a status/picture byte at $97+n (0 = free, positive = alive and
 * = the picture code, negative = an exploding/animating countdown), a
 * 16-bit position OBJXL/OBJXH ($320/$2B5) + OBJYL/OBJYH ($352/$2E7) and a
 * signed velocity XINC/YINC ($200/$232).  Slots:
 *
 *     $00        the velocity seed for new rocks ("lowest rock")
 *     $01-$10    rocks / asteroids
 *     $11-$18    comets and dwarfs
 *     $19-$1E    killer mines (6)
 *     $1F-$20    saucers 0 and 1
 *     $21-$22    player ships 0 and 1
 *     $23        the connecting rod / pair centre
 *     $24-$27    player-0 mines, $28-$2B player-0 torpedoes,
 *     $2C-$2F    player-1 torpedoes; saucer torpedoes reuse $24-$27
 *                through StartingValues/StoppingValues (see fire3)
 *
 * Register protocols are derived from all call sites and documented above
 * each function; 6502 X is nearly always the object index, so it is an
 * explicit parameter, and routines that talk through the carry/zero flag
 * return int.  Every RAM store the ROM makes is reproduced, scratch cells
 * included, because the oracle diffs the whole 1 KB.
 */
#include "sd_state.h"
#include "sd_hw.h"
#include "sd_vecrom.h"
#include "vgutil.h"
#include "lowones.h"
#include "sound.h"
#include "objects.h"

/* ================================================================== */
/* 6502 arithmetic helpers - flag-exact, carry passed explicitly       */
/* ================================================================== */

static uint8_t adc8(uint8_t a, uint8_t m, int *c)
{
    unsigned t = (unsigned)a + (unsigned)m + (unsigned)(*c & 1);
    *c = (int)((t >> 8) & 1u);
    return (uint8_t)t;
}

static uint8_t sbc8(uint8_t a, uint8_t m, int *c)
{
    unsigned t = (unsigned)a + (unsigned)(uint8_t)(~m) + (unsigned)(*c & 1);
    *c = (int)((t >> 8) & 1u);
    return (uint8_t)t;
}

static uint8_t asl8(uint8_t a, int *c)
{
    *c = (a >> 7) & 1;
    return (uint8_t)(a << 1);
}

static uint8_t lsr8(uint8_t a, int *c)
{
    *c = a & 1;
    return (uint8_t)(a >> 1);
}

static uint8_t rol8(uint8_t a, int *c)
{
    int out = (a >> 7) & 1;
    a = (uint8_t)((a << 1) | (*c & 1));
    *c = out;
    return a;
}

static uint8_t ror8(uint8_t a, int *c)
{
    int out = a & 1;
    a = (uint8_t)((a >> 1) | ((*c & 1) << 7));
    *c = out;
    return a;
}

/* The ROM's arithmetic-shift-right idiom: CMP #$80 (C = sign) / ROR. */
static uint8_t asr8(uint8_t a, int *c)
{
    *c = (a >= 0x80);
    return ror8(a, c);
}

#define CMP8(a, m, cp)  (*(cp) = ((a) >= (m)))
#define NEG(v)          (((v) & 0x80) != 0)
#define VROM(addr)      (sd_vecrom[(addr) - SD_VECROM_BASE])

/* ================================================================== */
/* object arrays and the ROM's base-offset const-table addressing      */
/* ================================================================== */

/* Object status / picture byte: the ROM writes `STA $97,X` (zp,X) and
 * `STA $0097,Y` (abs,Y) for the same cell.  $97 + $19..$1E = $B0..$B5 (the
 * killer mines), + $1F/$20 = $B6/$B7 (the saucer-active cells sound.c
 * knows), + $21/$22 = $B8/$B9 (the ships), + $23 = $BA (the rod). */
#define OST(i)  (g.ram[0x97 + (uint8_t)(i)])
#define OXL(i)  (g.ram[A_OBJXL + (uint8_t)(i)])
#define OXH(i)  (g.ram[A_OBJXH + (uint8_t)(i)])
#define OYL(i)  (g.ram[A_OBJYL + (uint8_t)(i)])
#define OYH(i)  (g.ram[A_OBJYH + (uint8_t)(i)])
#define OVX(i)  (g.ram[A_XINC  + (uint8_t)(i)])
#define OVY(i)  (g.ram[A_YINC  + (uint8_t)(i)])

/* Const tables are indexed by the ROM's own absolute address, because
 * several fetches use a base that lies *before* the table and an object
 * index that lands inside it (e.g. `LDA $447A,X` with X = $21..$2F really
 * reads $449B..$44A9, and `LDA $44A9,Y` with Y = 0..7 runs off the end of
 * CollisionDetector_112 into _115 and _125). */
#define COLL(addr)    (obj_coll_tab[(addr) - 0x448B])
#define OWNTAB(addr)  (obj_owner_tab[(addr) - 0x4592])
#define SAUT(addr)    (obj_saucer_tab[(addr) - 0x4C5E])
#define FIREI(addr)   (obj_fire_idx[(addr) - 0x4D6B])
#define CLRSAU(addr)  (obj_clearsaucer[(addr) - 0x53FB])
#define ENTDW(addr)   (obj_entdwarf[(addr) - 0x5154])
#define INITPOS(addr) (obj_initpos_m1[(addr) - 0x5967])
#define WAVET(addr)   (obj_wave_tab[(addr) - 0x5BA5])
#define TOGT(addr)    (obj_toggles[(addr) - 0x6CCD])
#define KMT(addr)     (obj_km_tab[(addr) - 0x6CD9])

/* ================================================================== */
/* cross-module externs (label + ROM address; the orchestrator folds    */
/* these into headers - see NOTES_objects.md "Externs")                 */
/* ================================================================== */

/* PartSignedNumberExit ($67D0): the signed arctangent (lowones.c).  in
 * x = the X (denominator) difference, y = the Y (numerator) difference;
 * out A = the angle, 256 units per circle. */
extern uint8_t part_signed_number_exit(uint8_t x, uint8_t y);
/* InitializeComet ($6B68): reads WHITE = which player gets the comet, and
 * RETURNS the 6502 X it leaves - $4A9C is a JMP, so that X is
 * CompetitiveWantWaitOther's own exit X (mainline.c). */
extern uint8_t initialize_comet(void);
/* Expset ($623E): seed the explosion pieces of object x.  NOTE: display.c
 * currently defines this `static` - it must lose the `static`. */
extern void expset(uint8_t x);
/* AddPointsToScore ($5F68): a = the score value (score module). */
extern void add_points_to_score(uint8_t a);
/* AmountAddRoutineLimits ($67B6): a = the amount added to the 16-bit
 * onslaught timer LNGTIMER/$3BA, saturating at $03FF (display.c). */
extern void amount_add_routine_limits(uint8_t a);
/* Gtoptn ($76DB): read the option switches (mainline.c). */
extern void gtoptn(void);
/* Inset2 ($4FEE): ScoreColorBasedAbove + Inisou + InitializeScoreHeadings;
 * Initialization ($4F66) falls straight into it (display.c). */
extern void inset2(void);
/* Pictur ($5D6D): draw object x's picture (display.c). */
extern void pictur(uint8_t x);

/* ---- forward declarations for this module's internal routines ------ */
static void    destruction_during_collision(uint8_t x, uint8_t y);
static void    dstr60(uint8_t x, uint8_t y);
static void    check_shield_condition_possibly(uint8_t x, uint8_t y);
static void    destroy_x_ship(uint8_t x, uint8_t y);
static void    retarget_comets(uint8_t x);
static void    back_away_from_collision(uint8_t x);
static void    collision_bounce(uint8_t x, uint8_t y);
static void    switch_velocities(uint8_t x, uint8_t y);
static uint8_t numerator_atan(uint8_t a_ydiff, uint8_t xdiff);
static uint8_t efire3(uint8_t x);
static uint8_t start_looking_here(uint8_t x);
static void    fire_ships_torpedos_20(uint8_t x);
static void    reset_saucer_values(uint8_t x);
static void    clear_saucer(uint8_t a, uint8_t x);
static uint8_t entry_no_requirements_exit(void);
static void    reverse_travel_velocity(uint8_t x);
static void    revxship(uint8_t x);
static void    reverse_angular_momentum(void);
static void    possible_reverse_x_velocity(void);
static void    prevybar(void);
static void    drop_shields_wall_hit(void);
static void    will_assume_radius_bar(uint8_t x);
static uint8_t thrust_two_ships(uint8_t x);
static void    dorig3(void);
static void    get_new_velocity(uint8_t x, uint8_t y);
static void    initiaize_pair(void);
static void    newship(uint8_t x);
static uint8_t positive_resulults(uint8_t a);
static uint8_t searc1(uint8_t x);
static uint8_t search_for_free_rock(void);
void split_rock_into_fragments(void);        /* SplitRockIntoFragments $6554 */

/* ================================================================== */
/* CollisionDetector ($43B7) and its consequences                      */
/* ================================================================== */

/* CollisionDetector ($43B7): the collision matrix.  X walks the
 * "aggressor" slots $2F down to $21 (torpedoes, mines, ships); for each
 * live one, Y walks a per-object start index taken from
 * CollisionDetector_125 ($44AE, co-operative) or _126 ($44BF, competitive,
 * chosen when $34 == 0) down to 0.  Radii come from CollisionDetector_112
 * ($449B) for objects >= $11 and from the size-indexed run at $44A9 for
 * rocks; the test is a box test on the halved 16-bit differences plus a
 * "chop off the corners" |dx|+|dy| test against 3/2 of the radius sum.
 * No inputs, no outputs; XCOMP/FOURPI carry X/Y across the
 * DestructionDuringCollision call, exactly as the ROM does. */
void collision_detector(void)
{
    uint8_t x = 0x2F, y = 0, a, r;
    int c;

    for (;;) {
        /* L43B9 CollisionDetector_10 */
        a = OST(x);
        if (a == 0 || NEG(a))
            goto next_x;                        /* _13: inactive/exploding */

        /* L43C5 _16: pick this object's scan start */
        y = ZP_34 ? COLL(0x448F + x) : COLL(0x44A0 + x);

    s19:                                        /* L43CF _19 */
        y--;
        if (NEG(y))
            goto next_x;
        a = OST(y);
        if (a == 0 || NEG(a))
            goto s19;                           /* inactive / an explosion */

        /* L43D9: coarse box test on the high bytes, +-3 slack */
        c = 1;
        a = sbc8(OXH(y), OXH(x), &c);
        a = sbc8(a, 0x03, &c);
        CMP8(a, 0xFA, &c);
        if (!c) goto s19;                       /* too far in X            */
        a = sbc8(OYH(y), OYH(x), &c);
        a = sbc8(a, 0x03, &c);
        CMP8(a, 0xFA, &c);
        if (!c) goto s19;                       /* too far in Y            */

        /* L43F2: |dx| / 2 into WHITE (the carry chain continues) */
        WHITE = sbc8(OXL(y), OXL(x), &c);
        a = sbc8(OXH(y), OXH(x), &c);
        a = lsr8(a, &c);
        WHITE = ror8(WHITE, &c);                /* divided by 2            */
        a = asl8(a, &c);                        /* reset the zero flag     */
        if (a != 0) {                           /* BEQ _32 = within 64     */
            if ((uint8_t)(a ^ 0xFE) != 0)
                goto s19;                       /* too far away            */
            WHITE = (uint8_t)(WHITE ^ 0xFF);    /* distance from torpedo   */
        }

        /* L4410 _32: |dy| / 2 into EACE */
        c = 1;
        EACE = sbc8(OYL(y), OYL(x), &c);
        a = sbc8(OYH(y), OYH(x), &c);
        a = lsr8(a, &c);
        EACE = ror8(EACE, &c);
        a = asl8(a, &c);
        if (a != 0) {                           /* BEQ _35 = within 64     */
            if ((uint8_t)(a ^ 0xFE) != 0)
                goto s19;
            EACE = (uint8_t)(EACE ^ 0xFF);      /* distance-1 from torpedo */
        }

        /* L442F _35: the sum of the two radii */
        if (y < 0x11) {                         /* a rock: radius by size  */
            FOURPI = y;
            r = COLL(0x44A9 + (OST(y) & 0x07));
            /* LDY FOURPI / BPL _65: always taken (FOURPI < $11)           */
        } else {
            r = COLL(0x447A + y);               /* _45                     */
        }
        c = 0;                                  /* _65: CLC                */
        a = adc8(r, COLL(0x447A + x), &c);

        /* L4449 _70 */
        CMP8(a, WHITE, &c);
        if (!c) goto s19;                       /* no hit                  */
        CMP8(a, EACE, &c);
        if (!c) goto s19;
        POKRAN = a;
        a = lsr8(a, &c);
        c = 0;
        a = adc8(a, POKRAN, &c);
        POKRAN = a;                             /* 3/2 distance            */
        POTGO = adc8(0x00, 0x00, &c);           /* its upper byte          */

        /* L445F _72: |dx| + |dy| vs that (chops the corners off) */
        WHITE = adc8(EACE, WHITE, &c);          /* the carry is clear here */
        EACE = adc8(0x00, 0x00, &c);
        CMP8(POKRAN, WHITE, &c);                /* sets C for the 16-bit   */
        (void)sbc8(POTGO, EACE, &c);
        if (!c) goto s19;                       /* a miss on the object    */

        XCOMP = x;                              /* L4475                   */
        FOURPI = y;
        destruction_during_collision(x, y);
        y = FOURPI;
        x = XCOMP;
        a = OST(x);                             /* still active? (shields) */
        if (a == 0 || NEG(a))
            y = 0x00;                           /* _78: restart with a new X */
        goto s19;                               /* _80                     */

    next_x:                                     /* L43BF _13               */
        x--;
        if (x == 0x20)
            return;                             /* _14: stop at ship 0     */
    }
}

/* DestructionDuringCollision ($44D0): object x (a torpedo, mine or ship)
 * hit object y.  XCOMP = x and FOURPI = y are already staged by the
 * caller and are how x/y survive the nested calls.  OWNER ($38E) is
 * loaded from ValueOwnershipNegativeNobody ($4571,X). */
static void destruction_during_collision(uint8_t x, uint8_t y)
{
    uint8_t a, xs;
    int c;

    OWNER = OWNTAB(0x4571 + x);                 /* L44D0                   */
    if (x < 0x24) {                             /* not a mine: a shot      */
        dstr60(x, y);
        return;
    }

    /* L44DD _15 */
    OST(x) = 0x00;                              /* clear the shot          */
    if (y < 0x19) {
        split_rock_into_fragments();            /* (exit point)            */
        return;
    }
    if (y < 0x1F) {                             /* _30: a killer mine      */
        g.ram[0x0266 + y] = 0x00;               /* KSPEED: current speed   */
        OVX(y) = 0x00;                          /* idle move               */
        OVY(y) = 0x00;                          /* idle mine               */
        c = 0;                                  /* CPY #$1F left C clear   */
        a = adc8(g.ram[0x00B0 + y], 0x01, &c);  /* $C9+: one more shot     */
        g.ram[0x00B0 + y] = a;
        CMP8(a, 0x08, &c);
        if (c) {                                /* ready to die            */
            OST(y) = 0x00;
            add_points_to_score(0x10);          /* 100 points              */
            /* X/Y here are AddPointsToScore's leftovers - see NOTES       */
            explosion(x, y);
            initiate_killer_mine();             /* restart another         */
            x = XCOMP;
            y = FOURPI;
        }
        /* L4517 _35: shove the victim along by the shot's velocity        */
        a = OVX(x);
        xs = NEG(a) ? 0xFF : 0x00;              /* LDX #$00 / DEX          */
        c = 0;                                  /* _47: CLC                */
        OXL(y) = adc8(a, OXL(y), &c);
        OXH(y) = adc8(xs, OXH(y), &c);
        x = XCOMP;
        a = OVY(x);
        xs = NEG(a) ? 0xFF : 0x00;
        c = 0;                                  /* _49: CLC                */
        OYL(y) = adc8(a, OYL(y), &c);
        OYH(y) = adc8(xs, OYH(y), &c);
        return;                                 /* _55                     */
    }

    if (y >= 0x21) {                            /* _60: a ship             */
        c = 1;                                  /* _63                     */
        a = sbc8(y, 0x21, &c);
        if (a == OWNER)
            return;                             /* his own shot            */
        check_shield_condition_possibly(FOURPI, y);
        return;
        /* L455C-L4565 is unreachable (jumped over by the JMP above) - a
         * second "who's shot was this" test nothing branches to. */
    }

    /* _65: y was a saucer.  Mines $24-$27 do nothing; $28+ kill it. */
    if (x >= 0x28 || x < 0x24) {
        SUPRSAC = 0x00;                         /* _66: no super saucer    */
        up_the_difficulty();                    /* _70                     */
        kill_x_saucer(FOURPI);                  /* (exit point)            */
    }
    /* _67: RTS */
}

/* Dstr60 ($457D): object x was a ship or the rod ($21-$23) rather than a
 * shot.  y < $21 hands off to the shield check; otherwise both objects
 * back out of each other and swap velocities. */
static void dstr60(uint8_t x, uint8_t y)
{
    if (y < 0x21) {                             /* rock/killer mine/saucer */
        check_shield_condition_possibly(x, y);
        return;
    }
    back_away_from_collision(x);
    back_away_from_collision(FOURPI);           /* the Y collision object  */
    switch_velocities(FOURPI, XCOMP);           /* bounce the two ships    */
}

/* CheckShieldConditionPossibly ($45A1): x = the ship object ($21/$22, or
 * $23 when the rod is involved), y = what it hit.  Shields up (or still
 * entering) costs shield energy and bounces; shields down destroys the
 * ship.  COLLIS ($38A,ship) remembers the last thing bounced off so the
 * same pair does not bounce twice. */
static void check_shield_condition_possibly(uint8_t x, uint8_t y)
{
    uint8_t a;
    int c;

    if (g.ram[0x03C6 + x] == 0) {               /* ENTER,ship: entering?   */
        if (!(g.ram[0x2E + x] & 0x80)) {        /* $4F/$50: shields on?    */
            destroy_x_ship(x, y);               /* shields were not on     */
            return;
        }
        c = 1;
        if (ZP_34 >= 0x02)                      /* games 2&3 last longer   */
            a = sbc8(g.ram[0x0252 + x], 0x0C, &c);
        else
            a = sbc8(g.ram[0x0252 + x], 0x18, &c);   /* _10                */
        CMP8(a, 0x18, &c);                      /* _20                     */
        if (!c) a = 0x00;
        g.ram[0x0252 + x] = a;                  /* _50: SHLDENG,ship       */
    }

    /* L45CA _51 */
    y = FOURPI;
    TEMP5 = (uint8_t)(g.ram[0x0369 + x] & 0x7F);     /* the old object     */
    g.ram[0x0369 + x] = y;                           /* the new one        */
    if (y == TEMP5)
        return;                                 /* _90: do not bounce again */
    if (NEG(LASTSW)) {                          /* the pair                */
        x = 0x23;
        reverse_angular_momentum();
    }
    collision_bounce(x, y);                     /* _60                     */
}

/* DestroyXShip ($45E8): x = the ship, y = what killed it (the live 6502 Y
 * at entry = the collision object).  WHITE keeps x across the nested
 * calls ("for COMOWAY"). */
static void destroy_x_ship(uint8_t x, uint8_t y)
{
    uint8_t a;
    int c;
    int to_62 = 0, to_61 = 0, to_80 = 0;

    WHITE = x;
    explosion(x, y);                            /* explosion sound         */
    OST(x) = 0xA0;                              /* full explosion length   */
    if (NEG(LASTSW)) {                          /* combined lives          */
        if (!NEG(g.ram[0x0367 + x])) {          /* PRTDAMAGE: damaged?     */
            y = FIREI(0x4D51 + x);              /* the other ship's index  */
            if (!NEG(g.ram[0x0367 + y])) {
                g.ram[0x0367 + x]--;            /* damage it               */
                g.ram[0x03CE + x] = 0xB8;       /* EXPDEC: partial count   */
                OST(x) = 0xB8;
                expset(x);                      /* init the pieces         */
                to_62 = 1;
            }
        }
        if (!to_62) {                           /* _98                     */
            g.ram[0x03CE + x] = 0x00;           /* only pieces             */
            if (!NEG(SPARKTIME)) {
                to_80 = 1;                      /* already started dying   */
            } else {
                SPARKTIME--;                    /* start the sparkle       */
                to_61 = 1;                      /* BNE _61 (always)        */
            }
        }
    } else {                                    /* _60                     */
        if (ZP_34 >= 0x02)
            to_61 = 1;
        else
            to_62 = 1;                          /* games 0 & 1 skip this   */
    }

    if (to_61) {                                /* _61                     */
        if (NEG(SAUMIN)) {
            to_62 = 1;                          /* skip if blocks too      */
        } else {
            x = 0x20;
            for (;;) {                          /* _66                     */
                if (OST(x) != 0) {
                    OVX(x) = min_velocity(OVX(x));
                    OVY(x) = min_velocity(OVY(x));
                }
                if (x == 0) break;              /* _68: DEX / BPL          */
                x--;
            }
            x = WHITE;
            g.ram[0x53] = 0xFF;                 /* $53: rocks off screen   */
            to_80 = 1;                          /* BNE _80 (always)        */
        }
    }

    if (to_62 && !to_80) {                      /* L464E _62               */
        y = XCOMP;                              /* the original collision X */
        CMP8(y, 0x28, &c);
        if (c) {
            OST(x) = 0xE0;                      /* start the flashing time */
            g.ram[0x03CE + x] = 0xE0;           /* only flash              */
            expset(x);
            x = WHITE;
            a = 0x50;                           /* full ship value         */
            if (NEG(g.ram[0x0367 + x]))
                a = 0x25;                       /* crippled ship value     */
            add_points_to_score(a);             /* _63                     */
            x = WHITE;
            a = 0xFF;
        } else {                                /* _65                     */
            a = 0x00;
            g.ram[0x0367 + x]--;
            if (!NEG(g.ram[0x0367 + x]))
                g.ram[0x0367 + x]++;            /* hold at the limit       */
        }
        g.ram[0x039A + x] = a;                  /* _75: WHOSHOT,ship       */
    }

    /* L467F _80 */
    g.ram[0x024C + x] = 0xA0;                   /* SDELAY,ship             */
    retarget_comets(x);                         /* point his at the other  */
    /* _90: LDY FOURPI (a register load only) */
    split_rock_into_fragments();                /* (exit)                  */
}

/* GetCometToGo ($468C): flag every comet "die at the edge of the screen"
 * and, outside the two-fighter game, set COMOFF = one ship has died. */
void get_comet_to_go(void)
{
    uint8_t y = 0x07;
    for (;;) {
        g.ram[A_COMTYP + y] |= 0x01;            /* the die-at-edge bit     */
        if (y == 0) break;
        y--;
    }
    if (ZP_34 != 0)
        COMOFF = 0xFF;                          /* one ship has died       */
}

/* RetargetComets ($46A3): x = the ship object that just died.  Every live
 * comet is retargeted at `x EOR 1` - note that with the ships at $21/$22
 * this produces $20/$23 (saucer 1 / the rod), not the other ship;
 * reproduced as coded (NOTES_objects.md, open question 3). */
static void retarget_comets(uint8_t x)
{
    uint8_t y = 0x07;
    x = (uint8_t)(x ^ 0x01);                    /* point at the other      */
    for (;;) {
        if (g.ram[A_CTARGET + y] != 0)
            g.ram[A_CTARGET + y] = x;
        if (y == 0) break;
        y--;
    }
}

/* Updif3 ($46E8), AloneGame1Player ($472E), Updif5 ($477C) and
 * TwinGame1Player ($47B8) are the four per-game difficulty ramps that
 * UpTheDifficulty's PHA/PHA/RTS dispatch (DifficultyTableLo/Hi $46B6/$46BA)
 * selects with Y = $34.  x = OWNER; WHITE/EACE hold the 16-bit total hit
 * count of both players. */
static void updif3(uint8_t x)
{
    int c;
    uint8_t a;

    if (g.ram[A_UMONHITS + x] != 0 || g.ram[A_LMONHITS + x] >= 0x20) {
        g.ram[A_PROBCOMET + x]++;               /* _20                     */
        if (NEG(g.ram[A_PROBCOMET + x]))
            g.ram[A_PROBCOMET + x]--;           /* hold at $7F             */
    }
    /* _30 */
    if (g.ram[A_UMONHITS + x] == 0 &&
        (g.ram[A_LMONHITS + x] & 0x07) == 0) {
        g.ram[A_DWFRMP + x]++;                  /* _35                     */
        if (NEG(g.ram[A_DWFRMP + x]))
            g.ram[A_DWFRMP + x]--;              /* max is $80              */
    }
    /* _50 */
    if (g.ram[A_LMONHITS + x] == 0x03)
        g.ram[A_COMSTART + x] = obj_comet_table[x];
    /* _60: LDA LMONHITS / ADC LMONHITS - the ROM adds $03D2 to itself
     * ("total hits between them"); reproduced literally. */
    c = 0;
    a = adc8(LMONHITS, LMONHITS, &c);
    if ((a & 0x07) == 0)
        COMLIMIT++;                             /* every 8 hits, harder    */
}

static void alone_game1_player(uint8_t x)
{
    uint8_t a;
    int bump = 0;

    if (g.ram[A_UMONHITS + x] != 0) {
        bump = 1;
    } else {
        a = g.ram[A_LMONHITS + x];
        if (a >= 0x20 && (a & 0x01) == 0)
            bump = 1;                           /* 1 of 2 after $20        */
    }
    if (bump) {
        g.ram[A_PROBCOMET + x]++;               /* _20                     */
        if (NEG(g.ram[A_PROBCOMET + x]))
            g.ram[A_PROBCOMET + x]--;
    }
    /* _30 */
    if (g.ram[A_UMONHITS + x] == 0 &&
        (g.ram[A_LMONHITS + x] & 0x07) == 0) {
        g.ram[A_DWFRMP + x]++;
        if (NEG(g.ram[A_DWFRMP + x]))
            g.ram[A_DWFRMP + x]--;              /* don't let past $80      */
    }
    /* _50 */
    a = g.ram[A_LMONHITS + x];
    if (a == 0x04 || a == 0x0F || a == 0x19) {  /* _58                     */
        COMSTART++;
        COMLIMIT++;
    }
    /* _60/_65: the ROM's last test (UMONHITS/LMONHITS vs $28) reaches an
     * RTS either way - no effect, so nothing is emitted for it. */
}

static void updif5(uint8_t x)
{
    if (EACE != 0 || WHITE >= 0x20) {
        g.ram[A_PROBCOMET + x]++;               /* _20                     */
        if (NEG(g.ram[A_PROBCOMET + x]))
            g.ram[A_PROBCOMET + x]--;
    }
    /* _30 */
    if (EACE != 0 || (WHITE >= 0x10 && (WHITE & 0x0F) == 0)) {
        g.ram[A_DWFRMP + x]++;                  /* _35                     */
        if (NEG(g.ram[A_DWFRMP + x]))
            g.ram[A_DWFRMP + x]--;              /* don't let past $80      */
    }
    /* _50 */
    if (EACE == 0 && (WHITE & 0x0F) == 0) {     /* every 16 hits...        */
        COMLIMIT++;                             /* ...get harder           */
        g.ram[0x03B5]++;                        /* BCOMSTART+1             */
        BCOMSTART++;
    }
}

/* carry: TwinGame1Player_60's BCC reads the carry the last CMP executed
 * left - and when EACE != 0 skipped every CMP, the carry
 * UpTheDifficulty's `ADC $03D5` produced. */
static void twin_game1_player(uint8_t x, int c)
{
    uint8_t a;

    if (EACE != 0 || WHITE >= 0x20) {
        g.ram[A_PROBCOMET + x]++;               /* _20                     */
        if (NEG(g.ram[A_PROBCOMET + x]))
            g.ram[A_PROBCOMET + x]--;
    }
    /* _30 */
    if (EACE != 0 || (WHITE >= 0x10 && (WHITE & 0x0F) == 0)) {
        g.ram[A_DWFRMP + x]++;                  /* _35                     */
        if (NEG(g.ram[A_DWFRMP + x]))
            g.ram[A_DWFRMP + x]--;
    }
    /* _50: with EACE == 0 the CMP chain runs and leaves C = WHITE >= $25 */
    if (EACE == 0) {
        a = WHITE;
        if (a == 0x07) {
            g.ram[0x03B5]++;
            COMLIMIT++;
        }
        if (a == 0x0F) {                        /* _54                     */
            BCOMSTART++;
            COMLIMIT++;
        }
        if (a == 0x25) {                        /* _58 / _59               */
            g.ram[0x03B5]++;
            COMLIMIT++;
        }
        CMP8(a, 0x25, &c);
    }
    /* _60 */
    if (c && (WHITE & 0x07) == 0) {             /* above the last limit    */
        COMLIMIT++;
        g.ram[0x03B5]++;
        BCOMSTART++;
    }
}

/* UpTheDifficulty ($46BE): OWNER named a player, so bump his hit counters
 * (the LMONHITS/UMONHITS pairs at $3D2/$3D4) and run that game's ramp. */
void up_the_difficulty(void)
{
    uint8_t x = OWNER;
    int c;

    if (NEG(x))
        return;                                 /* nobody owns it          */
    g.ram[A_LMONHITS + x]++;                    /* _10                     */
    if (g.ram[A_LMONHITS + x] == 0)
        g.ram[A_UMONHITS + x]++;
    /* _20: the 16-bit total of both players' hits into WHITE/EACE */
    c = 0;
    WHITE = adc8(LMONHITS, g.ram[0x03D3], &c);
    EACE = adc8(UMONHITS, g.ram[0x03D5], &c);
    switch (ZP_34) {                            /* the PHA/PHA/RTS jump    */
    case 0:  updif3(x);               break;    /* $46E8                   */
    case 1:  alone_game1_player(x);   break;    /* $472E                   */
    case 2:  updif5(x);               break;    /* $477C                   */
    default: twin_game1_player(x, c); break;    /* $47B8                   */
    }
}

/* BackAwayFromCollision ($4816): step object x back along its own
 * velocity (X wraps into the $00-$1F screen, Y clamps at top/bottom).
 * Quirk kept: the Y half only clears the carry on the negative branch, so
 * a zero YINC adds an extra 1 (Comp leaves C set when A == 0). */
static void back_away_from_collision(uint8_t x)
{
    uint8_t a, ys;
    int c;

    a = comp(OVX(x));
    ys = NEG(a) ? 0xFF : 0x00;
    c = 0;                                      /* _10: CLC                */
    OXL(x) = adc8(a, OXL(x), &c);
    a = adc8(ys, OXH(x), &c);
    OXH(x) = (uint8_t)(a & 0x1F);               /* the screen limit        */

    a = OVY(x);
    c = (a == 0);                               /* the carry out of Comp   */
    a = comp(a);
    ys = 0x00;
    if (NEG(a)) { ys = 0xFF; c = 0; }           /* DEY / CLC               */
    OYL(x) = adc8(a, OYL(x), &c);               /* _20                     */
    a = adc8(ys, OYH(x), &c);
    if (NEG(a))
        a = 0x17;                               /* _50: went below bottom  */
    else if (a >= 0x18)
        a = 0x00;
    OYH(x) = a;                                 /* _60                     */
}

/* CollisionBounce ($4857): x = the shielded ship, y = what it hit.  Swaps
 * the velocities, forces a minimum separation speed and, for comets and
 * killer mines, recomputes the travel angle ($0282,Y = CANGLH/KANGLH) and
 * quarters the angle-change rate ($0274,Y). */
static void collision_bounce(uint8_t x, uint8_t y)
{
    uint8_t a;
    int c;

    if (y >= 0x21)
        return;                                 /* _91: no bounce          */
    if (NEG(SUPRSAC) && y == 0x20)
        y--;                                    /* pretend control saucer  */

    switch_velocities(x, y);                    /* _10                     */
    a = OVX(y);
    if (a < 0x04 || a >= 0xFD) {                /* _20                     */
        CMP8(OXL(x), OXL(y), &c);
        (void)sbc8(OXH(x), OXH(y), &c);
        OVX(y) = c ? 0xFD : 0x03;               /* _30                     */
    }
    /* _50 */
    a = OVY(y);
    if (a < 0x04 || a >= 0xFD) {                /* _55                     */
        CMP8(OYL(x), OYL(y), &c);
        (void)sbc8(OYH(x), OYH(y), &c);
        OVY(y) = c ? 0xFD : 0x03;               /* _60                     */
    }
    /* _80 */
    if (y >= 0x1F || y < 0x11)
        return;                                 /* saucers keep the angle  */
    TEMP2 = x;                                  /* remember the entering X */
    a = part_signed_number_exit(OVX(y), OVY(y));
    /* LDX TEMP2 restores X, which nothing downstream reads */
    y = FOURPI;
    g.ram[0x0282 + y] = a;                      /* CANGLH/KANGLH           */
    if (y >= 0x19)
        return;
    g.ram[0x0274 + y] = (uint8_t)(g.ram[0x0274 + y] >> 2);   /* CANGCH     */
}

/* SwitchVelocities ($48D0): exchange XINC/YINC between objects x and y. */
static void switch_velocities(uint8_t x, uint8_t y)
{
    uint8_t t;
    t = OVX(x); OVX(x) = OVX(y); OVX(y) = t;
    t = OVY(x); OVY(x) = OVY(y); OVY(y) = t;
}

/* NumeratorAtan ($492E): the shared tail - A holds the Y difference and
 * the X difference is the byte the caller pushed. */
static uint8_t numerator_atan(uint8_t a_ydiff, uint8_t xdiff)
{
    return part_signed_number_exit(xdiff, a_ydiff);
}

/* GetWrapAroundAngle ($48ED): like FindDifferenceCoordinates, but the
 * difference wraps around the $20 x $18 playfield (with 3 / 2 units of
 * hysteresis) so a chaser takes the short way round the edge.
 * in x = the chaser, y = the target; out A = the angle. */
uint8_t get_wrap_around_angle(uint8_t x, uint8_t y)
{
    uint8_t dx, dy;
    int c;

    c = 1;
    dx = sbc8(OXH(y), OXH(x), &c);
    if (NEG(dx)) {                              /* _30                     */
        CMP8(dx, 0xED, &c);
        if (!c)
            dx = adc8(dx, 0x20, &c);            /* the carry was clear     */
    } else {
        CMP8(dx, 0x13, &c);                     /* 3 for hysteresis        */
        if (c)
            dx = sbc8(dx, 0x20, &c);            /* wrap around             */
    }
    /* _50: PHA */
    c = 1;
    dy = sbc8(OYH(y), OYH(x), &c);
    if (NEG(dy)) {                              /* _70                     */
        CMP8(dy, 0xF2, &c);
        if (!c)
            dy = adc8(dy, 0x18, &c);
    } else {
        CMP8(dy, 0x0E, &c);                     /* 2 for hysteresis        */
        if (c)
            dy = sbc8(dy, 0x17, &c);
    }
    return numerator_atan(dy, dx);              /* _80                     */
}

/* FindDifferenceCoordinates ($491F): out A = the arctan of the straight
 * line from object x to object y (high position bytes only). */
uint8_t find_difference_coordinates(uint8_t x, uint8_t y)
{
    uint8_t dx, dy;
    int c;

    c = 1;
    dx = sbc8(OXH(y), OXH(x), &c);              /* saved on the stack      */
    c = 1;
    dy = sbc8(OYH(y), OYH(x), &c);
    return numerator_atan(dy, dx);
}

/* ================================================================== */
/* killer mines and the enemy (saucer) controller                      */
/* ================================================================== */

/* KillerMines ($4937): one killer mine is steered per pass, chosen by the
 * frame counter - only when ($44 & 7) == 4 and (($44 & $3F) >> 3) < 6,
 * giving mine slot $19 + that value.  Falls into DoEnemy ($4934) either
 * way.  in x = the mainline's live 6502 X (returned unchanged on the
 * CompetitiveWantWaitOther_90 early-out); out the 6502 X on exit, which
 * MotionUpdateRoutine then indexes with. */
uint8_t killer_mines(uint8_t x)
{
    uint8_t a, y;
    int c;

    a = (uint8_t)(ZP_44 & 0x3F);                /* 1 of 7 mines max        */
    a = lsr8(a, &c);
    if (c) return competitive_want_wait_other(x);    /* even frames only   */
    a = lsr8(a, &c);
    if (c) return competitive_want_wait_other(x);    /* the bottom 2 bits  */
    a = lsr8(a, &c);
    if (!c) return competitive_want_wait_other(x);   /* and this bit 1     */
    CMP8(a, 0x06, &c);
    if (c) return competitive_want_wait_other(x);
    a = adc8(a, 0x19, &c);                      /* the carry is clear      */
    x = a;
    a = OST(x);
    if (a == 0 || NEG(a))                       /* dead / exploding comet  */
        return competitive_want_wait_other(x);
    XCOMP = x;
    y = g.ram[A_GTIME + x];                     /* KTARGET: ship to track  */
    return acc_holds_angle_object(x, y);
}

/* AccHoldsAngleObject ($4956): "ACC holds the angle to object Y to track
 * object X" - the arctan, then Klmi7.  Cross-module entry from the comet
 * module ($6C8D JMP, a tail call, so the return value is its exit X). */
uint8_t acc_holds_angle_object(uint8_t x, uint8_t y)
{
    return klmi7(find_difference_coordinates(x, y));
}

/* Klmi7 ($4959): steer object XCOMP toward angle a and rebuild its
 * velocity.  XCOMP < $19 = a comet (its COMTYP $037E bit 0 means "go
 * straight"), >= $19 = a killer mine (XINCL bit 7 = all mines leaving).
 * The turn rate comes from $0274,X (CANGCH/KANGCH) and is accumulated
 * into the 16-bit heading $0294,X / $0282,X (CANGLL/KANGLL +
 * CANGLH/KANGLH); the speed at $0266,X (CSPEED/KSPEED) ramps toward the
 * target speed in $97,X and multiplies cos/sin into XINC/YINC.
 * Cross-module entry from the comet module ($6C93 JMP).  Falls into
 * CompetitiveWantWaitOther, so it returns that routine's exit X. */
uint8_t klmi7(uint8_t a)
{
    uint8_t x = XCOMP, y;
    int c = 0, skip = 0;

    if (x >= 0x19) {                            /* _20                     */
        if (NEG(XINCL))
            skip = 1;                           /* mines going off screen  */
    } else {
        y = a;                                  /* TAY: store the angle    */
        (void)lsr8(g.ram[0x037E + x], &c);      /* COMTYP bit 0            */
        a = y;                                  /* TYA: restore it         */
        if (c)
            skip = 1;                           /* headed off              */
    }

    if (!skip) {                                /* _25                     */
        c = 1;
        a = sbc8(a, g.ram[0x0282 + x], &c);
        (void)asl8(a, &c);                      /* C set = ship on right   */
        a = g.ram[0x0274 + x];                  /* angle increment allowed */
        if (c) {
            int c2 = 1;                         /* EOR #$FF / ADC #$00     */
            a = adc8((uint8_t)(a ^ 0xFF), 0x00, &c2);
            c = c2;
        }
        /* _30: signed >> 2 into TEMP5:A - TEMP5's old bits shift through */
        a = asr8(a, &c);
        TEMP5 = ror8(TEMP5, &c);
        a = asr8(a, &c);
        TEMP5 = ror8(TEMP5, &c);
        y = a;                                  /* the upper byte          */
        c = 0;
        g.ram[0x0294 + x] = adc8(TEMP5, g.ram[0x0294 + x], &c);
        g.ram[0x0282 + x] = adc8(y, g.ram[0x0282 + x], &c);
    }

    /* L4996 _35: ramp the speed toward the target speed in $97,X */
    a = g.ram[0x0266 + x];
    CMP8(x, 0x19, &c);
    if (c) {                                    /* a killer mine           */
        a = sbc8(a, OST(x), &c);                /* the difference          */
        if (c) {
            a = g.ram[0x0266 + x];              /* L49AF: hold as it is    */
        } else {
            a = comp(a);
            a = lsr8(a, &c);
            if (a == 0) a = 0x01;               /* at least 1              */
            a = adc8(a, g.ram[0x0266 + x], &c); /* L49A9                   */
        }
        g.ram[0x0266 + x] = a;                  /* L49C8                   */
    } else {                                    /* L49B5: a comet          */
        CMP8(a, OST(x), &c);
        if (!c) {                               /* not at speed            */
            a = adc8(a, 0x04, &c);              /* else add 4 always       */
            CMP8(x, 0x15, &c);
            if (c)
                a = adc8(a, g.ram[0x039C], &c); /* second player targets   */
            else
                a = adc8(a, DWFRMP, &c);        /* L49C5                   */
            g.ram[0x0266 + x] = a;
        }
    }

    /* Ok1 ($49CB): the velocity = speed * (cos, sin) of the heading */
    WHITE = a;                                  /* the multiplier          */
    a = output_temp2_temp21(cos_sin_pi2(g.ram[0x0282 + x]));
    x = XCOMP;
    OVX(x) = a;
    a = output_temp2_temp21(pi_angle0(g.ram[0x0282 + x]));
    x = XCOMP;                                  /* "YES, SIN USES X"       */
    OVY(x) = a;
    return competitive_want_wait_other(x);
}

/* CompetitiveWantWaitOther ($49E9): the once-every-four-frames enemy
 * scheduler.  ($44 & 3) selects the phase: 0 = consider launching a
 * saucer or a comet for player ($44 & 4) >> 2, 1 = idle, 2/3 =
 * EnemyFireControl.  in/out x = the live 6502 X (see killer_mines). */
uint8_t competitive_want_wait_other(uint8_t x)
{
    uint8_t a, y;
    int c;

    if (!NEG((uint8_t)(ZP_38 & ZP_39)))
        return x;                               /* _90: attract initials   */
    a = (uint8_t)(ZP_44 & 0x03);
    if (a != 0) {
        if (a == 0x01)
            return x;                           /* _90: no action          */
        return enemy_fire_control(a, 1);        /* C set by the CMP #$01   */
    }

    /* L49FD _10 */
    a = (uint8_t)(ZP_44 & 0x04);
    a = lsr8(a, &c);
    a = lsr8(a, &c);                            /* c = 0 after both        */
    x = a;                                      /* X = 0 or 1              */
    WHITE = a;                                  /* who owns the enemy      */
    if (a != 0 && NEG(SUPRSAC))
        return x;                               /* skip #1 for a super     */
    a = adc8(a, 0x21, &c);                      /* _11: the carry is clear */
    y = a;
    if (ZP_34 == 0x01 && x != 0) {              /* the alone game          */
        if ((ZP_45 & 0xE0) == 0)
            return x;                           /* _90: too early          */
        y--;                                    /* against a single player */
    }
    /* _12 */
    EACE = y;
    if (g.ram[0x00B6 + x] == 0) {               /* the saucer is not out   */
        a = ZP_35;
        if (a == 0)
            return scent5(a, x);                /* A = 0: target a rock    */
        if (RDELAY != 0)
            return x;                           /* _92                     */
    }
    /* _18 */
    if (NEG(g.ram[A_PRTDAMAGE + x])) {          /* this ship is crippled   */
        y = FIREI(0x4D51 + y);                  /* _22: the other ship     */
        a = OST(y);
        if (a != 0 && !NEG(a))
            EACE = y;                           /* give him the problems   */
    }
    /* _30 */
    y = EACE;
    a = OST(y);
    if (a == 0 || NEG(a))
        return x;                               /* _90                     */
    if (NEG(LASTSW)) {                          /* the pair                */
        if ((uint8_t)(RTIMER | g.ram[0x026C]) == 0)
            goto s60;
        if ((uint8_t)(ENMDEL | g.ram[0x0266]) == 0)
            goto s60;
        goto s80;
    }
    /* _40 */
    if (ZP_34 != 0) {
        if (RTIMER == 0) goto s60;
        if (ENMDEL == 0) goto s60;
        goto s80;
    }
    /* _50: the competitive game keeps per-player timers */
    if (g.ram[A_RTIMER + x] == 0) goto s60;
    if (g.ram[A_ENMDEL + x] == 0) goto s60;

s80:
    a = g.ram[0xCF];                            /* $CF: difficulty level   */
    if (a == 0)
        return x;                               /* _92                     */
    CMP8(a, NROCKS, &c);
    if (!c)
        return x;                               /* _92                     */

s60:                                            /* L4A84 _60               */
    a = lsr8(WAVE, &c);                         /* wave 1?                 */
    if (a == 0)
        return scent5(a, x);                    /* rock-directed saucer    */
    a = (uint8_t)(sd_hw_pokey_random(0) & 0x07);
    CMP8(a, 0x01, &c);
    if (!c)
        return scent5(a, x);                    /* rock-directed saucer    */
    CMP8(a, 0x03, &c);
    if (c)
        return scent5(EACE, x);                 /* SaucerEntry: a normal one */
    if (NROCKS == 0)
        return x;                               /* _92                     */
    return initialize_comet();                  /* L4A9C JMP: the comet    */
}                                               /* module's exit X         */

/* Scent5 ($4AA1): start saucer x (0/1) with target a.  Picks the picture
 * and the side from POKEY2/POKEY1 RANDOM, seeds the entry position and
 * speed from Sspos/Ssminus by wave, and may promote saucer 0 to the
 * "super saucer" twin.  Falls into ResetTimers, so it returns that
 * routine's exit X (= WHITE) when it gets that far. */
uint8_t scent5(uint8_t a, uint8_t x)
{
    uint8_t y;
    int c;

    if (g.ram[0x00B6 + x] != 0)
        return x;                               /* _100: already there     */

    /* _1 */
    g.ram[A_ETARGET + x] = a;                   /* overrides any target    */
    if (g.ram[A_ETIMER + x] != 0)
        return x;                               /* _100                    */
    if (!NEG(g.ram[0x03BA])) {                  /* LNGTIMER+1: he dawdled? */
        if (NROCKS >= 0x08)
            return x;                           /* _100                    */
        if (ZP_34 != 0 &&
            (uint8_t)(g.ram[0xB6] | g.ram[0xB7]) != 0 &&
            g.ram[A_UMONHITS + x] == 0) {
            if (g.ram[A_LMONHITS + x] < 0x3C)
                return x;                       /* _100                    */
        }
    }

    /* L4AD0 _6 */
    a = (uint8_t)((sd_hw_pokey_random(1) & 0x40) | 0x01);   /* pic+active  */
    g.ram[0x00B6 + x] = a;
    if (x == 0x00) {                            /* only for saucer 0       */
        y = 0x00;                               /* guess a regular saucer  */
        if (g.ram[0xB7] == 0 &&                 /* saucer 1 not active     */
            (sd_hw_pokey_random(1) & 0x01) == 0 &&
            COMTIMER == 0 &&                    /* no super in an onslaught */
            g.ram[0xCF] >= 0x03) {              /* not before wave 3       */
            g.ram[0xB6] = 0x41;                 /* always this pic         */
            y = 0x80;                           /* set to super saucer     */
        }
        SUPRSAC = y;                            /* _3                      */
    }

    /* _7 */
    g.ram[0x033F + x] = 0x00;
    g.ram[0x02D4 + x] = 0x00;
    g.ram[0x0371 + x] = 0x00;
    a = sd_hw_pokey_random(0);
    TEMP5 = a;
    a = (uint8_t)(a & 0x1F);                    /* approx one screen       */
    if (a >= 0x18)
        a = (uint8_t)(a & 0x17);                /* must be 0 to 767        */
    if (NEG(SUPRSAC))                           /* _10                     */
        a = (uint8_t)(a & 0x03);                /* prevent a wrap on start */
    g.ram[0x0306 + x] = a;                      /* _15: start vertical pos */
    g.ram[0x0306 + x]++;                        /* 1 to 3 minimum start    */

    y = (uint8_t)(WAVE >> 2);                   /* wave # / 4              */
    if (y >= 0x04) y = 0x04;
    a = SAUT(0x4C66 + y);                       /* _16: min positive speed */
    if (!(TEMP5 & 0x40)) {                      /* BIT TEMP5 / BVS _20     */
        a = 0x1F;
        g.ram[0x02D4 + x] = a;
        g.ram[0x033F + x]--;                    /* start on the right side */
        a = SAUT(0x4C6B + y);                   /* the min negative speed  */
    }
    /* _20: LDY SCSHSP,X loads a register nothing reads afterwards */
    g.ram[0x00D3 + x] = a;
    if (NEG(SUPRSAC))
        a = (uint8_t)(a << 1);                  /* move at twice the speed */
    g.ram[0x021F + x] = a;                      /* _25                     */
    c = 0;
    SUPRDIS = adc8(g.ram[0xCF], 0x04, &c);      /* min distance (maxes at 9) */
    g.ram[A_ETIMER + x] = 0x3C;                 /* one screen width delay  */
    return reset_timers();
}

/* ResetTimers ($4B5C): X = WHITE, then Hasent. */
uint8_t reset_timers(void)
{
    return hasent(WHITE);
}

/* Hasent ($4B5E): reload player x's enemy delay from SENMDEL and clamp
 * his rock timer to MXRTIMER / 4.  out = x (Efirex is a bare RTS). */
uint8_t hasent(uint8_t x)
{
    uint8_t a;
    int c;

    g.ram[A_ENMDEL + x] = g.ram[A_SENMDEL + x];
    a = (uint8_t)(g.ram[A_MXRTIMER + x] >> 2);
    CMP8(a, g.ram[A_RTIMER + x], &c);
    if (c)
        g.ram[A_RTIMER + x] = a;
    return x;                                   /* Efirex $4B71            */
}

/* EnemyFireControl ($4B74): entered only by JMP from
 * CompetitiveWantWaitOther with a = $44 & 3 (2 or 3) and carry set, so
 * X = a - 2 = the saucer number.  Steps the saucer's vertical velocity
 * every 16 frames, counts EDELAY down and fires when it reaches zero. */
uint8_t enemy_fire_control(uint8_t a, int carry)
{
    uint8_t x, y;
    int c = carry;

    a = sbc8(a, 0x02, &c);                      /* the carry was set       */
    x = a;                                      /* X is now 0 or 1         */
    XCOMP = x;
    a = (uint8_t)(ZP_44 & 0xF0);
    a = asl8(a, &c);
    if (a == 0) {                               /* time to change direction */
        y = (uint8_t)(sd_hw_pokey_random(0) & 0x03);
        g.ram[0x0251 + x] = SAUT(0x4C62 + y);   /* vertical saucer velocity */
    }
    /* _10 */
    if (!NEG(g.ram[0x03BA])) {                  /* he dawdled?             */
        CMP8(NROCKS, 0x0A, &c);
        if (c)
            return x;                           /* Efirex: no time for it  */
    }
    /* _30 */
    g.ram[A_EDELAY + x]--;
    if (g.ram[A_EDELAY + x] != 0)
        return x;                               /* _40: not time to shoot  */
    /* _50 */
    if (NEG(SUPRSAC)) {
        g.ram[A_ANGLE + x] = obj_angleshoot[x]; /* force the angle         */
        g.ram[A_EDELAY + x] = SUPRTIM;          /* delay set by distance   */
        return start_looking_here(x);
    }
    /* _51 */
    a = 0x10;                                   /* a cheap way to limit shots */
    if (NEG(g.ram[A_SCSHSP + x]))
        a = 0x09;                               /* fast shots: can fire 2  */
    g.ram[A_EDELAY + x] = a;                    /* _55                     */
    return efire3(x);
}

/* Efire3 ($4BBE): pick a live target for saucer x (falling back to a scan
 * of the comet/rock slots $11 down to $01), then compute the lead angle -
 * the distances are taken to quarter-screen resolution and the saucer's
 * own velocity is subtracted before the arctan.  A random fuzz of up to
 * $0F (halved once $45 passes $30) keeps the saucer from being perfect. */
static uint8_t efire3(uint8_t x)
{
    uint8_t a, y;
    int c;

    y = g.ram[A_ETARGET + x];
    if (y < 0x10) {
        y = 0x11;
        for (;;) {                              /* _10                     */
            a = OST(y);
            if (a != 0 && !NEG(a))
                break;                          /* _40: found a live one   */
            y--;                                /* _20                     */
            if (y == 0)
                break;
        }
        g.ram[A_ETARGET + x] = y;               /* _40                     */
    }
    /* _50 */
    a = g.ram[0x00B6 + x];
    if (a == 0 || NEG(a))
        return x;                               /* Efirex: dead / gone     */
    a = OST(y);
    if (a == 0 || NEG(a))
        return x;                               /* the target is dead/gone */

    c = 0;
    POTGO = asr8(g.ram[0x021F + x], &c);        /* (XINC / 2)              */
    c = 1;
    POKRAN = sbc8(OXL(y), g.ram[0x033F + x], &c);
    a = sbc8(OXH(y), g.ram[0x02D4 + x], &c);
    POKRAN = asl8(POKRAN, &c);
    a = rol8(a, &c);
    POKRAN = asl8(POKRAN, &c);
    a = rol8(a, &c);                            /* -$7F to +$7F            */
    c = 1;
    a = sbc8(a, POTGO, &c);                     /* torpedo speed follows us */
    {
        uint8_t denom = a;                      /* PHA                     */
        c = 0;
        POTGO = asr8(g.ram[0x0251 + x], &c);
        c = 1;
        POKRAN = sbc8(OYL(y), g.ram[0x0371 + x], &c);
        a = sbc8(OYH(y), g.ram[0x0306 + x], &c);
        POKRAN = asl8(POKRAN, &c);
        a = rol8(a, &c);
        POKRAN = asl8(POKRAN, &c);
        a = rol8(a, &c);                        /* -$5F to +$5F            */
        c = 1;
        a = sbc8(a, POTGO, &c);                 /* account for our motion  */
        a = part_signed_number_exit(denom, a);  /* arctan(y/x)             */
    }
    x = XCOMP;
    g.ram[A_ANGLE + x] = a;
    CMP8(ZP_45, 0x30, &c);                      /* units of ~4 seconds     */
    a = (uint8_t)(sd_hw_pokey_random(0) & 0x0F);
    if (c)
        a = lsr8(a, &c);                        /* more accuracy           */
    if (NEG(sd_hw_pokey_random(1)))             /* _90: BIT $140A          */
        a = (uint8_t)(a ^ 0xFF);                /* invert                  */
    a = adc8(a, g.ram[A_ANGLE + x], &c);        /* _95: don't be too good  */
    g.ram[A_ANGLE + x] = a;                     /* _96: the angle to aim   */
    return start_looking_here(x);
}

/* StartLookingHere ($4C47): choose the saucer's torpedo slot window
 * (StartingValues $4C5E / StoppingValues $4C60 - two torpedoes each) and
 * whether the shot is fast (POKRAN bit 7). */
static uint8_t start_looking_here(uint8_t x)
{
    uint8_t a, y;

    y = SAUT(0x4C5E + x);                       /* start looking here      */
    FOURPI = SAUT(0x4C60 + x);                  /* the stopping index      */
    a = (uint8_t)(g.ram[A_SCSHSP + x] | SUPRSAC);
    if (NEG(a))
        a = 0x80;                               /* fast for the dawdled    */
    POKRAN = a;                                 /* FastSlow: fast or slow  */
    temp280_fast0(x, y);
    return x;
}

/* FireShipsTorpedos ($4C70): x = ship 0/1.  Reads the fire button through
 * IN1 (bit 6) - in attract the "button" is a POKEY random number - and
 * edge-detects it in CMBSCORE,X ($49/$4A).  In the drone game ($51 bit 7)
 * this single call fires for both ships. */
void fire_ships_torpedos(uint8_t x)
{
    uint8_t a;
    int c;

    if (NEG(ZP_35))
        a = sd_hw_in1(x);                       /* _10: bit 6 = pushed     */
    else
        a = sd_hw_pokey_random(0);
    /* _11: shift bit 6 into the carry, then into CMBSCORE,X bit 7 */
    a = asl8(a, &c);
    a = asl8(a, &c);
    g.ram[A_CMBSCORE + x] = ror8(g.ram[A_CMBSCORE + x], &c);
    if (!NEG(g.ram[A_CMBSCORE + x]))
        return;                                 /* Fire2: not pressed      */
    a = g.ram[A_CMBSCORE + x];
    a = asl8(a, &c);
    if (NEG(a))
        return;                                 /* Fire2: on last time too */
    if (NEG(ZP_51)) {                           /* the drone game          */
        fire_ships_torpedos_20(x);              /* JSR _20 with X = 0      */
        x = 0x01;                               /* L4C8F                   */
    }
    fire_ships_torpedos_20(x);
}

/* FireShipsTorpedos_20 ($4C91): the per-ship half - alive, not exploding
 * and shields down, then find a free torpedo slot.  The slot window comes
 * from StartingSearchEmptyMine/EndingSearchEmptyMine/EndingDamaged
 * ($4D6B-$4D70) indexed by X + 2, with a shorter window when the ship is
 * partially damaged (PRTDAMAGE, reached as `BXINCL,X`). */
static void fire_ships_torpedos_20(uint8_t x)
{
    uint8_t a, y;

    a = OST(x + 0x21);                          /* L4C91 LDA $B8,X - the
                                                 * SHIP's status ($97+$21/
                                                 * $22), not $97,X         */
    if (a == 0 || NEG(a))
        return;                                 /* Fire2: dead / exploding */
    if (g.ram[0x4F + x] & 0x80)
        return;                                 /* Fire2: shields are on   */
    /* _50 */
    x = (uint8_t)(x + 2);                       /* X = 2 or 3 for Fire3    */
    XCOMP = x;
    POKRAN = 0x80;
    FOURPI = FIREI(0x4D6B + x);                 /* the stopping index      */
    y = FIREI(0x4D69 + x);                      /* the starting index      */
    if (g.ram[A_BXINCL + x] != 0)               /* PRTDAMAGE,ship          */
        y = FIREI(0x4D6D + x);                  /* the damaged start value */
    temp280_fast0(x, y);
}

/* Temp280Fast0 ($4CB5): walk down from torpedo slot y to FOURPI looking
 * for a free one; Fire3 launches it. */
void temp280_fast0(uint8_t x, uint8_t y)
{
    for (;;) {
        if (OST(y) == 0) {
            fire3(x, y);                        /* found an inactive one   */
            return;
        }
        y--;
        if (y == FOURPI)
            return;                             /* Fire2: none free        */
    }
}

/* Fire2 ($4CBF): the bare RTS every "cannot fire" test shares. */
void fire2(void)
{
}

/* Fire3 ($4CC0): launch torpedo y from shooter x (x = 0/1 saucer, 2/3
 * ship).  Life = $12 fast / $24 slow; the velocity = the shooter's
 * velocity plus cos/sin of ANGLE,X halved (twice for a slow shot) and
 * clamped to -$6F..+$6F; the start position is the shooter's plus 3/2 of
 * that velocity component, i.e. out at the nose. */
void fire3(uint8_t x, uint8_t y)
{
    uint8_t a;
    int c;

    a = 0x12;
    if (!NEG(POKRAN))
        a = (uint8_t)(a << 1);                  /* a slow shot lives twice */
    OST(y) = a;                                 /* _10: length of life     */

    a = cos_sin_pi2(g.ram[A_ANGLE + x]);        /* the X component         */
    c = 0;
    a = asr8(a, &c);                            /* divide by 2             */
    if (!NEG(POKRAN))
        a = asr8(a, &c);                        /* divide again            */
    EACE = a;                                   /* _15                     */
    c = 0;
    x = XCOMP;
    a = adc8(a, g.ram[0x021F + x], &c);
    if (NEG(a)) {                               /* _23                     */
        if (a < 0x91) a = 0x91;                 /* the minimum             */
    } else {
        if (a >= 0x70) a = 0x6F;                /* the maximum             */
    }
    OVX(y) = a;                                 /* _30: set the X speed    */

    a = pi_angle0(g.ram[A_ANGLE + x]);          /* the Y component         */
    c = 0;
    a = asr8(a, &c);
    if (!NEG(POKRAN))
        a = asr8(a, &c);
    POTGO = a;                                  /* _32                     */
    x = XCOMP;
    c = 0;
    a = adc8(a, g.ram[0x0251 + x], &c);
    if (NEG(a)) {                               /* _33                     */
        if (a < 0x91) a = 0x91;
    } else {
        if (a >= 0x70) a = 0x6F;
    }
    OVY(y) = a;                                 /* _40                     */

    /* L4D20: the start position = shooter + 3/2 * the component */
    c = 0;
    a = asr8(EACE, &c);
    c = 0;
    a = adc8(a, EACE, &c);                      /* multiply by 3/2         */
    c = 0;                                      /* the CLC drops that carry */
    a = adc8(a, g.ram[0x033F + x], &c);
    OXL(y) = a;
    a = adc8(0x00, g.ram[0x02D4 + x], &c);
    if (NEG(EACE)) {                            /* test the sign           */
        c = 0;
        a = adc8(a, 0xFF, &c);
    }
    OXH(y) = a;                                 /* _45                     */

    c = 0;
    a = asr8(POTGO, &c);
    c = 0;
    a = adc8(a, POTGO, &c);
    c = 0;
    a = adc8(a, g.ram[0x0371 + x], &c);
    OYL(y) = a;
    a = adc8(0x00, g.ram[0x0306 + x], &c);
    if (NEG(POTGO)) {
        c = 0;
        a = adc8(a, 0xFF, &c);                  /* perhaps not needed      */
    }
    OYH(y) = a;                                 /* _50                     */

    if (x < 0x02)
        saucer_fire(x, y);                      /* JSR & return            */
    else if (x == 0x02)
        player0_fire(x, y);                     /* _60: player 0           */
    else
        player1_fire(x, y);                     /* _65: player 1           */
}

/* ================================================================== */
/* start-up                                                            */
/* ================================================================== */

/* Shpplace ($4F1C): pick a random re-entry position for ship x, kept
 * $05..$1A in X (ship 0 biased into the right half by the ORA #$10) and
 * $05..$12 in Y. */
void shpplace(uint8_t x)
{
    uint8_t a;

    a = (uint8_t)(sd_hw_pokey_random(0) & 0x0F);
    if (x == 0x00)
        a = (uint8_t)(a | 0x10);
    if (a >= 0x1B) a = 0x1A;                    /* _1: stay off the edge   */
    if (a < 0x05)  a = 0x05;                    /* _2                      */
    g.ram[0x02D6 + x] = a;                      /* _4                      */

    a = (uint8_t)(sd_hw_pokey_random(0) & 0x1F);
    if (a >= 0x13) a = 0x12;                    /* _10: stay off the top   */
    if (a < 0x05)  a = 0x05;                    /* _12                     */
    g.ram[0x0308 + x] = a;                      /* _20: the new Y position */
}

/* ZeroAllRamPast ($4F4B): clear zp $35-$D8, $0200-$02FF and $0301-$03E0.
 * $0300 is deliberately missed - the DEX/BNE loop stops at X = 0. */
void zero_all_ram_past(void)
{
    unsigned i;

    for (i = 0x35; i != 0xD9; i++)              /* _10: STA BLACK,X        */
        g.ram[i] = 0x00;
    for (i = 0x00; i <= 0xFF; i++)              /* _20: STA XINC,X         */
        g.ram[A_XINC + i] = 0x00;
    for (i = 0xE0; i != 0; i--)                 /* _30: STA $0300,X        */
        g.ram[0x0300 + i] = 0x00;
}

/* Initialization ($4F66): a new game.  Wipes the play RAM, clears both
 * scores, marks all three score areas dirty, re-reads the options, seeds
 * the per-player enemy timers and comet parameters, and loads the
 * game-type toggles ($51 from Ttogdrone, LASTSW from
 * TableInitialValuesToggles).  Falls into Inset2 ($4FEE, display.c). */
void initialization(void)
{
    uint8_t x, a;

    zero_all_ram_past();
    g.ram[0x31] = 0x00;                         /* no more coins           */
    for (x = 0x08; x != 0xFF; x--)              /* _30: clear the scores   */
        g.ram[0x3A + x] = 0x00;
    NROCKS = 0x00;
    RDELAY = 0x00;
    SUPRSAC = 0x00;                             /* clear any old saucer    */
    for (x = 0x02; x != 0xFF; x--)              /* _35                     */
        g.ram[A_PL0SCFLAG + x] = 0xBF;          /* score on, lives off     */
    gtoptn();                                   /* options -> lives/bonus  */
    ZP_35 = 0x80;
    ZP_38--;
    ZP_39--;                                    /* stop high score entry   */
    g.ram[0x03BA] = 0x01;                       /* LNGTIMER+1              */
    for (x = 0x01; x != 0xFF; x--) {            /* _36                     */
        g.ram[A_SENMDEL + x] = 0xA0;            /* starting enemy delay    */
        g.ram[A_SDELAY + x] = 0x01;
        g.ram[A_DWFRMP + x] = 0x02;
        g.ram[A_FCACH + x] = 0x00;
        a = 0x20;
        g.ram[A_NWCACH + x] = a;
        g.ram[A_NWCSPD + x] = a;
        g.ram[A_FCSPD + x] = a;
        a = (uint8_t)(a << 2);                  /* ASL / ASL -> $80        */
        g.ram[A_IANGLE + x] = a;
        g.ram[A_MXRTIMER + x] = a;
    }
    COMSTART = 0x11;
    g.ram[0x0398] = 0x15;                       /* COMSTART+1              */
    g.ram[0x03B5] = 0xFF;                       /* BCOMSTART+1             */
    x = ZP_34;
    ZP_51 = TOGT(0x6CD1 + x);                   /* Ttogdrone               */
    LASTSW = TOGT(0x6CCD + x);                  /* TableInitialValuesToggles */
    if (x == 0x01) {
        g.ram[0x026E] = 0x00;                   /* SDELAY+1                */
        g.ram[0x48] = 0x00;
        g.ram[0x0389]--;                        /* PRTDAMAGE+1 (was 0)     */
    }
    COMLIMIT = 0x01;                            /* _38: always 1 comet     */
    inset2();                                   /* falls into Inset2       */
}

/* Inselo ($50D5): fill the persistent rock/saucer stub area in vector RAM
 * ($2290-$22FF) with RTSLs, then seed the three saucer COLOR words
 * SAU11/12/13 and their COLOR opcodes. */
void inselo(void)
{
    uint8_t y;

    for (y = 0x6F; y != 0xFF; y--)              /* _20                     */
        VRAM(A_VROCK1 + y) = 0xC0;              /* an RTSL                 */
    VRAM(A_SAU11) = 0xF4;                       /* init the saucer colours */
    VRAM(A_SAU12) = 0xE7;
    VRAM(A_SAU13) = 0xF1;
    VRAM(0x22C5) = 0x64;                        /* and the COLOR opcode    */
    VRAM(0x22C9) = 0x64;
    VRAM(0x22CD) = 0x64;
}

/* ================================================================== */
/* the per-frame motion update                                         */
/* ================================================================== */

/* MotionUpdateRoutine ($5174): during an onslaught in a combined-lives
 * game, drop the STRADDLE flags once the two ships are close enough in Y
 * (< $0C) and X (< $10), then run Moti20.
 * in x = the live 6502 X left by KillerMines - the ROM indexes $0308,X /
 * $02D6,X with it and compares against ship $22, so the intent is x = 0;
 * see NOTES_objects.md, open question 1. */
void motion_update_routine(uint8_t x)
{
    uint8_t a;
    int c;

    if (COMTIMER != 0 && NEG(LASTSW)) {
        c = 1;
        a = sbc8(g.ram[0x0308 + x], g.ram[0x0309], &c);
        a = entry_input_exit_absolute(a);
        if (a < 0x0C)
            STRADDLE = (uint8_t)(STRADDLE & 0xBF);   /* no longer in Y     */
        /* _30 */
        c = 1;
        a = sbc8(g.ram[0x02D6 + x], g.ram[0x02D7], &c);
        a = entry_input_exit_absolute(a);
        if (a < 0x10)
            STRADDLE = (uint8_t)(STRADDLE & 0x7F);   /* no longer in X     */
    }
    moti20();
}

/* Moti20 ($51A9): integrate every object's 16-bit position by its
 * velocity, run the explosion animations, apply the screen wrap (or the
 * onslaught cage bounce), then draw the picture.  X walks $2F down to
 * $00 and XCOMP mirrors it across the Pictur call.  RED/CHAN2V hold the
 * new X high/low and TWOPI/CHAN3V the new Y - Pictur reads them. */
void moti20(void)
{
    uint8_t x, y, a;
    int c;

    RODSTATUS = 0x00;                           /* no rods drawn           */
    x = 0x2F;                                   /* the objects to move     */

    for (;;) {
        XCOMP = x;                              /* _11: save for later use */
        a = OST(x);
        if (a == 0)
            goto next;                          /* _13                     */

        if (NEG(a)) {                           /* _15: exploding          */
            a = comp(a);                        /* time remaining (0..60)  */
            a = (uint8_t)(a >> 4);              /* LSR x4                  */
            if (x < 0x21) {
                c = 1;                          /* _30: SEC                */
            } else if (x >= 0x23) {
                c = 1;                          /* the CPX #$23 left C set */
            } else {
                (void)lsr8((uint8_t)(ZP_44 & 0x01), &c);
                /* +1 every other frame for the two ships */
            }
            a = adc8(a, OST(x), &c);            /* _32: the new picture    */
            if (NEG(a)) {
                OST(x) = a;                     /* _45: still inactive     */
            } else {
                /* _36: the explosion finished - retire the object */
                if (x < 0x19) {
                    int done = 0;
                    if (x >= 0x11) {
                        NCOMET--;
                        if (!NEG(NCOMET))
                            done = 1;           /* BPL _40 ("I hope")      */
                    }
                    if (!done) {                /* _37                     */
                        NROCKS--;
                        if (NROCKS == 0) {
                            g.ram[0x53] = 0x00;
                            y = 0x7F;
                            RDELAY = y;         /* delay before starting   */
                            if (ZP_35 != 0) {   /* not in attract          */
                                XINCL = 0xFF;   /* mines off               */
                                c = 0;
                                a = adc8(WAVE, g.ram[0xCF], &c);
                                a = (uint8_t)(a >> 2);   /* onslaught size */
                                y = a;          /* _39                     */
                                if (y >= 0x0F) y = 0x0F;
                                if (!NEG(COMOFF)) {      /* _38: just died? */
                                    NENTCOMETS = ENTDW(0x5154 + y);
                                    NENTDWARF = ENTDW(0x5164 + y);
                                    if (NEG(LASTSW))
                                        STRADDLE = 0xFF; /* assume straddle */
                                    COMTIMER = 0x60;     /* _35: onslaught  */
                                    SFREQ = 0xFF;        /* reset hum freq  */
                                }
                            }
                        }
                    }
                }
                OST(x) = 0x00;                  /* _40 / _42               */
                goto next;
            }
        }

        /* L5236 _60: integrate X */
        c = 0;
        y = 0x00;
        a = OVX(x);
        if (NEG(a)) y = 0xFF;                   /* the sign extension      */
        a = adc8(a, OXL(x), &c);                /* _62                     */
        CHAN2V = a;
        a = adc8(y, OXH(x), &c);
        if (a < 0x20)
            goto x85;                           /* _27: already 0..1023    */
        RED = a;

        /* _70: off the side of the screen */
        if (x < 0x11)      goto x75;            /* it was a rock           */
        else if (x >= 0x24) goto x79;           /* a shot                  */
        else if (x < 0x1F)  goto x76;           /* a comet or killer mine  */
        else if (x >= 0x21) goto x71;           /* not a saucer or below   */
        if (NEG(SUPRSAC)) {                     /* a super saucer hit it   */
            uint8_t saved = a;                  /* PHA                     */
            c = 0;
            a = adc8(SUPRDIS, 0x01, &c);        /* wider next pass         */
            if (a < 0x12)
                SUPRDIS = a;
            a = saved;                          /* _72: PLA                */
            if (!NEG(g.ram[0x53])) {
                if (COMTIMER == 0)
                    goto x75;
            }
        }
        reset_saucer_values(x);                 /* _77                     */
        goto next;

    x71:
        RODSTATUS++;
        if (COMTIMER == 0) goto x79;            /* not the cage            */
        if (NEG(STRADDLE)) goto x79;            /* still straddling        */
        if (x != 0x23)
            revxship(x);                        /* _74 skips this for the rod */
        reverse_angular_momentum();             /* _74                     */
        possible_reverse_x_velocity();
        if (NEG(RED)) {                         /* _24                     */
            a = 0x00;
            y = 0x00;
        } else {
            a = 0x1F;
            y = 0xFF;
        }
        CHAN2V = y;                             /* _26                     */
        goto x85;                               /* _27                     */

    x76:
        if (x >= 0x19) {
            if (!NEG(XINCL)) goto x80;          /* stay                    */
            goto x81;                           /* leave                   */
        }
        /* _73: a comet or dwarf */
        c = 0;                                  /* the CPX #$19 left C clear */
        a = ror8(g.ram[0x037E + x], &c);        /* COMTYP                  */
        if (c) goto x83;                        /* take it away            */
        a = rol8(a, &c);
        if (NEG(a)) goto x79;                   /* already a comet         */
        sbttl_stcomet(x);
        if (!NEG(OST(x))) goto x79;             /* "BPL _79 (always)"      */
        /* falls into _75 */
    x75:
        if (!NEG(g.ram[0x53])) goto x80;        /* rocks wrap around       */
        goto next;                              /* do not show this rock   */

    x83:
        NCOMET--;
    x81:
        OST(x) = 0x00;
        goto next;                              /* _102                    */

    x79:
        a = RED;
    x80:
        a = (uint8_t)(a & 0x1F);
    x85:
        RED = a;

        /* L52DB: integrate Y */
        c = 0;
        y = 0x00;
        a = OVY(x);
        if (NEG(a)) y = 0xFF;
        a = adc8(a, OYL(x), &c);                /* _88                     */
        CHAN3V = a;
        a = adc8(y, OYH(x), &c);                /* 0 to 767 please         */
        if (a < 0x18)
            goto y92;
        TWOPI = a;
        if (x < 0x11) goto y84;
        if (x < 0x1F) goto y58;
        RODSTATUS++;
        if (COMTIMER == 0) goto y89;            /* the time is gone        */
        if (STRADDLE & 0x40) goto y89;          /* BVS: still straddling   */
        if (x == 0x23) goto y54;                /* it was the rod          */
        if (x >= 0x23) goto y89;                /* not a ship              */
        if (x < 0x21) goto y89;                 /* not a ship              */
        reverse_travel_velocity(x);
        reverse_angular_momentum();
    y54:
        prevybar();
        if (NEG(TWOPI)) {                       /* _52                     */
            a = 0x00;
            y = 0x00;
        } else {
            a = 0x17;
            y = 0xFF;
        }
        TWOPI = a;                              /* _53                     */
        CHAN3V = y;
        goto y92;

    y58:
        if (x >= 0x19) {
            if (!NEG(XINCL)) goto y89;          /* stay                    */
            goto x81;                           /* leave                   */
        }
        /* _82 */
        c = 0;
        a = ror8(g.ram[0x037E + x], &c);
        if (c) goto x83;                        /* get off the screen      */
        a = rol8(a, &c);
        if (NEG(a)) goto y89;                   /* already a comet         */
        sbttl_stcomet(x);
        if (!NEG(OST(x))) goto y89;             /* "BPL _89 (always)"      */
        /* falls into _84 */
    y84:
        if (NEG(g.ram[0x53]))
            goto next;                          /* _102: leave at the edge */
    y89:
        a = NEG(TWOPI) ? 0x17 : 0x00;           /* wrap to the top / _90   */
    y92:
        if (NEG(SUPRSAC) && x == 0x1F) {        /* the control saucer      */
            CMP8(a, 0x01, &c);
            if (a == 0x01)
                goto y93;                       /* hold there on the way up */
            if (!c) {
                OYH(x)++;                       /* _100: force off bottom  */
                goto y93;
            }
            TEMP2 = a;
            c = 0;
            a = adc8(a, SUPRDIS, &c);           /* check the top distance  */
            CMP8(a, 0x17, &c);
            if (a == 0x17)
                goto y93;                       /* at the top: leave it    */
            if (!c) {
                a = TEMP2;                      /* _94                     */
                goto y95;
            }
            OYH(x)--;                           /* force off the top       */
        y93:
            CHAN3V = OYL(x);                    /* store the positions     */
            TWOPI = OYH(x);                     /* for the picture routine */
            if (TWOPI != 0)
                goto y96;                       /* "we know this is never 0" */
            a = TEMP2;                          /* falls into _94          */
        }
    y95:
        OYH(x) = a;
        TWOPI = a;
        OYL(x) = CHAN3V;
    y96:
        OXL(x) = CHAN2V;
        OXH(x) = RED;
        if (x == 0x23)
            goto next;                          /* _99: the rod has no pic */
        if (NEG(SPECEX)) {                      /* special explosions?     */
            CMP8(OYH(x), OST(x), &c);           /* OBJ holds the dest Y    */
            if (c) {
                OVY(x) = 0x00;                  /* stop the motion         */
                OST(x) = 0xA0;                  /* explode                 */
                explosion(x, y);                /* sound                   */
                x = XCOMP;                      /* recall X                */
            }
        }
        pictur(x);                              /* _121: display the pic   */
        x = XCOMP;

    next:                                       /* _13                     */
        if (x == 0)
            return;
        x--;
    }
}

/* SbttlStcomet ($53C7): promote rock/dwarf x into a comet aimed at its
 * GTIME target - the turn rate comes from NWCACH and the target speed
 * from NWCSPD of the targeted ship. */
void sbttl_stcomet(uint8_t x)
{
    uint8_t y = g.ram[A_GTIME + x];

    g.ram[0x037E + x] = 0x80;                   /* now a comet             */
    g.ram[0x0274 + x] = g.ram[A_BXINCL + y];    /* NWCACH,target           */
    OST(x) = g.ram[A_PRTDAMAGE + y];            /* NWCSPD,target           */
}

/* KillXSaucer ($53DB): 300 points, explosion, then ClearSaucer. */
void kill_x_saucer(uint8_t x)
{
    WHITE = x;
    add_points_to_score(0x30);
    x = WHITE;
    /* Y here is AddPointsToScore's leftover - see NOTES */
    explosion(x, 0x00);                         /* explosion sound         */
    clear_saucer(0xA0, x);
}

/* ResetSaucerValues ($53EB) / ClearSaucer ($53ED): a = the new status
 * ($00 = gone, $A0 = exploding), x = the saucer object ($1F/$20). */
static void reset_saucer_values(uint8_t x)
{
    clear_saucer(0x00, x);
}

static void clear_saucer(uint8_t a, uint8_t x)
{
    OST(x) = a;                                 /* clear the saucer        */
    SUPRSAC = 0x00;                             /* goodbye super saucer    */
    hasent(CLRSAU(0x53DC + x));                 /* delay before the next   */
}

/* WaitForDirectedEnemies ($53FD): is any saucer or comet already aimed at
 * object y?  Returns the 6502 Z flag: 1 = nothing found (the caller's
 * BEQ).  Note the fall-through exit takes Z from the DEX, not from A. */
int wait_for_directed_enemies(uint8_t y)
{
    uint8_t x;

    TEMP5 = y;
    for (x = 0x02; x != 0; x--) {               /* _20: the two saucers    */
        if (g.ram[A_NENTDWARF + x] == TEMP5 &&  /* ETARGET-1,x             */
            g.ram[0xB5 + x] != 0)
            return 0;                           /* _80: Z clear            */
    }
    for (x = 0x08; x != 0; x--) {               /* _55: the comets         */
        if (g.ram[0x03C0 + x] == TEMP5 &&       /* CTARGET-1,x             */
            g.ram[0xA7 + x] != 0)
            return 0;
    }
    return 1;                                   /* _80 via DEX: Z set      */
}

/* EntryNoRequirementsExit ($5420): OR together the eight comet status
 * bytes ($A8-$AF = objects $11-$18); out A (zero = no comets alive). */
static uint8_t entry_no_requirements_exit(void)
{
    uint8_t a = 0x00, y;
    for (y = 0x07; y != 0xFF; y--)              /* _10                     */
        a = (uint8_t)(a | g.ram[0x00A8 + y]);
    return a;                                   /* TAY sets the flags      */
}

/* ReverseTravelVelocity ($542C): negate the 16-bit Y velocity of ship x
 * (low byte at $2C+x = $4D/$4E = FRAME, high byte at YINC,x). */
static void reverse_travel_velocity(uint8_t x)
{
    int c = 1;
    g.ram[0x2C + x] = sbc8(0x00, g.ram[0x2C + x], &c);
    OVY(x) = sbc8(0x00, OVY(x), &c);
}

/* Revxship ($543C): negate the 16-bit X velocity of ship x, then fall
 * into ReverseAngularMomentum. */
static void revxship(uint8_t x)
{
    int c = 1;
    g.ram[0x2A + x] = sbc8(0x00, g.ram[0x2A + x], &c);
    OVX(x) = sbc8(0x00, OVX(x), &c);
    reverse_angular_momentum();
}

/* ReverseAngularMomentum ($544B): negate the 16-bit bar spin
 * LWBAR/UWBAR. */
static void reverse_angular_momentum(void)
{
    int c = 1;
    LWBAR = sbc8(0x00, LWBAR, &c);
    UWBAR = sbc8(0x00, UWBAR, &c);
}

/* PossibleReverseXVelocity ($545D): if the pair's X velocity still points
 * at the wall it just hit (RED and $0223 differ in sign), negate it. */
static void possible_reverse_x_velocity(void)
{
    int c;
    if (!NEG((uint8_t)(RED ^ g.ram[0x0223]))) {
        c = 1;
        BXINCL = sbc8(0x00, BXINCL, &c);
        g.ram[0x0223] = sbc8(0x00, g.ram[0x0223], &c);
    }
    drop_shields_wall_hit();                    /* _90                     */
}

/* Prevybar ($5478): the same for the pair's Y velocity, then fall into
 * DropShieldsWallHit. */
static void prevybar(void)
{
    int c;
    if (!NEG((uint8_t)(TWOPI ^ g.ram[0x0255]))) {
        c = 1;
        BYINCL = sbc8(0x00, BYINCL, &c);
        g.ram[0x0255] = sbc8(0x00, g.ram[0x0255], &c);
    }
    drop_shields_wall_hit();
}

/* DropShieldsWallHit ($5490): hitting the onslaught cage costs shield
 * energy for whichever player is holding his shield switch down. */
static void drop_shields_wall_hit(void)
{
    uint8_t x;
    for (x = 0x01; x != 0xFF; x--) {            /* _10                     */
        if (NEG(twin_game_both_shields(x)))     /* switch pushed?          */
            game23_shields(x);                  /* yes: take away energy   */
    }
    /* LDX XCOMP restores X for the caller (no RAM effect) */
}

/* ================================================================== */
/* ship control                                                        */
/* ================================================================== */

/* MoveShip ($54A1): x = ship 0/1.  In the combined-lives games the pair
 * is moved by Dorigid instead.  Handles the re-entry countdown (SDELAY),
 * the life/damage bookkeeping when a ship comes back, and the thrust:
 * cos/sin of SANGLE scaled by 4 (2 when partially damaged) added to the
 * 16-bit velocity and clamped by OutRange. */
void move_ship(uint8_t x)
{
    uint8_t a, y;
    int c;

    XCOMP = x;
    if (NEG(LASTSW)) {                          /* combined lives          */
        if (x == 0x00)
            return;                             /* _91: last pass through  */
        dorigid();                              /* _31: move the pair      */
        return;
    }
    a = OST(x + 0x21);                          /* L54A7 LDA $B8,X - the
                                                 * SHIP's status ($97+$21/
                                                 * $22), not $97,X         */
    if (NEG(a)) {
        /* The 6502 carry here is the mainline caller's - see NOTES */
        shipfriction(x, 0);                     /* if exploding            */
        return;
    }
    if (a != 0)
        goto active;                            /* _2 / _5                 */

    /* _7: not visible - count the re-entry delay down */
    if (g.ram[A_SDELAY + x] == 0)
        return;                                 /* _91: not to appear      */
    g.ram[A_SDELAY + x]--;
    if (g.ram[A_SDELAY + x] != 0)
        return;                                 /* _91: not done yet       */
    if (COMTIMER != 0)
        goto s94;                               /* no re-entry in a bonus  */
    shpplace(x);
    if (check_for_rocks_nearby(x) != 0)
        goto s94;                               /* something is close by   */
    y = FIREI(0x4D71 + x);                      /* L01ZshipZship: our slot */
    if (!wait_for_directed_enemies(y))
        goto s94;                               /* an enemy is aimed here  */

    /* _92: bring the ship back */
    x = XCOMP;
    g.ram[0x0221 + x] = 0x00;
    g.ram[0x0253 + x] = 0x00;
    if (ZP_34 == 0x01) {                        /* the alone game          */
        if (g.ram[0x47 + x] == 0)
            goto s8;                            /* the game is over        */
        COMOFF = 0x00;                          /* all active              */
        goto s95;
    }
    /* _93 */
    if (!NEG(g.ram[A_WHOSHOT + x]) ||           /* lost a light            */
        NEG(g.ram[A_PRTDAMAGE + x])) {
        /* _99 */
        if (g.ram[0x47 + x] != 0)
            goto s95;
        y = FIREI(0x4D72 + x);                  /* Revship: the other ship */
        if (NEG(g.ram[0x0367 + y]))
            goto s94;                           /* the other is dead: wait */
        goto s97;
    }
    goto s97;                                   /* reincarnate             */

s95:
    if (NEG(ZP_35))                             /* not attract             */
        g.ram[0x47 + x]--;
    g.ram[A_PL0SCFLAG + x] = 0xBF;              /* _1: lives & scores      */
    g.ram[A_PRTDAMAGE + x] = 0x00;              /* _96: no partial damage  */
s97:
    g.ram[A_SHLDENG + x] = 0xF0;                /* restore the shields     */
    OST(x + 0x21) = 0x02;                       /* L5529 STA $B8,X: the
                                                 * 1/2-size ship picture   */
    g.ram[0x53] = 0x00;                         /* let the rocks come back */
    NENTCOMETS = 0x00;
    NENTDWARF = 0x00;
    c = 0;
    a = adc8(g.ram[A_MXRTIMER + x], 0x10, &c);
    if (!c) {                                   /* _98 on overflow         */
        g.ram[A_MXRTIMER + x] = a;              /* a little more rock time */
        g.ram[A_RTIMER + x] = a;
    }
    g.ram[A_ENMDEL + x] = 0x7F;                 /* _98: the max delay      */
    if (x == 0x01) {
        g.ram[0x03E8] = 0x10;                   /* _10: ENTER+1            */
        reenter(x, 0x00);                       /* re-enter sound & exit   */
    } else {
        ENTER = 0x10;                           /* the effect timer        */
        reenter2(x, 0x00);
    }
    return;

s94:
    x = XCOMP;
s8:
    g.ram[A_SDELAY + x]++;                      /* _8                      */
    return;

active:                                         /* L555A _5                */
    a = (uint8_t)(x ^ ZP_44);
    (void)lsr8(a, &c);
    if (c)
        return;                                 /* _70: alternate frames   */
    if (NEG(ZP_35)) {
        a = sd_hw_in1((uint8_t)(4 + x));        /* _11: STRT1,X            */
    } else {
        a = ZP_44;                              /* don't read in attract   */
        a = asl8(a, &c);
        a = asl8(a, &c);
    }
    if (!NEG(a)) {                              /* _12: no thrust          */
        shipfriction(x, c);
        return;
    }
    thrust_sound(x, 0x00);                      /* Y unknown - see NOTES   */
    WHITE = 0x00;                               /* the sign extension      */
    a = cos_sin_pi2(g.ram[A_SANGLE + x]);       /* cos = the X change * 4  */
    a = asl8(a, &c);
    if (c) WHITE--;                             /* _20                     */
    x = XCOMP;
    if (g.ram[A_PRTDAMAGE + x] == 0) {
        a = asl8(a, &c);                        /* _25: full power = x4    */
        WHITE = rol8(WHITE, &c);
    }
    c = 0;                                      /* CLC                     */
    g.ram[0x4B + x] = adc8(a, g.ram[0x4B + x], &c);
    a = adc8(WHITE, g.ram[0x0221 + x], &c);
    g.ram[0x0221 + x] = out_range(a);           /* check the range         */

    WHITE = 0x00;
    a = pi_angle0(g.ram[A_SANGLE + x]);         /* sin(angle)              */
    a = asl8(a, &c);                            /* _50                     */
    if (c) WHITE--;                             /* _60                     */
    x = XCOMP;
    if (g.ram[A_PRTDAMAGE + x] == 0) {
        a = asl8(a, &c);                        /* _65                     */
        WHITE = rol8(WHITE, &c);
    }
    c = 0;
    g.ram[A_FRAME + x] = adc8(a, g.ram[A_FRAME + x], &c);
    a = adc8(WHITE, g.ram[0x0253 + x], &c);
    g.ram[0x0253 + x] = out_range(a);
}

/* Shipfriction ($55C6): subtract velocity/128 (rounded away from zero)
 * from each axis of ship x.  carry = the 6502 carry on entry; it only
 * reaches bit 0 of the scratch cell TEMP5 through `ROL TEMP5`, but the
 * oracle sees that store. */
void shipfriction(uint8_t x, int carry)
{
    uint8_t a, y;
    int c = carry;

    y = 0x00;
    TEMP5 = g.ram[0x4B + x];
    if ((uint8_t)(TEMP5 | g.ram[0x0221 + x]) != 0) {
        a = g.ram[0x0221 + x];
        TEMP5 = rol8(TEMP5, &c);
        a = rol8(a, &c);
        a = (uint8_t)(a ^ 0xFF);
        c = 1;                                  /* SEC forms the +1        */
        if (NEG(a)) { y--; c = 0; }             /* DEY / CLC               */
        g.ram[0x4B + x] = adc8(a, g.ram[0x4B + x], &c);     /* _86         */
        g.ram[0x0221 + x] = adc8(y, g.ram[0x0221 + x], &c);
    }
    /* _87 */
    y = 0x00;
    TEMP5 = g.ram[A_FRAME + x];
    if ((uint8_t)(TEMP5 | g.ram[0x0253 + x]) != 0) {
        a = g.ram[0x0253 + x];
        TEMP5 = rol8(TEMP5, &c);
        a = rol8(a, &c);
        c = 1;
        a = (uint8_t)(a ^ 0xFF);
        if (NEG(a)) { y--; c = 0; }             /* _88                     */
        g.ram[A_FRAME + x] = adc8(a, g.ram[A_FRAME + x], &c);
        g.ram[0x0253 + x] = adc8(y, g.ram[0x0253 + x], &c);
    }
}

/* OutRange ($560D): clamp a signed velocity high byte to -$40..+$3F. */
uint8_t out_range(uint8_t a)
{
    if (NEG(a))
        return (a >= 0xC0) ? a : 0xC0;          /* _30: max negative       */
    return (a < 0x40) ? a : 0x3F;               /* max positive            */
}

/* WillAssumeRadiusBar ($561D): place ship x on the rotating bar.  The
 * general path takes cos/sin of BANGLE (+$80 for ship 1), puts the ship
 * at the pair centre +- 2 * that, and adds the tangential velocity
 * 6 * (UWBAR * component) to the pair's velocity, remembering the
 * components in XPOSSAVE/YPOSSAVE and XINCROT/YINCROT.  The x == 0 fast
 * path (only when SDELAY+1 has expired) reuses those saved values. */
static void will_assume_radius_bar(uint8_t x)
{
    uint8_t a, y;
    int c;

    if (x == 0x00 && g.ram[0x026E] == 0) {
        y = 0x00;
        c = 1;
        a = sbc8(0x00, XPOSSAVE, &c);           /* the saved X rel. to bar */
        a = asl8(a, &c);
        if (c) y--;                             /* _72                     */
        c = 0;
        g.ram[0x0341] = adc8(a, g.ram[0x0343], &c);
        g.ram[0x02D6] = adc8(y, g.ram[0x02D8], &c);
        y = 0x00;
        c = 1;
        a = sbc8(0x00, YPOSSAVE, &c);
        a = asl8(a, &c);
        if (c) y--;                             /* _73                     */
        c = 0;
        g.ram[0x0373] = adc8(a, g.ram[0x0375], &c);
        g.ram[0x0308] = adc8(y, g.ram[0x030A], &c);      /* _76            */
        c = 1;
        g.ram[0x0221] = sbc8(g.ram[0x0223], XINCROT, &c);
        c = 1;
        g.ram[0x0253] = sbc8(g.ram[0x0255], YINCROT, &c);
        return;                                 /* (exit)                  */
    }

    /* _15 */
    a = BANGLE;
    if (x != 0x00)
        a = (uint8_t)(a ^ 0x80);
    g.ram[0x16] = a;                            /* _12: the bar angle      */

    /* _20 */
    a = cos_sin_pi2(a);
    XPOSSAVE = a;
    y = 0x00;
    a = asl8(a, &c);
    if (c) y--;                                 /* _25                     */
    x = XCOMP;
    c = 0;
    g.ram[0x0341 + x] = adc8(a, g.ram[0x0343], &c);  /* X of centre of mass */
    g.ram[0x02D6 + x] = adc8(y, g.ram[0x02D8], &c);
    WHITE = XPOSSAVE;
    a = signed_by_signed_mult(UWBAR);
    a = asl8(a, &c);
    TEMP5 = a;
    a = asl8(a, &c);
    c = 0;
    a = adc8(a, TEMP5, &c);                     /* x6                      */
    x = XCOMP;
    YINCROT = a;
    c = 0;
    g.ram[0x0253 + x] = adc8(a, g.ram[0x0255], &c);

    /* _30 */
    a = pi_angle0(g.ram[0x16]);
    x = XCOMP;
    YPOSSAVE = a;
    y = 0x00;
    a = asl8(a, &c);
    if (c) y--;                                 /* _35                     */
    c = 0;
    g.ram[0x0373 + x] = adc8(a, g.ram[0x0375], &c);
    g.ram[0x0308 + x] = adc8(y, g.ram[0x030A], &c);
    WHITE = comp(YPOSSAVE);
    a = signed_by_signed_mult(UWBAR);
    a = asl8(a, &c);
    TEMP5 = a;
    a = asl8(a, &c);
    c = 0;
    a = adc8(a, TEMP5, &c);
    x = XCOMP;
    c = 0;
    XINCROT = a;
    g.ram[0x0221 + x] = adc8(a, g.ram[0x0223], &c);
}

/* ThrustTwoShips ($56F1): ship x thrusting while joined to the bar.  The
 * component of the thrust perpendicular to the bar spins it
 * (LWBAR/UWBAR), the component along the bar translates the pair
 * (BXINCL/BYINCL).  out = the 6502 Y on exit (0 or $FF) - Dorig3 passes
 * it straight to ThrustSound. */
static uint8_t thrust_two_ships(uint8_t x)
{
    uint8_t a, y;
    int c;

    a = BANGLE;
    if (x != 0x00)
        a = (uint8_t)(a ^ 0x80);                /* _5                      */
    g.ram[0x16] = a;
    WHITE = 0x28;
    c = 1;
    TEMP2 = sbc8(g.ram[A_SANGLE + x], g.ram[0x16], &c);   /* relative angle */
    NOBJ = pi_angle0(TEMP2);                    /* sin of the rel. angle   */
    a = output_temp2_temp21(NOBJ);
    y = 0x00;
    if (NEG(a)) y--;                            /* TAX sets the status     */
    c = 0;                                      /* _10                     */
    LWBAR = adc8(a, LWBAR, &c);
    UWBAR = adc8(y, UWBAR, &c);

    WHITE = 0xF0;
    a = output_temp2_temp21(NOBJ);
    g.ram[0x14] = a;
    WHITE = a;                                  /* prepare the next mult   */
    a = signed_by_signed_mult(cos_sin_pi2(g.ram[0x16]));
    y = 0x00;                                   /* the intrinsic /2 undone */
    a = asl8(a, &c);
    if (NEG(a)) y--;                            /* _20                     */
    c = 0;
    BYINCL = adc8(a, BYINCL, &c);
    a = adc8(y, g.ram[0x0255], &c);
    g.ram[0x0255] = out_range(a);

    WHITE = g.ram[0x14];
    a = (uint8_t)(g.ram[0x16] + 0x40);
    a = signed_by_signed_mult(cos_sin_pi2(a));
    y = 0x00;
    a = asl8(a, &c);
    if (NEG(a)) y--;                            /* _30                     */
    c = 0;
    BXINCL = adc8(a, BXINCL, &c);
    a = adc8(y, g.ram[0x0223], &c);
    g.ram[0x0223] = out_range(a);

    WHITE = 0xF0;                               /* the multiplier          */
    a = output_temp2_temp21(cos_sin_pi2(TEMP2));
    g.ram[0x14] = a;                            /* the translation amount  */
    WHITE = a;
    a = signed_by_signed_mult(cos_sin_pi2(g.ram[0x16]));
    y = 0x00;
    POKRAN = asl8(POKRAN, &c);                  /* begin multiply by two   */
    a = rol8(a, &c);
    if (NEG(a)) y--;                            /* _40                     */
    c = 0;
    BXINCL = adc8(a, BXINCL, &c);
    a = adc8(y, g.ram[0x0223], &c);
    g.ram[0x0223] = out_range(a);

    WHITE = g.ram[0x14];
    a = signed_by_signed_mult(pi_angle0(g.ram[0x16]));
    y = 0x00;
    POKRAN = asl8(POKRAN, &c);
    a = rol8(a, &c);
    if (NEG(a)) y--;                            /* _50                     */
    c = 0;
    BYINCL = adc8(a, BYINCL, &c);
    a = adc8(y, g.ram[0x0255], &c);
    g.ram[0x0255] = out_range(a);
    return y;
}

/* Dorigid ($57CE): the combined-lives ships.  With neither ship on screen
 * Dorig2 runs the shared re-entry countdown (and Attract restores both
 * ships once the enemies are gone); otherwise Dorig3 reads the thrust
 * switches, spins the bar and applies its friction. */
void dorigid(void)
{
    if ((uint8_t)(g.ram[0xB8] | OBKLMINES) != 0) {
        dorig3();                               /* one ship is on screen   */
        return;
    }
    /* Dorig2 ($57D4) */
    if (g.ram[0x47] == 0)
        return;                                 /* Dorigex                 */
    if ((uint8_t)(SDELAY | g.ram[0x026E]) == 0)
        return;                                 /* they were not waiting   */
    if (SDELAY != 0)
        SDELAY--;
    if (g.ram[0x026E] != 0)                     /* _10                     */
        g.ram[0x026E]--;
    if ((uint8_t)(SDELAY | g.ram[0x026E]) != 0) /* _20                     */
        return;                                 /* Dorig4                  */
    initiaize_pair();
    if (ship_dead_so_will(0x02, 0x20) != 0)
        goto traffic;                           /* _25                     */
    if (entry_no_requirements_exit() != 0)
        goto traffic;

    /* Attract ($5810) - restore the pair */
    if (NEG(ZP_35)) {                           /* not attract             */
        g.ram[0x47]--;
        g.ram[0x48]--;
    }
    CMBSCFLAG = 0xBF;                           /* _1: score and lives     */
    g.ram[0xB8] = 0x02;
    OBKLMINES = 0x02;
    g.ram[0xBA] = 0x02;
    g.ram[0x53] = 0x00;
    COMOFF = 0x00;                              /* allow the enemies       */
    COMTIMER = 0x00;                            /* end the onslaught       */
    NENTDWARF = 0x00;
    NENTCOMETS = 0x00;
    reset_enemy_timers();
    dorig3();                                   /* falls into Dorig3       */
    return;

traffic:                                        /* Dorig2_25               */
    SDELAY++;
    g.ram[0x026E]++;                            /* if needed               */
}

/* Dorig3 ($5838): the per-frame service of the joined pair - resurrect a
 * damaged-but-absent ship while the fuse burns, read each player's thrust
 * switch (alternate frames, or every frame for the drone), integrate the
 * bar angle by LWBAR/UWBAR and, when neither player is thrusting, apply
 * friction to BXINCL/BYINCL and to the spin. */
static void dorig3(void)
{
    uint8_t a, x, y;
    int c;

    if (NEG(SPARKTIME)) {                       /* the fuse is going       */
        for (x = 0x01; x != 0xFF; x--) {        /* _10                     */
            if (g.ram[0xB8 + x] == 0 &&         /* not here...             */
                g.ram[A_PRTDAMAGE + x] != 0) {  /* ...but was damaged      */
                g.ram[0xB8 + x] = 0x02;         /* return the ship         */
                g.ram[A_ENTER + x] = 0x02;      /* shields on entry        */
            }
        }
    }
    /* _16 */
    x = 0x01;
    for (;;) {
        XCOMP = x;                              /* _20                     */
        if (g.ram[A_SDELAY + x] == 0) {
            if (NEG(ZP_51)) {                   /* the drone thrusts now   */
                c = 0;
                x = 0x00;
            } else {
                a = (uint8_t)(x ^ ZP_44);       /* _50                     */
                (void)lsr8(a, &c);
            }
            /* _55 */
            if (NEG(ZP_35))
                a = sd_hw_in1((uint8_t)(4 + x));    /* _56: STRT1,X        */
            else
                a = sd_hw_pokey_random(1);
            /* _57 */
            if (!c && NEG(a)) {
                y = thrust_two_ships(x);
                x = XCOMP;
                thrust_sound(x, y);             /* thrust on               */
            }
            x = XCOMP;                          /* _70                     */
            will_assume_radius_bar(x);          /* _75                     */
        }
        x = XCOMP;                              /* _71                     */
        if (x == 0)
            break;
        x--;
    }

    c = 0;
    BANGLL = adc8(LWBAR, BANGLL, &c);
    BANGLE = adc8(UWBAR, BANGLE, &c);
    a = sd_hw_in1(4);                           /* STRT1                   */
    if (!NEG(ZP_51))
        a = (uint8_t)(a | sd_hw_in1(5));        /* ORA OPTNA1              */
    (void)asl8(a, &c);                          /* _80                     */
    if (c)
        return;                                 /* an active thrust is on  */

    /* _82: friction on the pair's X velocity */
    y = 0x00;
    TEMP5 = BXINCL;                             /* "not needed"            */
    if ((uint8_t)(TEMP5 | g.ram[0x0223]) != 0) {
        a = (uint8_t)(g.ram[0x0223] ^ 0xFF);
        c = 1;
        if (NEG(a)) { y--; c = 0; }             /* _26                     */
        BXINCL = adc8(a, BXINCL, &c);
        g.ram[0x0223] = adc8(y, g.ram[0x0223], &c);
    }
    /* _27 */
    y = 0x00;
    TEMP5 = BYINCL;
    if ((uint8_t)(TEMP5 | g.ram[0x0255]) != 0) {
        c = 1;
        a = (uint8_t)(g.ram[0x0255] ^ 0xFF);
        if (NEG(a)) { y--; c = 0; }             /* _28                     */
        BYINCL = adc8(a, BYINCL, &c);
        g.ram[0x0255] = adc8(y, g.ram[0x0255], &c);
    }
    /* _29: and on the spin */
    y = 0x00;
    TEMP5 = LWBAR;
    if ((uint8_t)(TEMP5 | UWBAR) != 0) {
        a = (uint8_t)(UWBAR ^ 0xFF);
        c = 1;
        if (NEG(a)) { y--; c = 0; }             /* _36                     */
        LWBAR = adc8(a, LWBAR, &c);
        UWBAR = adc8(y, UWBAR, &c);
    }
}

/* CheckForRocksNearby ($5916) / ShipDeadSoWill ($5918): is any object
 * from y down to 0 too close to (or closing on) ship x?  Returns the
 * 6502 A on exit = Y+1 from L_90; the callers test it with BNE, so zero
 * means "the area is clear". */
uint8_t check_for_rocks_nearby(uint8_t x)
{
    return ship_dead_so_will(x, 0x22);
}

uint8_t ship_dead_so_will(uint8_t x, uint8_t y)
{
    uint8_t a;
    int c;

    for (;;) {
        if (OST(y) == 0)
            goto l80;                           /* the object is not alive */
        c = 1;
        a = sbc8(OXH(y), g.ram[0x02D6 + x], &c);
        if (a < 0x08) {                         /* L_20: close enough      */
            if (a < 0x04) goto l40;             /* very close in X         */
            if (!NEG(OVX(y))) goto l80;         /* going out of the way    */
            goto l40;
        }
        if (a < 0xF9) goto l80;
        if (a < 0xFD) {                         /* not yet "close in X"    */
            if (NEG(OVX(y))) goto l80;          /* going out of the way    */
        }
    l40:
        c = 1;
        a = sbc8(OYH(y), g.ram[0x0308 + x], &c);
        if (a < 0x08) {                         /* L_50                    */
            if (a < 0x04) goto l90;             /* too close               */
            if (NEG(OVY(y))) goto l90;
            goto l80;
        }
        if (a < 0xF9) goto l80;                 /* far away                */
        if (a >= 0xFD) goto l90;                /* too close               */
        if (NEG(OVY(y))) goto l80;              /* going out of the way    */
        goto l90;                               /* close, and coming in    */
    l80:
        y--;
        if (NEG(y))
            break;                              /* falls into L_90         */
    }
l90:
    return (uint8_t)(y + 1);                    /* INY adjusts the Z flag  */
}

/* ================================================================== */
/* wave and object start-up                                            */
/* ================================================================== */

/* Newp2 ($5977): place new rock x.  The special attract wave (SAUMIN bit
 * 7) lines the rocks up on a fixed X grid at Y = $10 with no motion;
 * otherwise GetNewVelocity gives the rock a random velocity around object
 * y's and drops it on the top or the left edge. */
uint8_t newp2(uint8_t x, uint8_t y)
{
    if (!NEG(SAUMIN)) {
        get_new_velocity(x, y);                 /* normal                  */
        return y;                               /* GetNewVelocity/NewRandom
                                                 * VelocityUsing never
                                                 * touch 6502 Y            */
    }
    y = (uint8_t)(x & 0x0F);                    /* the position index      */
    OXH(x) = INITPOS(0x5967 + y);
    OYH(x) = 0x10;                              /* all the same Y position */
    OVX(x) = 0x00;
    OVY(x) = 0x00;                              /* no motion               */
    OXL(x) = 0x00;
    OYL(x) = 0x00;                              /* Newout                  */
    return y;                                   /* Newaex: 6502 Y = x & $0F,
                                                 * which NewastStartNew
                                                 * Asteroids_10 then feeds
                                                 * back into L80RandomWave0
                                                 * ($6FDF STY NOBJ)        */
}

/* GetNewVelocity ($5997). */
static void get_new_velocity(uint8_t x, uint8_t y)
{
    uint8_t a;
    int c;

    new_random_velocity_using(x, y);            /* get a new velocity      */
    a = sd_hw_pokey_random(0);
    a = lsr8(a, &c);
    a = (uint8_t)(a & 0x1F);
    if (c) {                                    /* start on the Y axis     */
        if (a >= 0x18)
            a = (uint8_t)(a & 0x17);            /* _35: keep it 0..767     */
        OYH(x) = a;
        OXH(x) = 0x00;
        OXL(x) = 0x00;
        return;                                 /* (exit - no OBJYL store) */
    }
    OXH(x) = a;                                 /* _50: on the X axis      */
    OYH(x) = 0x00;
    OYL(x) = 0x00;                              /* Newout                  */
}

/* NewastStartNewAsteroids ($59C0): start the next wave.  Waits for the
 * screen to clear, bumps WAVE and the difficulty level $CF, wipes the
 * rock slots, spawns $CF+2 rocks through L80RandomWave0/Newp2, launches
 * $CF-1 killer mines and ramps the rock speed limits ($D5-$D8) by KLMINC.
 * Falls into ResetEnemyTimers. */
void newast_start_new_asteroids(void)
{
    uint8_t a, x, y;
    int c;

    if (SCORE != 0)
        return;                                 /* Newaex: the game ends   */
    if (!NEG(ZP_35)) {                          /* attract                 */
        if ((uint8_t)((ZP_45 & 0x07) | SHHIGH) != 0)
            return;                             /* Newaex: else wait       */
        goto start;                             /* _1                      */
    }
    /* _29 */
    if (entry_no_requirements_exit() != 0)
        return;
    if ((uint8_t)(NENTCOMETS | NENTDWARF) != 0 && COMTIMER != 0)
        return;                                 /* it will wait            */
    /* _71 */
    CMP8(0x03, COMTIMER, &c);
    if (!c)
        COMTIMER = 0x03;
    /* _8: just in case we fell through */
    if (COMTIMER != 0)
        return;
    if (ZP_34 != 0) {                           /* game 0 starts any time  */
        if ((uint8_t)(SDELAY | g.ram[0x026E]) != 0)
            return;
    }

start:                                          /* L5A01 _1                */
    a = 0x00;                                   /* might want this off     */
    if (!NEG(ZP_35))
        a = (uint8_t)(SAUMIN ^ 0x80);           /* the alt special flag    */
    SAUMIN = a;                                 /* _42                     */
    if (NEG(SAUMIN)) {                          /* the special attract     */
        for (x = 0x10; x != 0xFF; x--)          /* _43                     */
            g.ram[0x00B6 + x] = 0x00;           /* saucers, ships, shots   */
    }
    /* _44 */
    g.ram[0x17] = 0xFF;                         /* random spinner direction */
    WAVE++;                                     /* the next wave           */
    c = 0;
    x = KLMINC;                                 /* the difficulty option   */
    a = adc8(g.ram[0xCF], WAVET(0x5BAD + x), &c);
    if (a >= 0x09) a = 0x09;                    /* max out at 9            */
    g.ram[0xCF] = a;                            /* _2                      */
    if (ZP_35 == 0) {
        a = 0x07;
        if (!NEG(SAUMIN))
            a = 0x01;                           /* not the 9-shape attract */
        g.ram[0xCF] = a;                        /* _22                     */
        WAVE = a;
        for (x = 0x05; x != 0xFF; x--)          /* _3                      */
            g.ram[0x00B0 + x] = 0x00;
    }
    /* _4 / _6 */
    c = 0;
    a = adc8(g.ram[0xCF], 0x02, &c);
    NROCKS = a;                                 /* rocks to initiate       */
    y = 0x00;
    a = 0x00;
    for (x = 0x10; x != 0xFF; x--)              /* _7: remove all rocks    */
        OST(x) = a;
    MODNUM = a;                                 /* so it starts over       */
    x = NROCKS;
    OVX(0) = y;                                 /* the "lowest rock"       */
    OVY(0) = y;
    do {                                        /* _10                     */
        a = (uint8_t)(l80_random_wave0(x, y) | 0x04);   /* add the size    */
        OST(x) = a;                             /* set the picture         */
        y = newp2(x, y);                        /* L5A71: Newp2 leaves
                                                 * 6502 Y = x & $0F, which
                                                 * the next pass's
                                                 * L80RandomWave0 stores in
                                                 * NOBJ ($15)              */
        x--;
    } while (x != 0);

    /* _75 */
    g.ram[0x53] = 0x00;                         /* the screen is not full  */
    COMOFF = 0x00;
    c = 1;
    a = sbc8(g.ram[0xCF], 0x01, &c);            /* # = wave - 1            */
    if (a != 0) {
        WHITE = a;                              /* the counter             */
        XINCL = 0x00;                           /* the mines stay          */
        do {                                    /* _76                     */
            initiate_killer_mine();
            WHITE--;
        } while (WHITE != 0);
    }

    /* _80 */
    a = WAVE;
    y = a;                                      /* an extra copy of A      */
    x = KLMINC;
    if ((uint8_t)(a & WAVET(0x5BB1 + x)) == 0) {     /* every N'th wave    */
        c = 0;
        a = adc8(g.ram[0xD7], WAVET(0x5BA5 + x), &c);
        CMP8(a, 0x3F, &c);
        if (!c) {                               /* don't let it go too fast */
            g.ram[0xD7] = a;
            a = (uint8_t)(a ^ 0xFF);
            a = adc8(a, 0x01, &c);              /* the carry was clear     */
            DIFCTY = a;                         /* the max negative too    */
        }
        /* _81 */
        a = y;
        if ((uint8_t)(a & WAVET(0x5BB5 + x)) == 0) {
            a = adc8(g.ram[0xD5], WAVET(0x5BA9 + x), &c);
            CMP8(a, 0x30, &c);                  /* the max min will be $30 */
            if (!c) {
                g.ram[0xD5] = a;
                a = (uint8_t)(a ^ 0xFF);
                a = adc8(a, 0x01, &c);
                g.ram[0xD6] = a;                /* the negative            */
            }
        }
    }
    reset_enemy_timers();
}

/* ResetEnemyTimers ($5AC6): reload both players' rock timer from
 * MXRTIMER and give them the maximum enemy delay. */
void reset_enemy_timers(void)
{
    uint8_t x;
    for (x = 0x01; x != 0xFF; x--) {            /* _85                     */
        g.ram[A_RTIMER + x] = g.ram[A_MXRTIMER + x];
        g.ram[A_ENMDEL + x] = 0x7F;             /* max delay on new rocks  */
    }
}

/* InitiaizePair ($5AD7): reset the bar - horizontal, no spin, no
 * velocity, full shields for both ships - then fall into Newship with
 * X = $02 (the pair centre). */
static void initiaize_pair(void)
{
    BANGLE = 0x00;                              /* horizontal              */
    LWBAR = 0x00;
    UWBAR = 0x00;                               /* no angular acceleration */
    g.ram[0x0223] = 0x00;                       /* no velocity             */
    g.ram[0x0255] = 0x00;
    BANGLL = 0x80;
    BXINCL = 0x80;
    BYINCL = 0x80;
    SPARKTIME = 0x80;
    SHLDENG = 0xF0;
    g.ram[0x0274] = 0xF0;                       /* ship 1's shields too    */
    newship(0x02);
}

/* Newship ($5B00): clear object x's low position bytes and the damage
 * flags, place it at ($10, $0C) and, for the pair ($02, the only entry
 * the ROM ever uses), fire the re-entry sound for both players. */
static void newship(uint8_t x)
{
    g.ram[0x0341 + x] = 0x00;
    g.ram[0x0373 + x] = 0x00;
    PRTDAMAGE = 0x00;                           /* reset the damage        */
    g.ram[0x0389] = 0x00;
    g.ram[0x02D6 + x] = 0x10;
    g.ram[0x0308 + x] = 0x0C;
    if (x == 0x02) {                            /* the pair is back        */
        ENTER = 0x50;                           /* sound & effect          */
        g.ram[0x03E8] = 0x50;
        reenter2(x, 0x00);
        reenter(x, 0x00);
    }
}

/* CopyAttributesOfRock ($5B2B): copy object y's position (and, unless the
 * special attract is running, a fresh picture of the same size) onto
 * object x, then fall into NewRandomVelocityUsing.  Quirk kept: the ROM
 * stores XINC,Y into YINC,X twice and never writes XINC,X. */
void copy_attributes_of_rock(uint8_t x, uint8_t y)
{
    uint8_t a;

    OXL(x) = OXL(y);                            /* copy the position       */
    OXH(x) = OXH(y);
    OYL(x) = OYL(y);
    OYH(x) = OYH(y);
    a = OVX(y);                                 /* copy the velocity       */
    OVY(x) = a;
    OVY(x) = a;
    a = OST(y);                                 /* copy the picture        */
    if (!NEG(SAUMIN)) {                         /* random rocks?           */
        WHITE = (uint8_t)(a & 0x07);            /* save the size           */
        a = (uint8_t)(l80_random_wave0(x, y) | WHITE);   /* a new pic      */
    }
    OST(x) = a;
    new_random_velocity_using(x, y);
}

/* NewRandomVelocityUsing ($5B5E): object x gets object y's velocity plus
 * a random -4..+3 on each axis, clamped by PositiveResulults into the
 * current wave's speed band. */
void new_random_velocity_using(uint8_t x, uint8_t y)
{
    uint8_t a;
    int c;

    a = (uint8_t)(sd_hw_pokey_random(0) & 0xBF);
    if (NEG(a))
        a = (uint8_t)(a | 0xF0);                /* -1 to -4                */
    c = 0;                                      /* _10                     */
    a = adc8(a, OVX(y), &c);
    OVX(x) = positive_resulults(a);             /* check the range         */
    a = (uint8_t)(sd_hw_pokey_random(0) & 0xBF);
    if (NEG(a))
        a = (uint8_t)(a | 0xF0);
    c = 0;                                      /* _40                     */
    a = adc8(a, OVY(y), &c);
    OVY(x) = positive_resulults(a);
}

/* Newve3 ($5B8D) / Newve5 ($5B94) / Newve7 ($5B9A): the band clamps.
 * $D5 = the minimum positive speed, $D6 = the minimum negative, $D7 = the
 * maximum positive, DIFCTY ($D8) = the maximum negative. */
static uint8_t newve3(uint8_t a)
{
    if (a >= g.ram[0xD6]) a = g.ram[0xD6];      /* at least 1/2            */
    return a;
}

static uint8_t newve7(uint8_t a)
{
    if (a < g.ram[0xD5]) a = g.ram[0xD5];       /* not too close to zero   */
    return a;
}

static uint8_t newve5(uint8_t a)
{
    if (a >= g.ram[0xD7]) a = g.ram[0xD7];      /* within range            */
    return newve7(a);
}

/* PositiveResulults ($5B85): clamp a signed rock velocity into the band. */
static uint8_t positive_resulults(uint8_t a)
{
    if (!NEG(a))
        return newve5(a);                       /* positive results        */
    if (a < DIFCTY) a = DIFCTY;                 /* within range            */
    return newve3(a);
}

/* MinVelocity ($5BA1): the same clamp entered with the sign already
 * known - it skips the maximum tests, so it only raises the magnitude.
 * Used when a ship dies and every object is nudged up to the minimum. */
uint8_t min_velocity(uint8_t a)
{
    return NEG(a) ? newve3(a) : newve7(a);
}

/* ================================================================== */
/* rock splitting                                                      */
/* ================================================================== */

/* SearchForFreeRock ($615F) / Searc1 ($6161): scan $97,X downward from X
 * (SearchForFreeRock starts at $10) for a free rock slot.
 * out X = the free slot, or $FF when the scan is exhausted - the ROM's
 * callers test with BMI (the exit N flag is LDA's on the found slot and
 * DEX's on the wrapped $FF), so NEG(result) is exactly that test. */
static uint8_t searc1(uint8_t x)
{
    for (;;) {
        if (OST(x) == 0)                        /* L6161/63: found one     */
            return x;
        x--;                                    /* L6165 DEX               */
        if (NEG(x))                             /* L6166 BPL Searc1        */
            return x;                           /* exhausted ($FF)         */
    }
}

static uint8_t search_for_free_rock(void)
{
    return searc1(0x10);                        /* L615F LDX #$10          */
}

/* SplitRockIntoFragments ($6554): object FOURPI ($0D) was just destroyed
 * in a collision - retire a saucer, score a comet, or split a rock into
 * up to two fragments and explode the original.
 *   in   FOURPI = the victim's object index (the ROM's LDY FOURPI);
 *        OWNER ($38E) = the player who gets the points (bit 7 = nobody).
 *   out  nothing (both call sites are tail JMPs).
 *   RAM  WHITE ($07) = the victim, YTOP ($18) = its picture code - both
 *        oracle-visible scratch.
 * The two callers are DestructionDuringCollision's exits at $44E5 and
 * $4689 (objects.c above).  AlsoUsedFromBelow ($6553) is a shared RTS.
 *
 * The explosion/popsn (x_in, y_in) values are the live 6502 X/Y that the
 * sound triggers park in TEMP5/TEMP6.  On the search-failure paths X is
 * exactly $FF (Searc1's exhausted exit) and on the full-split path it is
 * the second fragment's slot; on the paths that pass through
 * AddPointsToScore, X is that routine's leftover and OWNER is the
 * best-known value (NOTES_objects.md open question 3 - same flag as the
 * $450D/$53E4 sites; Gate P arbitrates). */
void split_rock_into_fragments(void)
{
    uint8_t a, x, y;
    int c;

    y = FOURPI;                                 /* L6554 LDY FOURPI        */
    if (y >= 0x21)                              /* L6556 CPY #$21 / BCS    */
        return;                                 /* a ship or the rod       */
    if (y >= 0x1F) {                            /* L655A CPY #$1F / BCC _3 */
        kill_x_saucer(y);                       /* L655F TAX / JMP (EXIT)  */
        return;
    }
    /* SplitRockIntoFragments_3 */
    if (y >= 0x19)                              /* L6563 CPY #$19 / BCS    */
        return;                                 /* a killer mine: no action */
    if (y >= 0x11) {                            /* L6567 CPY #$11 / BCC _5 */
        up_the_difficulty();                    /* L656B: it was a comet   */
        y = FOURPI;                             /* L656E LDY FOURPI        */
        add_points_to_score(0x20);              /* L6572: 200 points       */
        x = OWNER;      /* X = AddPointsToScore's leftover - see above     */
        goto explode_90;                        /* L6575 JMP _90 (EXIT)    */
    }

    /* _5: a rock (y = 0..$10) */
    WHITE = y;                                  /* L6578 STY WHITE         */
    x = OWNER;                                  /* L657A LDX OWNER         */
    if (!NEG(x)) {                              /* L657D BMI _7: no ship   */
        amount_add_routine_limits(0x10);        /* L657F: 2 seconds a rock */
        a = (uint8_t)(g.ram[A_RTIMER + x] + 0x10); /* L6584-88 CLC/ADC     */
        CMP8(a, g.ram[A_MXRTIMER + x], &c);     /* L658A CMP MXRTIMER,X    */
        if (c)                                  /* BCC _6: under the       */
            a = g.ram[A_MXRTIMER + x];          /* decreasing ceiling      */
        g.ram[A_RTIMER + x] = a;                /* _6 (L6592)              */
    }

    /* _7: halve the size, keep the picture code */
    a = OST(y);                                 /* L6595 LDA $0097,Y       */
    YTOP = (uint8_t)(a & 0x38);                 /* L6599/9B: save pic code */
    a = (uint8_t)((a & 0x07) >> 1);             /* L659E/A0: the new size  */
    x = a;                                      /* L65A1 TAX: score index  */
    a |= YTOP;                                  /* L65A2 ORA YTOP          */

    /* _10 */
    OST(y) = a;                                 /* L65A4: new pic or empty */
    add_points_to_score(obj_rock_points[x]);    /* L65A7/AA (+ 10K check)  */
    y = WHITE;                                  /* L65AD LDY WHITE         */

    /* _20 */
    a = (uint8_t)(OST(y) & 0x07);               /* L65AF/B2: only the size */
    if (a == 0) {                               /* L65B4 BEQ _90           */
        x = OWNER;      /* X = AddPointsToScore's leftover - see above     */
        goto explode_90;                        /* the rock disappeared    */
    }
    if (NEG(SAUMIN)) {                          /* L65B6/B8: special attract */
        a >>= 1;                                /* L65BA LSR: a little one? */
        if (a == 0) {
            x = OWNER;  /* X = AddPointsToScore's leftover - see above     */
            goto explode_90;                    /* L65BB BEQ _90: skip it! */
        }
        x = search_for_free_rock();             /* L65BD                   */
        if (NEG(x))
            goto explode_90;                    /* L65C0 BMI _90: no room  */
        copy_attributes_of_rock(x, y);          /* L65C2: copy it there    */
        OST(x) = 0xA0;                          /* L65C5/C7: and explode it */
        NROCKS++;                               /* L65C9: another "rock"   */
        new_random_velocity_using(y, 0x00);     /* L65CC-D0: the old rock  */
        return;                                 /* keeps moving, off rock 0 */
    }

    /* _21: split for real */
    x = search_for_free_rock();                 /* L65D3                   */
    if (NEG(x)) {                               /* L65D6 BMI _93           */
        OST(y) = 0xA0;                          /* _93 (L6609): explode it */
        popsn(x, y);                            /* L660E JMP Popsn (X=$FF) */
        return;
    }
    NROCKS++;                                   /* L65D8                   */
    copy_attributes_of_rock(x, y);              /* L65DB                   */
    a = (uint8_t)((OVX(x) & 0x1F) << 1);        /* L65DE/E1/E3             */
    OXL(x) ^= a;                                /* L65E4/E7: prevent       */
                                                /* overlapping rocks       */
    x = searc1(x);                              /* L65EA: the second slot  */
    if (NEG(x))
        goto explode_90;                        /* L65ED BMI _90: no room  */
    NROCKS++;                                   /* L65EF                   */
    copy_attributes_of_rock(x, y);              /* L65F2                   */
    a = (uint8_t)((OVY(x) & 0x1F) << 1);        /* L65F5/F8/FA             */
    OYL(x) ^= a;                                /* L65FB/FE                */

explode_90:                                     /* _90 (L6601)             */
    OST(y) = 0xA0;                              /* explode the old rock    */
    explosion(x, y);                            /* L6606 JMP Explosion     */
}

/* ================================================================== */
/* shields and the score area                                          */
/* ================================================================== */

/* ProcessShields ($5BB9): read each player's shield switch and, if he has
 * energy left and is actually on screen, raise the shield ($4F/$50 bit
 * 7), make the shield noise and burn energy. */
void process_shields(void)
{
    uint8_t x, y, a;

    for (x = 0x01; x != 0xFF; x--) {            /* _20                     */
        a = (uint8_t)(g.ram[0x4F + x] & 0x7F);
        g.ram[0x4F + x] = a;
        y = twin_game_both_shields(x);          /* read the shield switch  */
        if (!NEG(y))
            continue;                           /* _80                     */
        y = g.ram[0xB8 + x];
        if (y == 0 || NEG(y))
            continue;                           /* alive but not showing / */
                                                /* suspended animation     */
        y = g.ram[A_SHLDENG + x];
        if (y == 0)
            continue;                           /* _80: no energy left     */
        g.ram[0x4F + x] = (uint8_t)(a | 0x80);
        if (x == 0x01)
            sh1sn(x, y);                        /* _41: shield sound       */
        else
            sh0sn(x, y);
        game23_shields(x);                      /* _43: take out energy    */
    }
}

/* TwinGameBothShields ($5BE9): out = the 6502 Y, the raw IN1 byte of
 * player x's shield/hyperspace switch (bit 7 = pushed).  In attract, and
 * in game 3 where a single player owns both ships, the ROM substitutes
 * $0900 / zero. */
uint8_t twin_game_both_shields(uint8_t x)
{
    if (!NEG(ZP_35))
        return 0x00;                            /* _40: skip in attract    */
    if (ZP_34 == 0x03)
        return sd_hw_in1(0);                    /* one player              */
    return sd_hw_in1(x);                        /* _30: HYPSW,X            */
}

/* Game23Shields ($5BFD): drain player x's 16-bit shield energy
 * LSHLDENG/SHLDENG by $30 ($18 in games 2 and 3), flooring at $18 -> 0. */
void game23_shields(uint8_t x)
{
    uint8_t a;
    int c = 1;

    if (ZP_34 >= 0x02)                          /* games 2&3 drop at half  */
        a = sbc8(g.ram[A_LSHLDENG + x], 0x18, &c);
    else
        a = sbc8(g.ram[A_LSHLDENG + x], 0x30, &c);   /* _45                */
    g.ram[A_LSHLDENG + x] = a;                  /* _46                     */
    a = sbc8(g.ram[A_SHLDENG + x], 0x00, &c);   /* SBC 1 if borrow         */
    if (a < 0x18)
        a = 0x00;
    g.ram[A_SHLDENG + x] = a;                   /* _70                     */
}

/* Temp3WhichPlayer0 ($5C24): draw one score area - three BCD digit pairs
 * plus a phantom zero, then, unless PL0SCFLAG bit 6 says the lives live
 * elsewhere, one ship glyph per remaining life.  a = the zero-page
 * address of the three score bytes; XCOMP = the area index (0/1/2); the
 * list pointer and UPDOWN are staged by the caller (display.c). */
void temp3_which_player0(uint8_t a)
{
    uint8_t x, xx, ac, y;

    save_input_parameters(a, 0x03, 1);          /* 3 digit pairs, zero supp */
    (void)display_digit(0x00);                  /* add a phantom 0         */
    x = XCOMP;
    if (NEG((uint8_t)(g.ram[A_PL0SCFLAG + x] << 1)))
        return;                                 /* _80: hues are fine      */
    if (NEG(LASTSW)) {                          /* combined lives          */
        if (x != 0x02)
            goto rtsl;                          /* _70: no individual lives */
        x = 0x00;                               /* check player 0's lives  */
    }
    a = g.ram[0x47 + x];                        /* _30                     */
    if (a == 0 || NEG(a))
        goto rtsl;                              /* _40 / _70               */
    WHITE = a;                                  /* _50: the glyph count    */
    if (ZP_34 == 0x03)
        UPDOWN = ZP_34;                         /* game 3: never flipped   */
    xx = 0xA8;                                  /* _51                     */
    ac = 0x4E;
    if (NEG(UPDOWN)) {
        xx = 0xA8;
        ac = 0x52;
    }
    vg_add2(ac, xx);                            /* _55                     */
    do {                                        /* _60                     */
        y = XCOMP;
        if (NEG(UPDOWN)) {
            ac = VROM(0x30B1 + y);              /* the flipped ship glyph  */
            xx = VROM(0x30B3 + y);
        } else {
            ac = VROM(0x30AC + y);              /* the ship glyph JSRL     */
            xx = VROM(0x30AF + y);
        }
        vg_add2(ac, xx);                        /* _65                     */
        WHITE--;
    } while (WHITE != 0);
rtsl:                                           /* _70                     */
    vg_add_rtsl();
}

/* ================================================================== */
/* killer-mine start-up                                                */
/* ================================================================== */

/* InitiateKillerMine ($672D): find a free killer-mine slot ($B0-$B5 =
 * objects $19-$1E), point it at a ship, drop it on one edge at a random
 * position and load its speed / turn rate from the KLMINC-indexed ramps
 * at $6CD9 (game 1, games 2&3, game 0).  Only in a game ($35 bit 7);
 * Inexit ($672C) is the shared RTS. */
void initiate_killer_mine(void)
{
    uint8_t x, y, a;
    int c;

    if (!NEG(ZP_35))
        return;                                 /* Inexit: not in attract  */
    for (x = 0x05; ; x--) {                     /* _20                     */
        if (g.ram[0x00B0 + x] == 0)
            break;                              /* _25: a free slot        */
        if (x == 0)
            return;                             /* _90: none left          */
    }

    y = 0x21;                                   /* _25: default for alone  */
    if (ZP_34 != 0x01) {
        (void)lsr8(x, &c);
        if (!c)
            y++;                                /* even mines -> ZSHIP+1   */
    }
    g.ram[A_KTARGET + x] = y;                   /* _29                     */
    TEMP4 = x;                                  /* save X                  */
    a = (uint8_t)((KLMINC ^ 0xFF) & 0x03);      /* the offset into the table */
    c = 0;
    y = adc8(a, TEMP4, &c);                     /* plus the mine offset    */
    g.ram[0xC9 + x] = 0x01;                     /* the start colour (blue) */
    g.ram[0x02CE + x] = sd_hw_pokey_random(0);  /* a random start point    */
    g.ram[0x0300 + x] = sd_hw_pokey_random(1);
    a = 0x00;                                   /* now put it on one edge  */
    if (NEG(ZP_44))
        g.ram[0x02CE + x] = a;
    else
        g.ram[0x0300 + x] = a;                  /* _31                     */

    /* _32 */
    if (NEG(LASTSW)) {                          /* combined lives: 2 & 3   */
        g.ram[0x00B0 + x] = KMT(0x6CEB + y);    /* SpeedTableSpaceStation  */
        a = KMT(0x6CF4 + y);                    /* AngleChangeSpeedSpace   */
    } else if (ZP_34 != 0) {                    /* _30: game 1 only        */
        g.ram[0x00B0 + x] = KMT(0x6CD9 + y);    /* SpeedTableGame1         */
        a = KMT(0x6CE2 + y);                    /* AngleChangeSpeedGame    */
    } else {                                    /* _50: game 0             */
        g.ram[0x00B0 + x] = KMT(0x6CFD + y);    /* SpeedTableGame0         */
        a = KMT(0x6D06 + y);                    /* AngleChangeSpeedGame2   */
    }
    g.ram[A_KANGCH + x] = a;                    /* _35                     */

    /* _40 */
    g.ram[A_KSPEED + x] = 0x00;
    if (ZP_34 == 0)
        return;                                 /* _90: no game-0 tweak    */
    a = WAVE;
    a = asl8(a, &c);
    if (NEG(a))
        return;                                 /* _90: don't go negative  */
    a = adc8(a, g.ram[0x00B0 + x], &c);
    if (NEG(a))
        return;                                 /* _90                     */
    g.ram[0x00B0 + x] = a;
}


