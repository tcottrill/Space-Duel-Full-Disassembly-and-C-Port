/* mainline.c - Space Duel C port: boot + the Start2 mainline frame loop.
 *
 * Covers (one C function per ROM routine, addresses in comments):
 *   Poweron $803F (game path), StartThingsRunning $80AB,
 *   SetUpInitialsHigh $80D4, Pwron $68CA, LswVectorAddress $6C96,
 *   the Start2 loop $4012-$4159 (entries InitializePlayer1Start $400C /
 *   StartUpNewAsteroids $400F), CheckForStartEnd $415A + Chkst1 $4357,
 *   Nxtstep $43A3, Gtoptn $76DB, Bigbang $76CC, UsesTemp1Temp11 $68FD
 *   with its frame-service chain Frame0FrameOff $6952 / Frca30 $69E4 /
 *   Frame07f $6A1F / Frame0f $6A2E / Frame07 $6A46 / DoneAbove $6A89,
 *   Onslaught $6AD1, QuickEndEndOnslaught $6B1C, CometCalculations $6C65
 *   and the anonymous comet-slot entry L6C79 (sub_6c79).
 *
 * Frame-loop model (documented in NOTES_mainline.md): sd_mainline_frame()
 * is ONE pass of the Start2 loop; the ROM's re-entry JMPs (Start2_76 ->
 * StartUpNewAsteroids, Start2_14 -> InitializePlayer1Start, Start2_15 ->
 * Start2) become tail calls of the entry prologues followed by return, so
 * the executed instruction order is exactly the ROM's.
 *
 * Dropped hardware artifacts (CONVENTIONS rule 7), each noted in place:
 * SEI/CLI, TXS stack resets, CLD, every STA WTCHDG watchdog kick, and the
 * IRQ-atomicity SEI/CLI brackets around the POKEY DIP reads (the seam
 * calls are atomic in C).
 */
#include "sd_state.h"
#include "sd_hw.h"
#include "vgutil.h"
#include "mainline.h"

/* ------------------------------------------------------------------ */
/* module externs (translated elsewhere; label + ROM address)          */
/* ------------------------------------------------------------------ */

/* --- objects / game logic (objects.c, being written concurrently -
 * plain externs per CONVENTIONS 1c; do NOT create/edit objects.c) --- */
extern void initialization(void);            /* Initialization $4F66        */
extern void newast_start_new_asteroids(void);/* NewastStartNewAsteroids $59C0 */
extern void fire_ships_torpedos(uint8_t x);  /* FireShipsTorpedos $4C70, x = ship */
extern void move_ship(uint8_t x);            /* MoveShip $54A1, x = ship    */
/* KillerMines $4937 (falls into DoEnemy $4934 -> CompetitiveWantWaitOther)
 * and MotionUpdateRoutine $5174 are two separate JSRs at $40F8/$40FB, but
 * they are X-coupled: MotionUpdateRoutine's straddle test indexes $0308,X
 * ($517D) and $02D6,X ($5193) with whatever 6502 X KillerMines left behind.
 * So killer_mines() returns its exit X and the call site threads it. */
extern uint8_t killer_mines(uint8_t x);      /* KillerMines $4937           */
extern void motion_update_routine(uint8_t x);/* MotionUpdateRoutine $5174   */
extern void process_shields(void);           /* ProcessShields $5BB9        */
extern void collision_detector(void);        /* CollisionDetector $43B7     */
extern void initiate_killer_mine(void);      /* InitiateKillerMine $672D    */
extern void stop_fuse_sound(void);           /* StopFuseSound $6B57 (sound.c) */
extern void get_comet_to_go(void);           /* GetCometToGo $468C          */
/* --- comet spawn helpers (objects.c / lowones.c) --- */
extern void    sbttl_stcomet(uint8_t x);     /* SbttlStcomet $53C7          */
extern uint8_t find_difference_coordinates(uint8_t x, uint8_t y); /* $491F  */
extern uint8_t reset_timers(void);           /* ResetTimers $4B5C (out = X) */
extern uint8_t entry_input_exit_absolute(uint8_t a); /* $684B: A -> |A|     */
/* --- this module's own comet/fireworks routines (defined below) --- */
void since_cannot_get_must(void);            /* SinceCannotGetMust $6AA5    */
static void bells_wistles(void);             /* BellsWistles $768D          */
/* Inco10 $6B6D (InitializeComet body): x = highest object slot to scan,
 * y = which player's comets (0/1); WHITE ($07) and EACE ($08, target
 * object) are staged in RAM by the caller first.  Returns its exit 6502 X
 * (Onslaught's tail JMP ignores it; CompetitiveWantWaitOther needs it). */
uint8_t inco10(uint8_t x, uint8_t y);
/* AccHoldsAngleObject $4956: JSR FindDifferenceCoordinates then Klmi7;
 * x = object slot (XCOMP already = x), y = object tracked. */
extern void acc_holds_angle_object(uint8_t x, uint8_t y);
/* GetWrapAroundAngle $48ED: angle from object x to object y through the
 * screen wrap; returns 6502 A (the angle). */
extern uint8_t get_wrap_around_angle(uint8_t x, uint8_t y);
extern void klmi7(uint8_t a_angle);          /* Klmi7 $4959 (uses XCOMP)    */

/* --- display (display.c, on disk - signatures verified against display.h) - */
extern void inset2(void);                    /* Inset2 $4FEE                */
extern void spark2(void);                    /* Spark2 $638F                */
/* AmountAddRoutineLimits $67B6: a = amount added to the 16-bit onslaught
 * timer LNGTIMER/$3BA, saturating at $03FF. */
extern void amount_add_routine_limits(uint8_t a);
extern int  get_players_initials(void);      /* GetPlayersInitials $4DCD; C
                                              * flag: 1 = entry finished    */
extern int  scores(void);                    /* Scores $6004; C flag: 1 =
                                              * doing score table           */
extern void score_color_based_above(void);   /* ScoreColorBasedAbove $50C0  */
extern void entparams(void);                 /* Entparams $5C80             */
extern void display_parameters(void);        /* DisplayParameters $5CF2     */

/* --- NOT YET IMPLEMENTED ANYWHERE (see NOTES_mainline.md open questions):
 * these three have no home module on disk yet (not in display.h/earom.h/
 * any other header found). Addresses and call-site register protocols are
 * confirmed from the listing; extern kept per CONVENTIONS 1c so mainline.c
 * compiles/links once a module supplies them. --- */
extern void update_info_at_end(void);        /* UpdateInfoAtEnd $893E (earom
                                              * region, $87xx-$8Bxx)        */
extern void update_high_score_table(void);   /* UpdateHighScoreTable $6614
                                              * (near Scores $6004)         */
extern void display_4_names(void);           /* Display4Names $7529 (game-
                                              * select boxes; entry LDY #$03
                                              * makes the caller's Y dead)  */

/* --- messages (msgs.c) --- */
extern void mesgpos(uint8_t a_dx, uint8_t x_dy);        /* Mesgpos $7760    */
extern void vector_generator_message_processor(uint8_t y_msg); /* $7770     */
extern void brightness(uint8_t x_color, uint8_t y_msg); /* Brightness $7772 */
extern void pass_color(uint8_t a_color, uint8_t y_msg); /* PassColor $7773  */
extern void aux_routine_add_offset(uint8_t x_row);      /* $7730            */

/* --- sound (sound.c) --- */
extern void inisou(void);                    /* Inisou $73A8                */
extern void force_field_up(void);            /* ForceFieldUp $73D4          */
extern void l2_saucers(void);                /* L2Saucers $7091             */
/* Gates $72ED: high-score-table tune trigger. Parks the caller's live
 * 6502 X/Y in TEMP5/TEMP6 (oracle-visible), so the C caller passes them. */
extern void gates(uint8_t x_in, uint8_t y_in);

/* --- per-frame star service (lowones.c) --- */
extern void do_low_ones_every(void);         /* DoLowOnesEvery $6EE5        */

/* --- self-test (selftest.c) --- */
extern void beginning_pattern(void);         /* BeginningPattern $8110      */
extern void all_stop_please(void);           /* AllStopPlease $8A1D         */
extern int  selftest_frame(void);            /* one pass of a parked test loop */
extern void sd_cpu_loop_reset(void);         /* Poweron: CPU back in Start2 */

/* --- EAROM (earom.c) --- */
extern void read_everything(void);           /* ReadEverything $8777        */
extern void copy_from_buffer_back(void);     /* CopyFromBufferBack $88B6    */
extern void copy_ontime_from_buffer(void);   /* CopyOntimeFromBuffer $89A3  */

/* ------------------------------------------------------------------ */
/* Gtoptn / Bigbang / Nxtstep                                          */
/* ------------------------------------------------------------------ */

/* Gtoptn ($76DB): read the difficulty DIPs (POKEY1 $1008 behind a $100B
 * strobe = sd_hw_pokey1_diffsw()), set the killer-mine difficulty index
 * and language, and - only outside a game - the bonus level and the
 * per-player life counts. No register protocol (A/X/Y clobbered). */
void gtoptn(void)
{
    uint8_t a, x, y;

    /* L76DB SEI / STA $100B / LDA $1008 / CLI: the strobe+read seam call */
    a = (uint8_t)(sd_hw_pokey1_diffsw() ^ 0x85);  /* correct for all-off  */
    EASRCE = a;                             /* L76E5 STA EASRCE ($D0)     */
    a >>= 2;                                /* LSR/LSR: d2,d3 to bottom   */
    y = a;                                  /* TAY                        */
    x = (uint8_t)(a & 0x03);                /* switch setting             */
    /* L76ED LDA $34 / LSR / LSR: carry = game bit 1 = space-station game */
    if (ZP_34 & 0x02)
        x = (uint8_t)(x + 4);               /* second table of 4          */
    KLMINC = mainline_fighters[x];          /* L76F7: level from table    */
    a = (uint8_t)((y >> 2) & 0x03);         /* TYA/LSR/LSR/AND #$03       */
    g.ram[0xD1] = a;                        /* language (AS2MSG reads it) */
    if (ZP_35 & 0x80)                       /* BIT $35 / BMI Gtoptn_10    */
        return;                             /* not while a game is going  */
    /* L7709 ROL/ROL/ROL then AND #$03 == the top two bits of EASRCE (the
     * carry the first ROL shifts in lands in bit 2 and is masked off) */
    x = (uint8_t)((EASRCE >> 6) & 0x03);
    a = mainline_bonus_optn[x];             /* L770F                      */
    OPTN1 = a;
    LANG = a;
    DIFF = a;                               /* bonus level                */
    a = (uint8_t)((EASRCE & 0x03) + 0x03);  /* L7718: CLC/ADC -> 3..6     */
    g.ram[0x47] = a;                        /* ship hits (lives), plyr 1  */
    g.ram[0x48] = a;                        /* ship hits (lives), plyr 0  */
}

/* BellsWistles ($768D): the end-of-game "special explosion" fireworks
 * (SPECEX bit 7, Frame07).  One rock slot per call - NEXTEX ($3F5) is the
 * round-robin cursor 0-$0F - and a free slot ($97,X == 0) is re-seeded as
 * a random explosion picture at a random position, drifting upward.
 * RANDOM reads per seeded slot: $100A, $140A, $100A, $140A, $100A (five;
 * a busy slot reads none) - LFSR-visible, so the order is kept exactly.
 * ENTRY-CARRY QUIRK: the `ADC #$40` at $76BC runs on the CALLER's carry
 * (nothing from either Frame07 entry down to here touches C).  C = 0 is
 * assumed, the same call as Shipfriction's $54AB entry (NOTES_objects.md
 * open question 4); Gate P arbitrates if it ever shows. */
static void bells_wistles(void)
{
    uint8_t x = NEXTEX;                     /* L768D                      */
    if (g.ram[0x97 + x] == 0) {             /* L7690/92 BNE _40: done?    */
        g.ram[0x97 + x] =
            (uint8_t)(sd_hw_pokey_random(0) & 0x17);    /* L7694/97/99    */
        /* _15 */
        g.ram[A_OBJXH + x] =
            (uint8_t)(sd_hw_pokey_random(1) & 0x1F);    /* L769B-76A0     */
        g.ram[A_OBJXL + x] = sd_hw_pokey_random(0);     /* L76A3/A6       */
        g.ram[A_OBJYL + x] = sd_hw_pokey_random(1);     /* L76A9/AC       */
        g.ram[A_OBJYH + x] = 0x00;          /* L76AF/B1                   */
        g.ram[A_XINC + x] = 0x00;           /* L76B4: no X motion         */
        g.ram[A_YINC + x] =                 /* L76B7-BE: random velocity, */
            (uint8_t)((sd_hw_pokey_random(0) & 0x3F) + 0x40);  /* min $40 */
    }
    /* _40 */
    x++;                                    /* L76C1 INX                  */
    if (x >= 0x10)                          /* L76C2/C4 CPX #$10 / BCC    */
        x = 0x00;                           /* start over                 */
    NEXTEX = x;                             /* _20 (L76C8)                */
}

/* Bigbang ($76CC): remove every object. A/X clobbered (X exits $FF). */
void bigbang(void)
{
    uint8_t x;
    for (x = 0x2F;; x--) {                  /* Bigbang_10                 */
        g.ram[0x97 + x] = 0;                /* object status table        */
        if (x == 0) break;                  /* DEX/BPL                    */
    }
    NROCKS = 0;                             /* no rocks                   */
    SAUMIN = 0;                             /* no special                 */
}

/* Nxtstep ($43A3): step $34 to the next game via TableGameOrder; on a
 * caberet cabinet (CABERE bit 6) repeat until an odd (1-player) game.
 * Returns the 6502 A: the new game number, except on the caberet exit
 * where the LSR has already halved it ($34 itself always holds the real
 * game number). $34 is provably 0-3 (cleared at boot; written only from
 * the table and LASTG&3), so the table index needs no mask. */
uint8_t nxtstep(void)
{
    uint8_t a;
    for (;;) {
        a = mainline_game_order[ZP_34];     /* L43A3 LDX $34 / LDA tbl,X  */
        ZP_34 = a;                          /* next                       */
        if (!(sd_hw_in1(7) & 0x40))         /* BIT CABERE / BVC Nxtstep_10 */
            return a;
        if (a & 0x01)                       /* LSR / BCC Nxtstep          */
            return (uint8_t)(a >> 1);       /* odd game: exit, A halved   */
    }
}

/* ------------------------------------------------------------------ */
/* CheckForStartEnd / Chkst1                                           */
/* ------------------------------------------------------------------ */

/* Chkst1 ($4357): game in progress - detect "everything gone" and start
 * the game-over sequence. Returns the C flag (always 0). */
int chkst1(void)
{
    uint8_t a, x;

    a = (uint8_t)(g.ram[0x48] | g.ram[0x47] |   /* hits (lives) left?     */
                  g.ram[0xB8] | OBKLMINES);     /* ships still living?    */
    if (a != 0) return 0;                       /* Chkst1_90              */
    if (ZP_34 == 0) {                           /* competitive game       */
        a = (uint8_t)(PRTDAMAGE & g.ram[0x389]);/* both ships damaged?    */
        if (!(a & 0x80)) return 0;              /* one not damaged        */
    }
    /* Chkst1_20 */
    if (SCORE != 0) return 0;                   /* already ending         */
    for (x = 7;; x--) {                         /* Chkst1_10              */
        if (g.ram[A_OBSAUCER + x] != 0)         /* $BF-$C6 still active   */
            return 0;
        if (x == 0) break;
    }
    score_color_based_above();                  /* slow down rocks        */
    WAVE = 0x01;                                /* back to wave 1         */
    g.ram[0x53] = 0;                            /* let rocks come back    */
    x = 0x40;
    a = (uint8_t)(ZP_38 & 0x39);                /* L438A AND #$39: ROM bug,
                                                 * immediate where AND $39
                                                 * was surely meant - the
                                                 * result can never be
                                                 * minus, so...           */
    if (!(a & 0x80))
        x = 0x10;                               /* ...X is always $10     */
    SCORE = x;                                  /* Chkst1_17: end timer   */
    STRTLOK = 0x80;                             /* no starts allowed      */
    update_info_at_end();
    update_high_score_table();
    LANGBT = 0x00;                              /* start coin routine     */
    return 0;
}

/* CheckForStartEnd ($415A): the per-frame attract/credit/start service.
 * Returns the C flag: 1 = start button accepted, begin a new game (the
 * mainline then re-enters through InitializePlayer1Start). */
int check_for_start_end(void)
{
    uint8_t a, y;

    if (ZP_35 != 0) {                           /* game in progress?      */
        if (SCORE == 0)
            return chkst1();                    /* L4162 JMP Chkst1       */
        /* CheckForStartEnd_6: game-over sequence running */
        SCORE++;                                /* L4165 INC SCORE        */
        if (SCORE != 0) {                       /* BEQ _7: not over yet   */
            mesgpos(0xE4, 0x04);                /* position message       */
            UPDOWN = 0x07;                      /* LDY #$07 / STY UPDOWN:
                                                 * normal message always  */
            vector_generator_message_processor(0x07);  /* GAME OVER       */
            COMTIMER = 0x00;                    /* end onslaught          */
            SHHIGH = 0xFF;                      /* show high scores once  */
            return 0;                           /* CLC                    */
        }
        /* CheckForStartEnd_7: sequence complete */
        inisou();                               /* turn off sounds        */
        bigbang();                              /* remove all             */
        a = (uint8_t)(ZP_38 & ZP_39);
        if (!(a & 0x80)) {                      /* BMI _65 skips          */
            /* Live 6502 registers at $4190: X = $FF (Bigbang's DEX/BPL
             * exit), Y = 1 (every path into CheckForStartEnd leaves the
             * last VG word appender's Y; see NOTES_mainline.md). Gates
             * parks them in TEMP5/TEMP6. */
            gates(0xFF, 0x01);                  /* high score sound       */
            SPECEX = 0x00;
        }
        /* CheckForStartEnd_65 */
        ZP_35 = 0;
        RDELAY = 0;
        g.ram[0x53] = 0;                        /* allow rocks back       */
        SDELAY = 0;
        g.ram[0x26E] = 0;                       /* SDELAY, ship 1         */
        g.ram[0xB8] = 0;
        OBKLMINES = 0;
        return 0;                               /* CLC                    */
    }

    /* CheckForStartEnd_10: attract mode */
    a = (uint8_t)(TEMP8 | TEMPB | ZP_44);       /* no credit, coins, and  */
    if (a == 0) {                               /* frame counter just 0   */
        a = (uint8_t)((ZP_45 & 0x07) ^ 0x02);
        if (a == 0) {                           /* attract stage 2        */
            y = 0x00;                           /* LDY #$00               */
            a = nxtstep();                      /* step to next game      */
            if (a != 0 && a >= 0x02)            /* BEQ _4 / CMP #$02 BCC  */
                y = 0x80;
            LASTSW = y;                         /* CheckForStartEnd_4     */
            gtoptn();                           /* options + lives        */
            SDELAY = 0x20;                      /* make ship appear       */
            g.ram[0x26E] = 0x20;
            SCSHSP = 0x80;                      /* want saucers mad       */
            g.ram[0x39E] = 0x80;
            g.ram[0xB8] = 0;                    /* turn off old ship      */
            OBKLMINES = 0;
            IANGLE = 0;                         /* point straight up      */
            g.ram[0x3D1] = 0;
        }
    }
    /* CheckForStartEnd_3 */
    if (!(LANGBT & 0x80)) {                     /* coin routine running   */
        a = 0x08;
        if (TEMP8 >= 0x12)                      /* CPY #$12 / BCC _1      */
            TEMP8 = 0x12;                       /* credit limit           */
    } else {
        a = 0x00;                               /* CheckForStartEnd_11    */
    }
    g.ram[0x31] = a;                            /* _1: lamp/lockout latch */
    if (SHHIGH != 0)
        SHHIGH--;                               /* high-score-table timer */
    /* CheckForStartEnd_8 */
    TEMP2 = 0x00;                               /* default: sell players  */
    XINCL = 0x00;                               /* for attract            */
    /* LDY #$08 then INY at _12 leaves Y = 9, dead (overwritten below)   */
    if (sd_hw_in1(5) & 0x40)                    /* BIT OPTNA1 / BVC _12   */
        TEMP2--;                                /* selling games: -> $FF  */
    /* _12: SEI / STA $140B / LDA $1408 / CLI = the option-DIP seam read */
    a = (uint8_t)(sd_hw_pokey2_optionsw() ^ 0x02);  /* all-off correction */
    ZMINE = a;
    a &= 0x03;
    if (a == 0) {                               /* free play              */
        TEMP8 = 0x02;
        TEMP7B = 0x02;                          /* no 2-coin minimum      */
        goto c15;                               /* BNE _15 (always)       */
    }
    /* CheckForStartEnd_35 */
    a = (uint8_t)(a + 0x07);                    /* CLC/ADC #$07           */
    if (TEMP2 & 0x80)                           /* BIT TEMP2 / BPL _9     */
        a = (uint8_t)(a + 0x0D);                /* coin mode message      */
    y = a;                                      /* CheckForStartEnd_9     */
    YTOP = 0xC6;
    /* CheckForStartEnd_80: 2-coin-minimum messaging */
    if (sd_hw_in1(6) & 0x40) {                  /* BIT GAMSEL / BVC _82   */
        a = TEMP8;
        if (a == 0) {
            TEMP7B = 0x80;                      /* L4246                  */
        } else if (a != 0x01) {
            goto c82;                           /* easy way out           */
        }
        /* L4251 */
        if (!(TEMP7B & 0x80))
            goto c83;                           /* 1 credit, min satisfied */
        if ((ZP_44 & 0x20) == 0) {
            y = 0x12;                           /* alt message            */
            YTOP = 0xC4;
        }
        goto c81;
    }
c82:
    TEMP7B = 0x00;                              /* don't allow this       */
c83:
    if ((ZP_44 & 0x20) != 0)
        goto c15;                               /* flash the message      */
c81:
    a = (uint8_t)(ZP_38 & ZP_39);
    if (!(a & 0x80))
        goto c15;                               /* updating initials      */
    if (SHHIGH != 0)
        goto c15;                               /* high score table up    */
    /* TYA/PHA brackets the message positioning */
    mesgpos(0xD3, 0x49);
    aux_routine_add_offset(0x00);               /* language X offset      */
    brightness(YTOP, y);                        /* LDX YTOP / PLA,TAY     */
c15:
    y = TEMP8;
    if (y == 0) {                               /* no credit...           */
        y = TEMPB;                              /* ...any coins?          */
        if (y == 0) {
            /* CheckForStartEnd_14 */
            g.ram[0x31] |= 0x30;                /* turn off lights        */
            return 0;                           /* CLC                    */
        }
        goto c47;                               /* game display (Y=TEMPB,
                                                 * dead in Display4Names) */
    }
    /* CheckForStartEnd_16: debounce the game-select switch */
    a = sd_hw_in1(6);                           /* LDA GAMSEL             */
    SAVBOT = (uint8_t)((SAVBOT >> 1) |          /* ASL (C = d7) then      */
                       ((a & 0x80) ? 0x80 : 0));/* ROR SAVBOT             */
    /* CheckForStartEnd_17 */
    if (!(STRTLOK & 0x80) &&                    /* locked out?            */
        !(TEMP7B & 0x80) &&                     /* starts locked out?     */
        (sd_hw_in1(4) & 0x40)) {                /* BIT STRT1 / BVC _40    */
        /* start pushed */
        if (!(TEMP2 & 0x80)) {                  /* selling players...     */
            if (!(ZP_34 & 0x01))                /* LSR / BCS _20: even    */
                TEMP8--;                        /* games cost 2 credits   */
        }
        /* CheckForStartEnd_20 */
        TEMP8--;                                /* ...and this is one     */
        g.ram[0x31] &= 0xDF;                    /* turn on start lamp     */
        STRTLOK = 0x00;                         /* reset start lockout    */
        SPECEX = 0x00;                          /* in case this was on    */
        FLSFLG = 0xFF;                          /* no new high scores     */
        g.ram[0x3EC] = 0xFF;
        LASTG = ZP_34;                          /* save last game         */
        gtoptn();                               /* diff level, this game  */
        return 1;                               /* SEC: new game          */
    }
    /* CheckForStartEnd_40 */
    a = (uint8_t)((ZP_44 & 0x18) << 1);         /* lamp flash rate        */
    if ((SAVBOT & 0x80) &&                      /* BIT SAVBOT: pressed... */
        !(SAVBOT & 0x40) &&                     /* ...and not last time   */
        !(TEMP7B & 0x80)) {                     /* not held by 2-coin min */
        if (STRTLOK & 0x80) {                   /* BIT STRTLOK / BPL _41  */
            a = (uint8_t)(LASTG & 0x03);        /* just in case not init  */
            ZP_34 = a;
        } else {
            SHHIGH = 0x00;                      /* _41: no high score     */
            a = nxtstep();                      /* _44: next game         */
        }
        /* CheckForStartEnd_42 */
        STRTLOK = 0x40;                         /* set pushed flag        */
        ZP_38 = 0xFF;
        ZP_39 = 0xFF;                           /* abort any initials     */
        SHHIGH = 0x00;                          /* abort table            */
    }
    /* CheckForStartEnd_43 */
    if (STRTLOK & 0x80)
        a |= 0x20;                              /* no start lamp flash    */
    for (;;) {
        /* CheckForStartEnd_46: bits $30 of A replace those of $31 */
        a = (uint8_t)(((a ^ g.ram[0x31]) & 0x30) ^ g.ram[0x31]);
        g.ram[0x31] = a;
        a = mainline_ttplayr[ZP_34];            /* credits required (1,2) */
        if (TEMP2 & 0x80) break;                /* BMI _45: by the game   */
        if (a == TEMP8) break;                  /* exactly enough         */
        if (a < TEMP8) break;                   /* BCC _45: enough credit */
        a = nxtstep();                          /* next game; BCS _46     */
    }
    /* CheckForStartEnd_45 */
    y = 0x0B;                                   /* one player             */
    a >>= 1;                                    /* LSR: 0 for 1 player    */
    if (a != 0)
        y = 0x0C;                               /* INY: two player        */
c47:
    (void)y;    /* Display4Names overwrites Y (LDY #$03) - the message
                 * pair selected above (or TEMPB via the _15 jump) is dead */
    if (SHHIGH != 0)
        return 0;                               /* _59: showing scores    */
    a = (uint8_t)(ZP_38 & ZP_39);
    if (!(a & 0x80))
        return 0;                               /* no display if initials */
    display_4_names();                          /* game select boxes      */
    return 0;                                   /* CheckForStartEnd_59    */
}

/* ------------------------------------------------------------------ */
/* UsesTemp1Temp11 + the frame-modulo service chain                    */
/* ------------------------------------------------------------------ */

static void frame0_frame_off(void);          /* Frame0FrameOff $6952 */
static void frca30(void);                    /* Frca30 $69E4         */
static void frame07f(void);                  /* Frame07f $6A1F       */
static void frame0f(void);                   /* Frame0f  $6A2E       */
static void frame07(void);                   /* Frame07  $6A46       */
static void done_above(void);                /* DoneAbove $6A89      */

/* UsesTemp1Temp11 ($68FD): bump the master frame counter $44, set the
 * pulse intensity, drive the OUT1 latch (lamps/counters/flip), and run
 * the frame-modulo service chain. A/X clobbered. */
void uses_temp1_temp11(void)
{
    uint8_t a;

    ZP_44++;                                    /* L68FD INC $44          */
    INTEN = (uint8_t)((ZP_44 << 4) | 0x80);     /* 4xASL, min brightness  */
    a = g.ram[0x31];                            /* lockout status from    */
                                                /* the mainline           */
    if (!(sd_hw_in1(7) & 0x80))                 /* LDX CABERE / BMI _4    */
        a |= 0xC0;                              /* flip for cocktail norm */
    /* UsesTemp1Temp11_4 */
    if (!(LANGBT & 0x80)) {                     /* coin routine on?       */
        if (g.ram[0x29] & 0x80)                 /* 1st EM counter timer   */
            a |= 0x01;                          /* turn it on             */
        /* UsesTemp1Temp11_1 */
        if (ROTENG & 0x80)                      /* 2nd ($28)              */
            a |= 0x02;                          /* it's on                */
    }
    /* UsesTemp1Temp11_3 */
    if (ZP_35 & 0x80) {                         /* game going: wait a     */
        if (ZP_45 != 0 && SCORE == 0)           /* short time, then stop  */
            LANGBT = 0x80;                      /* the coin routine       */
    }
    /* UsesTemp1Temp11_5 */
    sd_hw_out1(a);                              /* L6933 STA OUT1         */
    a = ZP_44;
    if (a == 0)          { frame0_frame_off(); return; } /* do ALL        */
    if ((a & 0x7F) == 0) { frame07f(); return; }
    if ((a & 0x0F) == 0) { frame0f(); return; }
    if ((a & 0x07) == 0) { frame07(); return; }
    done_above();                               /* none this time         */
}

/* Frame0FrameOff ($6952): every-256-frames service (attract staging,
 * killer mine + comet difficulty ramps). Falls through to Frca30. */
static void frame0_frame_off(void)
{
    uint8_t a, x;

    if (ZP_35 & 0x80) goto step;                /* game: always up $45    */
    a = (uint8_t)(ZP_38 & ZP_39);
    if (!(a & 0x80)) goto step;                 /* initials entry: up too */
    a = (uint8_t)(ZP_45 & 0x04);
    if (a == 0) {
        a = (uint8_t)(ZP_45 & 0x03);
        if (a == 0x03) goto hold;               /* hold till wave over    */
    }
    /* Frame0FrameOff_2: any button holds the attract stage */
    a = (uint8_t)((sd_hw_in1(4) | sd_hw_in1(5)) & 0x80); /* STRT1|OPTNA1  */
    for (x = 3;; x--) {                         /* Frame0FrameOff_5       */
        a |= sd_hw_in1(x);                      /* ORA HYPSW,X            */
        if (x == 0) break;
    }
    if (a & 0xC0) goto hold;                    /* pushed: skip update    */
step:
    ZP_45++;                                    /* _6: step attract stage */
hold:
    /* Frame0FrameOff_12: run down both players' MXRTIMERs */
    for (x = 1;; x--) {
        if (g.ram[A_MXRTIMER + x] != 0)
            g.ram[A_MXRTIMER + x]--;
        if (x == 0) break;
    }
    /* Frame0FrameOff_30 */
    if ((ZP_45 & 0x03) == 0) {
        for (x = 5;; x--) {                     /* six killer-mine slots  */
            a = g.ram[0xC9 + x];                /* mine color             */
            if (a != 0x01)
                g.ram[0xC9 + x] = (uint8_t)(a - 1);  /* drop color        */
            /* Frame0FrameOff_36 */
            a = g.ram[A_KSPEED + x];
            if (a != 0) {                       /* active                 */
                if (a < mainline_evkm[x])       /* top speed check; the   */
                    g.ram[A_KSPEED + x] =       /* X=5 read is one byte   */
                        (uint8_t)(a + 2);       /* past the ROM table     */
                /* Frame0FrameOff_40 */
                a = g.ram[A_KANGCH + x];
                if (a < mainline_kchend[x])     /* X=5 reads code $6AA5   */
                    g.ram[A_KANGCH + x] = (uint8_t)(a + 1);
            }
            if (x == 0) break;                  /* Frame0FrameOff_45      */
        }
        since_cannot_get_must();                /* comet difficulty ramp  */
    }
    /* Frame0FrameOff_80: speed up mature comets */
    for (x = 7;; x--) {
        if (g.ram[0xA8 + x] != 0 &&             /* comet slot active      */
            (g.ram[A_COMTYP + x] & 0x80)) {     /* BPL _85: nascent       */
            a = g.ram[A_CSPEED + x];
            if (a < 0x10)
                g.ram[A_CSPEED + x]++;
            /* Frame0FrameOff_84 */
            a = g.ram[A_CANGCH + x];
            if (a < 0x70) {
                g.ram[A_CANGCH + x]++;
                g.ram[A_CANGCH + x]++;
            }
        }
        if (x == 0) break;                      /* Frame0FrameOff_85      */
    }
    frca30();                                   /* fall through           */
}

/* Frca30 ($69E4): killer-mine seeding + comet start-slot bases. */
static void frca30(void)
{
    uint8_t a;

    if (ZP_34 == 0 && (ZP_45 & 0x0F) == 0)
        initiate_killer_mine();
    /* Frca30_20 */
    if (LASTSW & 0x80) {
        a = ZP_45;
        if (!(a & 0x01)) {                      /* LSR / BCS Frca30_30    */
            a = (uint8_t)(BCOMSTART + 0x11);    /* ADC: C=0 from the LSR  */
            COMSTART = a;
            a = (uint8_t)(g.ram[0x3B5] + 0x15); /* BCOMSTART+1, CLC/ADC   */
            g.ram[0x398] = a;                   /* COMSTART+1             */
            if (!(a & 0x80)) {                  /* BPL Frame07f "ALWAYS"  */
                frame07f();
                return;
            }
        }
        /* Frca30_30 */
        a = (uint8_t)(g.ram[0x3B5] + 0x11);     /* CLC/ADC #$11           */
        COMSTART = a;
        a = (uint8_t)(BCOMSTART + 0x15);        /* CLC/ADC #$15           */
        g.ram[0x398] = a;
    }
    frame07f();                                 /* fall through           */
}

/* Frame07f ($6A1F): every-128-frames - run the saucer entry delays down
 * to their floor of 8. */
static void frame07f(void)
{
    uint8_t x;
    for (x = 1;; x--) {                         /* Frame07f_7             */
        if (g.ram[A_SENMDEL + x] >= 0x09)       /* CMP #$09 / BCC _8      */
            g.ram[A_SENMDEL + x]--;
        if (x == 0) break;
    }
    frame0f();                                  /* fall through           */
}

/* Frame0f ($6A2E): every-16-frames - bookkeeping display + onslaught
 * timer. */
static void frame0f(void)
{
    display_parameters();
    if (COMTIMER != 0) {
        COMTIMER--;
        if (COMTIMER == 0) {                    /* BNE Frame07            */
            NENTCOMETS = 0;
            NENTDWARF = 0;
            get_comet_to_go();
        }
    }
    frame07();                                  /* fall through           */
}

/* Frame07 ($6A46): every-8-frames - special explosion, saucers, rock
 * timers, long-game timer. */
static void frame07(void)
{
    uint8_t a, x;

    if (SPECEX & 0x80)                          /* want special explosion */
        bells_wistles();
    /* Frame07_9 */
    l2_saucers();                               /* keep saucers moving    */
    a = NROCKS;
    if (a == 0) { done_above(); return; }       /* no rocks               */
    for (x = 1;; x--) {                         /* Frame07_10/20/25       */
        if (g.ram[A_RTIMER + x] != 0)
            g.ram[A_RTIMER + x]--;
        if (g.ram[A_ETIMER + x] != 0)
            g.ram[A_ETIMER + x]--;
        if (g.ram[A_ENMDEL + x] != 0)
            g.ram[A_ENMDEL + x]--;
        if (x == 0) break;                      /* Frame07_30             */
    }
    a = (uint8_t)(SCSHSP & g.ram[0x39E]);       /* both shooting fast?    */
    if (a & 0x80) { done_above(); return; }
    a = LNGTIMER;
    LNGTIMER = (uint8_t)(a - 1);                /* SEC/SBC #$01           */
    if (a == 0)                                 /* BCS DoneAbove: borrow  */
        g.ram[0x3BA]--;                         /* 16-bit high byte       */
    done_above();                               /* fall through           */
}

/* DoneAbove ($6A89): re-arm both collision latches - set bit 7, keeping
 * bit 6 as "collided last time" via the ASL/ROR pair. */
static void done_above(void)
{
    uint8_t x, v;
    for (x = 1;; x--) {                         /* DoneAbove_22           */
        v = g.ram[A_COLLIS + x];
        if (!(v & 0x80)) {                      /* BMI _23: none last time */
            v <<= 1;                            /* ASL COLLIS,X           */
            g.ram[A_COLLIS + x] = v;
        }
        /* DoneAbove_23 */
        g.ram[A_COLLIS + x] = (uint8_t)(0x80 | (v >> 1)); /* SEC/ROR      */
        if (x == 0) break;
    }
}

/* ------------------------------------------------------------------ */
/* Onslaught / QuickEndEndOnslaught / CometCalculations                */
/* ------------------------------------------------------------------ */

/* Onslaught ($6AD1): between waves, feed queued onslaught comets into
 * play every 16th frame. Tail-calls Inco10 with the scan limit in X,
 * the owning player in Y/WHITE and the target object in EACE. */
void onslaught(void)
{
    uint8_t a, x, y;

    a = (uint8_t)(NROCKS | SCORE);              /* rocks left / ending?   */
    if (a != 0) return;                         /* Onslaught_90           */
    a = ZP_34;
    if (a >= 0x02) {                            /* CMP #$02 / BCC _10     */
        if (COMOFF & 0x80) return;              /* comets switched off    */
    }
    /* Onslaught_10 */
    a = (uint8_t)(NENTCOMETS | NENTDWARF);
    if (a == 0) return;                         /* Onslaught_11: none left */
    /* Onslaught_12 */
    if (a & 0x80) return;
    if (COMTIMER == 0) return;                  /* out of time            */
    if ((ZP_44 & 0x0F) != 0) return;
    y = 0x00;                                   /* whose comets to use    */
    EACE = 0x21;                                /* the target             */
    x = 0x14;
    if (ZP_34 == 0x01) {                        /* CMP #$01 / BNE _50     */
        x = 0x18;                               /* BNE _95 (always)       */
    } else {
        /* Onslaught_50 */
        if ((ZP_44 & 0x20) == 0) {
            y = 0x01;                           /* INY                    */
            EACE++;                             /* other ship as target   */
            x = 0x18;
        }
    }
    /* Onslaught_95 */
    WHITE = y;                                  /* for Ehasentered        */
    inco10(x, y);                               /* JMP Inco10 (always)    */
}

/* QuickEndEndOnslaught ($6B1C): once both ships are gone in a game,
 * clear every comet and saucer for the quick restart. */
void quick_end_end_onslaught(void)
{
    uint8_t a, x;

    if (ZP_35 == 0) return;                     /* not during attract     */
    a = (uint8_t)(g.ram[0xB8] & OBKLMINES);     /* both exploding?        */
    if (a & 0x80)                               /* BPL _1 skips           */
        stop_fuse_sound();
    /* QuickEndEndOnslaught_1 */
    a = (uint8_t)(g.ram[0xB8] | OBKLMINES);     /* see if both dead       */
    if (a != 0) return;
    /* QuickEndEndOnslaught_5 (A = 0 here) */
    for (x = 7;; x--) {                         /* remove comets          */
        g.ram[0xA8 + x] = 0;
        if (x == 0) break;
    }
    g.ram[0xB6] = 0;                            /* remove saucers         */
    g.ram[0xB7] = 0;
    NENTCOMETS = 0;
    NENTDWARF = 0;
    SUPRSAC = 0;                                /* reset supersaucer      */
    /* QuickEndEndOnslaught_20 RTS */
}

/* SinceCannotGetMust ($6AA5): the per-wave comet difficulty ramp - step
 * both players' comet turn rate ceiling (NWCACH), top speed (NWCSPD) and
 * first-comet start speed (FCSPD) by the KLMINC-indexed amounts.
 * ROM QUIRK, kept: the `ADC NewCometAngleChange,Y` at $6AB0 never stores
 * its sum back to NWCACH,X - the next LDA overwrites A - so only its
 * CARRY OUT survives, feeding the NWCSPD add at $6AB6 (and the BCS at
 * $6AAE reaches that ADC with C = 1).  NWCACH itself is only ever ramped
 * by SbttlStcomet's own +KANGCH path; this routine's name is a lie. */
void since_cannot_get_must(void)
{
    uint8_t a, x, y;
    unsigned s, c;

    y = KLMINC;                                 /* L6AA7: the diff setting */
    for (x = 1;; x--) {                         /* L6AA5 LDX #$01 / L_10   */
        a = g.ram[A_NWCACH + x];                /* L6AA9                   */
        c = (a >= 0x40);                        /* L6AAC CMP #$40          */
        if (!c) {                               /* L6AAE BCS L_30          */
            s = (unsigned)a + mainline_comet_ramp[y];   /* L6AB0 ADC       */
            c = s >> 8;                         /* the sum is dropped (see */
        }                                       /* the quirk note above)   */
        /* L_30: ADC with the carry from the CMP or the dropped ADC */
        s = (unsigned)g.ram[A_NWCSPD + x]
          + mainline_comet_ramp[4 + y] + c;     /* L6AB3/B6                */
        a = (uint8_t)s;
        if (!(a & 0x80))                        /* L6AB9 BMI L_40          */
            g.ram[A_NWCSPD + x] = a;
        /* L_40 */
        a = g.ram[A_FCSPD + x];                 /* L6ABE                   */
        if (a < 0x40) {                         /* L6AC1/C3 CMP/BCS L_60   */
            a = (uint8_t)(a + mainline_comet_ramp[8 + y]);  /* C=0 here    */
            g.ram[A_FCSPD + x] = a;             /* L6AC8                   */
        }
        if (x == 0) break;                      /* L_60 DEX / BPL L_10     */
    }
}

/* InitializeComet ($6B68): spawn a comet/dwarf for player WHITE, aimed at
 * the target object in EACE.  Falls into Inco10 with X = COMSTART,Y (the
 * highest slot to scan).  out = the exit 6502 X (see inco10). */
uint8_t initialize_comet(void)
{
    uint8_t y = WHITE;                          /* L6B68: who gets it 0:1  */
    return inco10(g.ram[A_COMSTART + y], y);    /* L6B6A LDX COMSTART,Y    */
}

/* Inco10 ($6B6D) / UsesTemp2Temp21 ($6B70): the comet spawner's body.
 *   in   x = highest object slot to scan (clamped to $18), y = player;
 *        EACE ($08) = the target object ($21/$22), staged by the caller.
 *   out  the exit 6502 X: the scan position on the no-slot/full early
 *        exits, else ResetTimers' exit X (= WHITE).  MotionUpdateRoutine
 *        consumes it after the $4A9C tail call.
 *   RAM  TEMP5 ($1C) holds the scan limit, then is CLOBBERED by the
 *        $6BF8 STA on the vary-Y placement path (ROM behavior, kept);
 *        POKRAN ($0A) = the first placement axis' distance.
 * Placement loop: a POKEY1 RANDOM byte picks which axis rides a screen
 * edge; too-close tries again with the byte skewed +$21 (axis-1 fail,
 * $6C0C) or +$81 (total-distance fail, $6C18) - no further RANDOM reads,
 * so the LFSR sees exactly one read per spawn (+ one more only on the
 * no-entitlement dwarf check at $6C4D). */
uint8_t inco10(uint8_t x, uint8_t y)
{
    uint8_t a, rnd, r2;
    unsigned c;

    a = mainline_comentable[y];                 /* L6B6D LDA Comentable,Y  */
    /* UsesTemp2Temp21 ($6B70) */
    if (!(ZP_35 & 0x80))                        /* BIT $35 / BPL _99       */
        return x;                               /* not during a game       */
    if (x >= 0x19)                              /* L6B74 CPX #$19          */
        x = 0x18;                               /* too many: set to max    */
    TEMP5 = a;                                  /* _4 (L6B7A)              */
    for (;;) {                                  /* _5                      */
        if (x < TEMP5)                          /* L6B7C CPX / BCC _99     */
            return x;                           /* no free slot            */
        a = g.ram[0x97 + x];                    /* L6B80                   */
        if (a == 0)                             /* BEQ _10: a free slot    */
            break;
        x--;                                    /* _7: DEX (active or      */
    }                                           /* exploding: skip it)     */
    /* _10 */
    if (COMTIMER == 0) {                        /* L6B8B BNE _12: onslaught */
        if (NCOMET >= COMLIMIT)                 /* L6B90/93 CMP / BCS _99  */
            return x;                           /* full already            */
    }
    /* _12 */
    NCOMET++;                                   /* L6B98                   */
    a = EACE;                                   /* L6B9B                   */
    g.ram[A_GTIME + x] = a;                     /* L6B9D STA GTIME,X       */
    y = a;                                      /* L6BA0 TAY: the target   */
    rnd = sd_hw_pokey_random(0);                /* L6BA1 LDA $100A         */

    for (;;) {                                  /* _15 (rnd rides the stack) */
        g.ram[A_OBJXL + x] = 0;                 /* L6BA5-6BAA              */
        g.ram[A_OBJYL + x] = 0;
        a = rnd;                                /* L6BAD/AE PLA / PHA      */
        c = a & 1; a >>= 1;                     /* L6BAF LSR               */
        if (!c) {
            /* vary X along a horizontal edge */
            c = a & 1; a >>= 1;                 /* L6BB2 LSR               */
            r2 = a;                             /* PHA: random 0-$3F       */
            a = 0x00;                           /* L6BB4: the bottom       */
            if (!c) {                           /* L6BB6 BCS _20           */
                a = 0x17;                       /* the top                 */
                g.ram[A_OBJYL + x]--;           /* L6BBA DEC -> $FF        */
            }
            /* _20 */
            g.ram[A_OBJYH + x] = a;             /* L6BBD                   */
            a = (uint8_t)(a - g.ram[A_OBJYH + y]); /* L6BC0/C1 SEC/SBC     */
            a = entry_input_exit_absolute(a);   /* L6BC4                   */
            POKRAN = a;                         /* the difference in Y     */
            c = (a >= 0x02);                    /* L6BC9 CMP #$02: minimum */
            a = r2;                             /* L6BCB PLA               */
            if (!c) {                           /* BCC _83: too close      */
                rnd = (uint8_t)(rnd + 0x21);    /* _83: vary it slightly   */
                continue;                       /* JMP _15                 */
            }
            a >>= 1;                            /* L6BCE LSR: 0-$1F        */
            g.ram[A_OBJXH + x] = a;             /* L6BCF                   */
            a = (uint8_t)(a - g.ram[A_OBJXH + y]); /* L6BD2/D3 SEC/SBC     */
            /* JMP _80 */
        } else {
            /* _50: vary Y along a vertical edge */
            c = a & 1; a >>= 1;                 /* L6BD9 LSR               */
            r2 = a;                             /* L6BDA PHA               */
            a = 0x00;                           /* L6BDB: the left         */
            if (!c) {                           /* L6BDD BCS _60           */
                a = 0x1F;                       /* the right               */
                g.ram[A_OBJXL + x]--;           /* L6BE1 DEC -> $FF        */
            }
            /* _60 */
            g.ram[A_OBJXH + x] = a;             /* L6BE4                   */
            a = (uint8_t)(a - g.ram[A_OBJXH + y]); /* L6BE7/E8 SEC/SBC     */
            a = entry_input_exit_absolute(a);   /* L6BEB                   */
            POKRAN = a;                         /* the difference in X     */
            a = r2;                             /* L6BF0 PLA               */
            a >>= 1;                            /* L6BF1 LSR: 0-$1F        */
            if (a >= 0x18) {                    /* L6BF2 CMP #$18          */
                a = (uint8_t)(a - 0x18);        /* L6BF6 SBC (C=1): 0-7    */
                TEMP5 = a;                      /* L6BF8: CLOBBERS the     */
                                                /* scan limit (ROM quirk)  */
                a = (uint8_t)((a << 1) + TEMP5);/* L6BFA/FB ASL / ADC: *3  */
            }
            /* _70 */
            g.ram[A_OBJYH + x] = a;             /* L6BFD                   */
            a = (uint8_t)(a - g.ram[A_OBJYH + y]); /* L6C00/01 SEC/SBC     */
        }
        /* _80 */
        a = entry_input_exit_absolute(a);       /* L6C04                   */
        c = (a >= 0x02);                        /* L6C07 CMP #$02          */
        if (!c) {                               /* BCS _85                 */
            rnd = (uint8_t)(rnd + 0x21);        /* _83 (L6C0B/0C): C=0     */
            continue;                           /* JMP _15                 */
        }
        /* _85 */
        a = (uint8_t)(a + POKRAN + 1);          /* L6C11 ADC (C=1 in)      */
        c = (a >= 0x04);                        /* L6C13 CMP #$04: minimum */
        if (c)                                  /* L6C15/16 PLA / BCS      */
            break;                              /* Inco30: far enough      */
        rnd = (uint8_t)(rnd + 0x81);            /* L6C18 ADC #$81 (C=0):   */
        /* JMP _15: vary it to the other side  */
    }

    /* Inco30 ($6C1D) */
    y = g.ram[A_GTIME + x];                     /* LDY GTIME,X: the target */
    g.ram[0x0274 + x] = g.ram[A_COLLIS + y];    /* L6C20/23                */
    g.ram[0x97 + x] = g.ram[A_STRADDLE + y];    /* L6C26/29: the picture   */
    g.ram[0x0266 + x] = 0x00;                   /* L6C2B/2D: dwarf         */
    g.ram[A_XINC + x] = 0x00;                   /* L6C30                   */
    g.ram[A_YINC + x] = 0x00;                   /* L6C33                   */
    g.ram[0x037E + x] = 0x00;                   /* L6C36                   */
    if (NENTCOMETS != 0) {                      /* L6C39 BEQ _30           */
        NENTCOMETS--;                           /* L6C3E (BPL _50 always)  */
        sbttl_stcomet(x);                       /* _50 (L6C55): comet sound */
    } else if (NENTDWARF != 0) {                /* _30 (L6C43) BEQ _40     */
        NENTDWARF--;                            /* L6C48 (BPL _70 always)  */
    } else if (sd_hw_pokey_random(0) < g.ram[0x0378 + y])   /* _40 (L6C4D) */
        sbttl_stcomet(x);                       /* CMP/BCS _70: else _50   */
    /* _70 (L6C58) */
    XCOMP = x;                                  /* STX XCOMP               */
    a = find_difference_coordinates(x, y);      /* the first angle         */
    x = XCOMP;                                  /* L6C5D LDX XCOMP         */
    g.ram[0x0282 + x] = a;                      /* L6C5F                   */
    return reset_timers();                      /* L6C62 JMP (EXIT)        */
}

/* L6C79 (anonymous entry, coverage list): step comet slot a+$11 - hand
 * an active, non-exploding comet to the angle tracker. a = frame-derived
 * index 0-7. */
void sub_6c79(uint8_t a)
{
    uint8_t x, y, v;

    x = (uint8_t)(a + 0x11);                    /* CLC / ADC #$11 / TAX   */
    XCOMP = x;                                  /* $0C                    */
    y = g.ram[A_GTIME + x];                     /* LDY GTIME,X: target    */
    v = g.ram[0x97 + x];                        /* object status          */
    if (v & 0x80) return;                       /* BMI Docoex: exploding  */
    if (v == 0) return;                         /* BEQ Docoex: inactive   */
    v = g.ram[0x37E + x];
    if (!(v & 0x80)) {                          /* BMI CometCalculations_20 */
        acc_holds_angle_object(x, y);           /* JMP AccHoldsAngleObject */
        return;
    }
    /* CometCalculations_20 */
    klmi7(get_wrap_around_angle(x, y));         /* JSR + JMP Klmi7        */
}

/* CometCalculations ($6C65): pick which comet slot this frame serves.
 * During an onslaught (COMTIMER bit 7) every frame serves slot $44&7;
 * otherwise only every 4th frame serves slot ($44&$1F)>>2. */
void comet_calculations(void)
{
    uint8_t a = ZP_44;

    if (COMTIMER & 0x80) {                      /* BIT / BPL L6C71        */
        sub_6c79((uint8_t)(a & 0x07));          /* AND #$07 / JMP L6C79   */
        return;
    }
    a &= 0x1F;                                  /* assume 8 comets        */
    if (a & 0x01) return;                       /* LSR / BCS Docoex       */
    a >>= 1;
    if (a & 0x01) return;                       /* LSR / BCS Docoex       */
    a >>= 1;
    sub_6c79(a);                                /* fall into L6C79        */
}

/* LswVectorAddress ($6C96): write the running display-list header - a
 * JMPL to the lower buffer ($2002) and a HALT in both buffers. Replaces
 * Poweron's dead $E4 seed before the first VGGO. */
void lsw_vector_address(void)
{
    g.vram[0x000] = 0x01;                       /* LSW of vector address  */
    g.vram[0x001] = 0xE0;                       /* JMPL word $001 = $2002 */
    g.vram[0x003] = 0x20;                       /* HALT                   */
    g.vram[0x403] = 0x20;                       /* HALT, upper buffer     */
}

/* ------------------------------------------------------------------ */
/* boot                                                                */
/* ------------------------------------------------------------------ */

/* SetUpInitialsHigh ($80D4): fill the high-score table with the default
 * "ATARI/CDS/DLS/OWN" initials (Ininitls codes) and 500-point scores.
 * The nested Y/X loop is reproduced exactly: 4 outer passes write
 * initials at $0119-$0154 and the 00/05/00 score pattern at $00DD-$0118;
 * the tail copies Ininitls to $0155-$0163. */
void set_up_initials_high(void)
{
    uint8_t x, y = 0x3C;
    do {                                        /* L80D6                  */
        x = 0x0E;
        do {                                    /* L80D8                  */
            g.ram[0x118u + y] = mainline_ininitls[x];   /* STA $0118,Y    */
            g.ram[0x0DCu + y] = 0x00;                   /* STA SAUMIN,Y   */
            y--; x--;
            g.ram[0x0DCu + y] = 0x05;
            g.ram[0x118u + y] = mainline_ininitls[x];
            y--; x--;
            g.ram[0x118u + y] = mainline_ininitls[x];
            g.ram[0x0DCu + y] = 0x00;
            y--; x--;
        } while (!(x & 0x80));                  /* L80FF BPL              */
    } while (y != 0);                           /* L8101 TYA / BNE        */
    for (x = 0x0E;; x--) {                      /* L8104                  */
        g.ram[0x155u + x] = mainline_ininitls[x];
        if (x == 0) break;                      /* DEX / BPL              */
    }
}

/* Pwron ($68CA): warm-start entry (also JMPed to by self-test exit,
 * $8C2F). Ends by falling through StartUpNewAsteroids into Start2, i.e.
 * where sd_mainline_frame() takes over. */
void pwron(void)
{
    uint8_t x;

    /* L68CC LDX #$FE / TXS stack reset and L68CF CLD: CPU artifacts     */
    lsw_vector_address();
    inset2();
    for (x = 2;; x--) {                         /* Pwron_30               */
        g.ram[A_PL0SCFLAG + x] = 0xBF;          /* $3E1-$3E3 score flags  */
        if (x == 0) break;
    }
    inisou();
    LASTG = 0x01;                               /* in case caberet        */
    ZP_38 = 0xFF;
    ZP_39 = 0xFF;                               /* no new high score      */
    SPFLG = 0xFF;
    STRTLOK = 0x80;                             /* no starts allowed      */
    /* L68F6 CLI: IRQs live - the harness services them at the seam waits */
    display_parameters();                       /* scores up at first     */
    newast_start_new_asteroids();               /* JMP StartUpNewAsteroids;
                                                 * next stop is Start2    */
}

/* StartThingsRunning ($80AB): let the IRQ run, burn $61 frame-gate ticks
 * (~1.58 s) as the EAROM warm-up, then read the EAROM through the
 * IRQ-driven state machine and copy the buffers down. */
static void start_things_running(void)
{
    uint8_t x, a;

    /* L80AB CLI: interrupts start here (harness runs them at the waits) */
    for (x = 0x60;; x--) {                      /* EAROM warm-up counter  */
        sd_wait_frame_gate();                   /* L80AE LSR $33 / BCC    */
        /* L80B2 STA WTCHDG: watchdog kick dropped                       */
        if (x == 0) break;                      /* DEX / BPL: $61 waits   */
    }
    read_everything();                          /* request the EAROM read */
    while (g.ram[0x188] != 0)                   /* L80BB: still reading?  */
        sd_hw_idle();                           /* busy poll; time passes,
                                                 * the per-16th-IRQ EAROM
                                                 * machine fills the
                                                 * buffer (STA WTCHDG
                                                 * kicks dropped)         */
    a = g.ram[0x187];                           /* data-ok flags          */
    if (!(a & 0x01))                            /* LSR / BCS $80CE        */
        copy_from_buffer_back();                /* move to display area   */
    copy_ontime_from_buffer();                  /* move rest down (PHA/PLA
                                                 * kept A; callee ignores) */
    pwron();                                    /* L80D1 JMP Pwron        */
}

/* Poweron ($803F), game path: full RAM/vram/POKEY clear, output latch +
 * POKEY init, VG buffer seed, default initials - then StartThingsRunning
 * and Pwron. Returns where the Start2 loop would begin. */
void sd_boot(void)
{
    unsigned i;

    /* L803F SEI / L8040 LDX #$FE,TXS / L8048 CLD: CPU artifacts         */
    sd_cpu_loop_reset();                        /* PC: no test loop parked */
    sd_hw_vgreset();                            /* L8045 STA STOPAD       */
    for (i = 0; i < 0x100; i++) {               /* L804A clear loop       */
        g.ram[0x000 + i] = 0;                   /* STA BLACK,X            */
        g.ram[0x100 + i] = 0;                   /* STA $0100,X            */
        g.ram[0x200 + i] = 0;                   /* STA XINC,X             */
        g.ram[0x300 + i] = 0;                   /* STA $0300,X            */
        g.vram[0x000 + i] = 0;                  /* STA VECMEM,X           */
        g.vram[0x100 + i] = 0;
        g.vram[0x200 + i] = 0;
        g.vram[0x300 + i] = 0;                  /* STA PL0SET,X           */
        g.vram[0x400 + i] = 0;
        g.vram[0x500 + i] = 0;
        g.vram[0x600 + i] = 0;
        g.vram[0x700 + i] = 0;                  /* STA SH0XPCOORD,X       */
        sd_hw_pokey_write(0, (uint8_t)i, 0);    /* STA POKEY,X            */
        sd_hw_pokey_write(1, (uint8_t)i, 0);    /* STA POKEY2,X           */
        /* L8073 STA WTCHDG: watchdog kick dropped                       */
    }
    sd_hw_out1(0xC0);                           /* counters off, no flip  */
    sd_hw_pokey_write(0, 0x0F, 0x07);           /* SKCTL: turn on POKEY   */
    sd_hw_pokey_write(1, 0x0F, 0x07);
    if (!(sd_hw_in0() & 0x10)) {                /* L8086: D IF SELF TEST  */
        beginning_pattern();                    /* L808D JMP: the power-on
                                                 * diagnostics; parks the
                                                 * CPU in MainLineDiagLoop */
        return;
    }
    /* L8090: init the VG buffer header */
    g.vram[0x000] = 0x01;
    g.vram[0x001] = 0xE4;                       /* JMPL word $401: dead
                                                 * seed - LswVectorAddress
                                                 * rewrites it before any
                                                 * VGGO (see DESIGN.md)   */
    g.vram[0x003] = 0x20;                       /* HALT, lower buffer     */
    g.vram[0x403] = 0x20;                       /* HALT, upper buffer     */
    UPDOWN = sd_hw_in1(7);                      /* L80A2 LDA CABERE: init
                                                 * cocktail-flip pointer  */
    set_up_initials_high();                     /* move in initials       */
    start_things_running();                     /* ...through Pwron       */
}

/* ------------------------------------------------------------------ */
/* the Start2 mainline loop                                            */
/* ------------------------------------------------------------------ */

/* One pass of the Start2 loop ($4012): from the loop top to the next
 * arrival back at Start2 / StartUpNewAsteroids / InitializePlayer1Start.
 * The re-entry prologues run as tail calls (identical instruction order
 * to the ROM's JMPs); the early 'JMP Start2' after GetPlayersInitials
 * simply ends the pass. One pass = one VGGO = one displayed frame. */
void sd_mainline_frame(void)
{
    uint8_t a, x;

    if (selftest_frame())                       /* CPU parked in a test   */
        return;                                 /* loop: that was its pass */
    gtoptn();                                   /* L4012                  */
    if (!(sd_hw_in0() & 0x10)) {                /* L4015: self test?      */
        all_stop_please();                      /* L401C JMP: the book-
                                                 * keeping screen; runs its
                                                 * first St2 pass         */
        return;
    }
    /* Start2_6 */
    sd_wait_vghalt();                           /* L401F BIT HALT / BVC   */
    do_low_ones_every();                        /* L4024                  */
    /* Start2_8 */
    sd_wait_frame_gate();                       /* L4027 LSR $33 / BCC    */
    /* L402B STA WTCHDG: watchdog kick dropped                           */
    FLASHCOL = (uint8_t)((ZP_44 & 0x0F) | 0xE0);/* flash color pointer,   */
                                                /* full bright            */
    for (x = 1;; x--) {                         /* Start2_9: shield-return */
        a = g.ram[A_ENTER + x];                 /* bonus timers           */
        if (a != 0) {                           /* BEQ _10: no touch      */
            a = (uint8_t)(a + 2);               /* CLC / ADC #$02         */
            g.ram[A_ENTER + x] = a;
            if (a == 0)                         /* BNE _10: not back yet  */
                amount_add_routine_limits(0x40);/* 8 second bonus         */
        }
        if (x == 0) break;                      /* Start2_10              */
    }
    g.vram[0x001] ^= 0x02;                      /* L404E: swap buffers... */
    sd_hw_vggo();                               /* L4056 STA GOADD: go    */
    /* Start2_11: pick the buffer to build in */
    x = 0x20;                                   /* use lower buffer       */
    if (!(g.vram[0x001] & 0x02))
        x = 0x24;                               /* use upper buffer       */
    /* Start2_12 */
    BLUE = 0x02;                                /* reset vector list      */
    EAC2 = x;                                   /* pointer ($x002)        */
    vg_add2(0x94, 0xAA);                        /* JSRL word $A94 = $3528 */
    a = (uint8_t)(ZP_35 | TEMP8 | TEMPB);       /* attract, no credit,    */
    if (a == 0) {                               /* no coins...            */
        a = (uint8_t)(ZP_38 & ZP_39);
        if (a & 0x80) {                         /* ...and no initials     */
            vg_add2(0x64, 0xAF);                /* JSRL word $F64 = $3EC8 */
            a = DIFF;                           /* bonus level (Gtoptn)   */
            if (a != 0) {
                uint8_t bonus = a;              /* PHA                    */
                mesgpos(0xCA, 0xC2);            /* position for message   */
                pass_color(0xE1, 0x0E);
                EACE = bonus;                   /* PLA: save bonus amount */
                WHITE = 0x00;                   /* for display            */
                /* SEC: zero suppression; $07 = page-0 pointer, 2 cells  */
                save_input_parameters(0x07, 0x02, 1);
                (void)display_digit(0x00);      /* add another 0          */
            }
        }
    }
    /* Start2_14 */
    if (check_for_start_end()) {                /* C set: start pushed    */
        /* L40B2 JMP InitializePlayer1Start (tail): the prologues run
         * now, the next pass starts at Start2 - ROM order preserved.    */
        initialization();                       /* L400C                  */
        newast_start_new_asteroids();           /* L400F                  */
        return;
    }
    /* Start2_15 */
    if (ZP_35 == 0) {
        if (get_players_initials())             /* C set: entry done      */
            return;                             /* L40BE JMP Start2       */
        /* Start2_55 */
        a = (uint8_t)(ZP_38 & ZP_39);
        if (!(a & 0x80))                        /* BPL Start2_60          */
            goto s60;
        if (SHHIGH == 0) {                      /* BNE Start2_13          */
            if ((uint8_t)(TEMP8 | TEMPB) != 0)  /* coins or credits?      */
                goto s60;                       /* yes: no table needed   */
        }
        /* Start2_13 */
        if (scores())                           /* C set: doing table     */
            goto s60;
    }
    /* Start2_20 */
    /* Timing sync point only (no ROM instruction) - L40D7.  Fire3 launches
     * a torpedo along ANGLE,X = SANGLE/SANGLE+1, which the IRQ rewrites
     * every tick.  See sd_hw.h; a no-op in the real build.             */
    sd_hw_irq_mark(SD_IRQ_MARK_FIRE);
    if (!(ZP_51 & 0x80))                        /* BIT $51 / BMI: ship 1? */
        fire_ships_torpedos(1);
    /* Start2_30 */
    fire_ships_torpedos(0);
    /* Start2_31 */
    /* Timing sync point only (no ROM instruction) - L40E5.  MoveShip
     * integrates thrust from SANGLE, which the IRQ rewrites every tick;
     * on an overrun pass the machine takes an IRQ between the VGGO and
     * here.  See sd_hw.h; a no-op in the real build.                   */
    sd_hw_irq_mark(SD_IRQ_MARK_SHIPS);
    move_ship(1);                               /* move ships by controls */
    move_ship(0);
    comet_calculations();                       /* L40EF                  */
    onslaught();                                /* L40F2                  */
    quick_end_end_onslaught();                  /* quick restart          */
    /* L40F8/L40FB: two JSRs, but X-coupled - MotionUpdateRoutine's
     * straddle test indexes $0308,X ($517D) / $02D6,X ($5193) with the
     * 6502 X KillerMines left.  The X arriving at $40F8 is whatever
     * MoveShip/CometCalculations/Onslaught/QuickEndEndOnslaught left;
     * those are void here, so the mainline seeds 0 (the ROM's evident
     * intent - the test compares object x against ship $22).  Settled by
     * oracle instrumentation: see NOTES_integration.md. */
    {
        uint8_t kmx = killer_mines(0);
        /* Timing sync point only (no ROM instruction) - L40FB.  Moti20
         * draws every object's picture from cells the IRQ updates
         * (SANGLE), and on hardware one of the pass's IRQs has normally
         * fired by here.  See sd_hw.h; a no-op in the real build.      */
        sd_hw_irq_mark(SD_IRQ_MARK_MOTION);
        motion_update_routine(kmx);
    }
    process_shields();
    collision_detector();                       /* check for collisions   */
s60:
    /* Start2_60 */
    entparams();                                /* score + parameters     */
    force_field_up();                           /* hum?                   */
    center_beam_in_middle();                    /* minimum beam current   */
    vg_add_halt();                              /* HALT ends the list     */
    spark2();                                   /* move the sparks        */
    /* Timing sync point only (no ROM instruction): on hardware 2-3 of this
     * pass's IRQs have already fired by here, and the very next thing
     * UsesTemp1Temp11 does is `INC $44` ($68FD) - the counter the IRQ's
     * ship-rotation reads.  A probe that services all of a pass's IRQs at
     * the frame gate would apply each new $44 value to 2 ticks too many.
     * See sd_hw.h; the real build's implementation is a no-op.          */
    sd_hw_irq_mark(SD_IRQ_MARK_FRAME);
    uses_temp1_temp11();                        /* L4113 frame service    */
    a = RDELAY;
    if (a != 0) {                               /* BEQ Start2_70          */
        RDELAY--;
        if (RDELAY != 0)                        /* BNE Start2_80          */
            return;
    }
    /* Start2_70: free-play + 2-coin-min "force next wave" backdoor */
    a = ZP_35;
    if (a & 0x80) {                             /* BPL L413F skips        */
        if ((ZMINE & 0x03) == 0) {              /* free play?             */
            if (sd_hw_in1(6) & 0x40) {          /* BIT GAMSEL / BVC: and  */
                                                /* 2 coin minimum?        */
                a = sd_hw_in1(6);               /* L412F LDA GAMSEL       */
                {
                    int c = (SAVBOT & 0x01);    /* ROR's carry-out        */
                    SAVBOT = (uint8_t)((SAVBOT >> 1) |          /* ASL/   */
                                       ((a & 0x80) ? 0x80 : 0));/* ROR    */
                    if (c && SAVBOT == 0)       /* BCC / BNE both skip    */
                        NROCKS = 0xF0;          /* force to next wave     */
                }
            }
        }
    }
    /* L413F */
    a = NROCKS;
    if (!(a & 0x80)) {                          /* BMI Start2_75          */
        if (a != 0)                             /* BNE Start2_80          */
            return;
    }
    /* Start2_75 */
    if (!(ZP_35 & 0x80)) {                      /* BIT $35 / BMI _76      */
        a = (uint8_t)(ZP_45 & 0x03);
        if (a != 0x03)                          /* only bump if held at 3 */
            return;
        ZP_45++;                                /* force to next stage    */
    }
    /* Start2_76: L4154 JMP StartUpNewAsteroids (tail) */
    newast_start_new_asteroids();
    /* Start2_80: next pass begins at Start2 */
}
