/* earom.c - Space Duel C port: the EAROM driver (module A2EARO, $8747-$89B0).
 *
 * A small state machine run from the IRQ every 16th 246 Hz tick
 * (output_earom_erased_written), plus the request entries that feed it and
 * the buffer<->live-cell copy routines around it.
 *
 * Two checksummed batches live in the ER-2055:
 *   bit 0: high scores + initials  EAROM $02-$1C, checksum $1D, buffer $0164
 *   bit 1: bookkeeping             EAROM $1E-$3D, checksum $3E, buffer $0192
 *
 * Operation codes held in $0188: $80 = erase a byte, $40 = write a byte,
 * $20 = read a byte, $00 = idle. Erase/write take one tick each (the ~65 ms
 * between ticks is the part's programming time); reads chain immediately
 * (L886B "DO ALL READS AT ONCE"), so a read batch completes inside a single
 * tick - including the tick triggered by read_everything itself.
 *
 * EACTL ($0E80) control codes issued: $00 deselect, $08 chip select + read,
 * $09 chip select + read + clock, $0C write + chip select, $0E erase + chip
 * select. Every tick starts with a $00 deselect (L87D1), ending the previous
 * erase/write pulse.
 *
 * Hardware artifacts dropped (noted per rule 7):
 *  - SEI/CLI around copy_ontime_from_buffer ($89A3/$89AF): the C port's
 *    IRQ cannot preempt mainline code.
 *  - PHA/PLA register saves in SaveCopy ($8914/$891F/$8921) and the boot
 *    path: stack-page bytes are not modelled (same policy as irq.c).
 */
#include "sd_state.h"
#include "sd_hw.h"
#include "sd_bcd.h"
#include "earom.h"

/* ---- unnamed state cells (g.ram[0xXX]; no Atari names in the defines) ---
 * The named cells EAZFLG $018D (running checksum), EAREQU $018E-$0191 (live
 * ontime BCD counter, bumped by the IRQ) and EABC $0192-$0195 (its slot in
 * the bookkeeping buffer) come from sd_state_defs.h. */
#define EA_ZERO   (g.ram[0x184])  /* $0184: $FF = zero RAM while writing     */
#define EA_REQ    (g.ram[0x185])  /* $0185: pending batch request bits       */
#define EA_WMODE  (g.ram[0x186])  /* $0186: bit set = erase/write, clear = read */
#define EA_BAD    (g.ram[0x187])  /* $0187: bad-checksum flags per batch     */
#define EA_OP     (g.ram[0x188])  /* $0188: current operation ($80/$40/$20/0)*/
#define EA_IDX    (g.ram[0x189])  /* $0189: buffer index of current byte     */
#define EA_ADDR   (g.ram[0x18A])  /* $018A: current EAROM address            */
#define EA_LAST   (g.ram[0x18B])  /* $018B: checksum (= last) EAROM address  */
#define EA_MASK   (g.ram[0x18C])  /* $018C: mask of the batch being serviced */
#define EA_PTR_LO (g.ram[0xC7])   /* $C7:   buffer pointer lo                */
/* buffer pointer hi is $C8 = OBP0MINES (defines reuse the name)             */

/* buffer pointer for the ($C7),Y accesses */
#define EA_PTR    ((uint16_t)(EA_PTR_LO | ((uint16_t)OBP0MINES << 8)))

/* ---- ROM tables (byte-checked against spacduel_64k.bin by
 *      tools/gen_earom_data.py; tiny, so inlined per CONVENTIONS 1c) ------ */

/* $8747: {first EAROM address, checksum EAROM address} per batch */
static const uint8_t tab_8747[4] = { 0x02, 0x1D, 0x1E, 0x3E };

/* EaromOffsetLowestByte ($874B): {buffer lo, buffer hi} per batch
 * (batch 0 -> $0164, batch 1 -> $0192 = EABC) */
static const uint8_t earom_offset_lowest_byte[4] = { 0x64, 0x01, 0x92, 0x01 };

/* Subnum ($8926): substitute score byte when a buffer byte fails BCD
 * validation, indexed by score rank X = 2,1,0 */
static const uint8_t subnum[3] = { 0x00, 0x05, 0x00 };

/* Subl ($893B): substitute initials characters ("LKN" glyph codes) */
static const uint8_t subl[3] = { 0x0C, 0x0B, 0x0E };

/* internal chain tails of the state machine (JMP targets, module-local) */
static void sub_8856(uint8_t a);
static void sub_8858(uint8_t a, uint8_t y);
static void sub_8865(uint8_t y);

/* ------------------------------------------------------------------ */
/* request entries                                                     */
/* ------------------------------------------------------------------ */

/* DoNotZeroEarom ($8765), shared tail of every request entry.
 * In: a = batch bits to request, y = zero flag ($FF zero / $00 keep).
 * $0185 accumulates pending batches; $0186 marks them as erase/write
 * batches (only read_everything ever clears $0186). */
static void do_not_zero_earom(uint8_t a, uint8_t y)
{
    EA_ZERO = y;                          /* L8765 STY $0184             */
    EA_REQ = (uint8_t)(EA_REQ | a);       /* L8769 ORA/STA $0185         */
    EA_WMODE = (uint8_t)(EA_WMODE | a);   /* L8770 ORA/STA $0186         */
}

/* RequestZeroEarom ($8759): a = batch bits; write zeros to those batches
 * (clearing the RAM buffers as it goes). Entered with A preloaded by the
 * three prefixes below - the only call sites ($874F/$8753/$8757). */
void request_zero_earom(uint8_t a)
{
    do_not_zero_earom(a, 0xFF);           /* L8759 LDY #$FF              */
}

/* ZeroEarom ($874F): zero bookkeeping only */
void zero_earom(void) { request_zero_earom(0x02); }

/* Eazhis ($8753): zero high scores / initials only */
void eazhis(void) { request_zero_earom(0x01); }

/* Eazero ($8757): zero all batches */
void eazero(void) { request_zero_earom(0x03); }

/* WriteHighScoresInitials ($875D): write batch 0 from the $0164 buffer
 * (caller runs transfer_high_scores_buffer first - see $4E91). */
void write_high_scores_initials(void)
{
    do_not_zero_earom(0x01, 0x00);        /* L875D LDA #$01, Nozero LDY #$00 */
}

/* RequestBookkeepingUpdate ($8761): write batch 1 from the $0192 buffer
 * (jumped to by UpdateInfoAtEnd $8994 after refreshing the counters). */
void request_bookkeeping_update(void)
{
    do_not_zero_earom(0x02, 0x00);        /* L8761 LDA #$02, Nozero LDY #$00 */
}

/* ReadEverything ($8777): request both batches as reads and run the state
 * machine; because reads chain to completion, both buffers are filled (and
 * checksums judged into $0187) before this returns. Call sites: boot $80B8,
 * self-test $82B9/$82DA. */
void read_everything(void)
{
    EA_REQ = 0x03;                        /* L8777 read in everything    */
    EA_WMODE = 0x00;                      /* L877C all batches are reads */
    output_earom_erased_written();        /* falls through               */
}

/* ------------------------------------------------------------------ */
/* the state machine                                                   */
/* ------------------------------------------------------------------ */

/* OutputEaromErasedWritten ($8781): one tick of the EAROM driver. Called
 * with no arguments from sd_irq every 16th tick (JSR $864A), from
 * read_everything, and recursively from sub_8865 while reading.
 * If idle and requests are pending, selects the highest pending batch bit
 * and initialises the per-batch cells; then always deselects the chip and
 * performs one erase/write step or a full chained read. */
void output_earom_erased_written(void)
{
    uint8_t a, x, y, c;

    a = EA_OP;                            /* L8781 LDA $0188             */
    if (a == 0) {                         /* L8784 BNE L87D1             */
        a = EA_REQ;                       /* L8786 LDA $0185             */
        if (a != 0) {                     /* L8789 BEQ L87D1             */
            /* start a new batch: scan for the highest set request bit.
             * Exits with x = bit number, EA_MASK = its mask. */
            EA_IDX = 0;                   /* L878D zero source index     */
            EAZFLG = 0;                   /* L8790 zero checksum ($018D) */
            EA_MASK = 0;                  /* L8793 zero select bit       */
            x = 0x08;                     /* L8796 LDX #$08              */
            c = 1;                        /* L8798 SEC                   */
            do {
                EA_MASK = (uint8_t)((EA_MASK >> 1) | (c << 7)); /* L8799 ROR */
                c = (uint8_t)(a >> 7);    /* L879C ASL A                 */
                a <<= 1;
                x--;                      /* L879D DEX                   */
            } while (c == 0);             /* L879E BCC L8799             */
            y = 0x80;                     /* L87A0 default to erase/write*/
            if ((EA_MASK & EA_WMODE) == 0)
                y = 0x20;                 /* L87AA read                  */
            EA_OP = y;                    /* L87AC save request          */
            EA_REQ = (uint8_t)(EA_MASK ^ EA_REQ); /* L87AF turn off bit  */
            x = (uint8_t)(x << 1);        /* L87B8 TXA/ASL/TAX           */
            EA_ADDR = tab_8747[x];        /* L87BB first EAROM address   */
            EA_LAST = tab_8747[x + 1];    /* L87C1 checksum address      */
            EA_PTR_LO = earom_offset_lowest_byte[x];     /* L87C7 -> $C7 */
            OBP0MINES = earom_offset_lowest_byte[x + 1]; /* L87CC -> $C8 */
        }
    }
    /* L87D1: deselect the chip (ends any pending erase/write pulse) */
    sd_hw_earom_ctl(0x00);                /* L87D3 STY EACTL, Y=0        */
    a = EA_OP;                            /* L87D6 LDA $0188             */
    if (a == 0)
        return;                           /* L87DB RTS - idle            */
    y = EA_IDX;                           /* L87DC LDY $0189             */
    x = EA_ADDR;                          /* L87DF LDX $018A             */

    /* dispatch: L87E2 ASL / BCC / BPL on the op code */
    c = (uint8_t)(a >> 7);
    a <<= 1;
    if (c) {
        /* op $80: erase cycle for the byte at EAROM address x */
        sd_hw_earom_write(x, a /* $00 */);/* L87E5 STA EADAL,X: address  */
        EA_OP = 0x40;                     /* L87E8 next tick: write      */
        sub_8865(0x0E);                   /* L87ED erase + chip select   */
        return;
    }
    if (a & 0x80) {
        /* op $40: write cycle */
        EA_OP = 0x80;                     /* L87F4 request erase for next byte */
        if (EA_ZERO != 0)                 /* L87F9 zeroing request?      */
            RAM(EA_PTR + y) = 0x00;       /* L8800 clear RAM too         */
        a = RAM(EA_PTR + y);              /* L8802 RAM data (default)    */
        if (x >= EA_LAST) {               /* L8804 CPX $018B, BCC L8811  */
            EA_OP = 0x00;                 /* L880B all done, set done flag */
            a = EAZFLG;                   /* L880E write the checksum    */
        }
        sd_hw_earom_write(x, a);          /* L8811 STA EADAL,X           */
        sub_8858(a, 0x0C);                /* L8814 write mode + chip select */
        return;
    }
    /* op $20: read cycle */
    sd_hw_earom_ctl(0x08);                /* L881B chip select + read    */
    sd_hw_earom_write(x, 0x08);           /* L881E select address (data moot) */
    sd_hw_earom_ctl(0x09);                /* L8823 + clock               */
                                          /* L8826 NOP (settling time)   */
    sd_hw_earom_ctl(0x08);                /* L8829                       */
    c = (uint8_t)(x >= EA_LAST);          /* L882C CPX $018B             */
    a = sd_hw_earom_read();               /* L882F LDA EAIN              */
    if (!c) {
        RAM(EA_PTR + y) = a;              /* L8854 save data in RAM      */
        sub_8856(a);                      /* falls into L8856: next byte */
        return;
    }
    a ^= EAZFLG;                          /* L8834 match checksum?       */
    if (a != 0) {                         /* L8837 BEQ L884C             */
        int i;                            /* no: wipe buffer, flag batch */
        for (i = EA_IDX; i >= 0; i--)     /* L883B LDY $0189             */
            RAM(EA_PTR + (uint16_t)i) = 0x00; /* L883E STA/DEY/BPL       */
        EA_BAD = (uint8_t)(EA_MASK | EA_BAD); /* L8843 set bad flag      */
    }
    EA_OP = 0x00;                         /* L884C/L884E all done        */
    sub_8856(0x00);                       /* L8851 JMP L8856 (A=0)       */
}

/* ------------------------------------------------------------------ */
/* chain tails (anonymous entries; JMP targets inside the machine)     */
/* ------------------------------------------------------------------ */

/* L8856: deselect variant of the bookkeeping tail (Y forced to 0, which
 * makes sub_8865 chain straight into the next state-machine pass - this is
 * how a read batch completes in one tick). In: a = byte for the checksum. */
static void sub_8856(uint8_t a)
{
    sub_8858(a, 0x00);                    /* L8856 LDY #$00              */
}

/* L8858: add a to the running checksum, advance buffer index and EAROM
 * address, then set the control latch. In: a = byte just transferred,
 * y = EACTL code ($00/$0C from call sites). */
static void sub_8858(uint8_t a, uint8_t y)
{
    EAZFLG = (uint8_t)(EAZFLG + a);       /* L8858 CLC/ADC/STA: checksum */
    EA_IDX++;                             /* L885F INC $0189             */
    EA_ADDR++;                            /* L8862 INC $018A             */
    sub_8865(y);
}

/* L8865: write y to EACTL; y == 0 (deselect) re-enters the state machine
 * ("YES. DO ALL READS AT ONCE"), anything else returns to the caller.
 * In: y = EACTL code ($00/$0C/$0E from call sites). */
static void sub_8865(uint8_t y)
{
    sd_hw_earom_ctl(y);                   /* L8865 STY EACTL             */
    if (y == 0)                           /* L8868 TYA / BNE L886E       */
        output_earom_erased_written();    /* L886B JMP (tail recursion)  */
}                                         /* L886E RTS                   */

/* ------------------------------------------------------------------ */
/* buffer <-> live-cell copies                                         */
/* ------------------------------------------------------------------ */

/* TransferHighScoresBuffer ($886F): pack the live top-score bytes and
 * top-slot initials into the batch-0 buffer at $0164 (27 bytes), ready for
 * write_high_scores_initials. Iterates X = 2,1,0 over the 3 bytes of each
 * group; 9 buffer bytes per pass. No arguments. Call site: $4E91.
 * Several loads use forced-absolute zero-page addressing ($BD $DD $00 etc.)
 * - same cells, so no translation difference. */
void transfer_high_scores_buffer(void)
{
    uint8_t y = 0;                        /* L8871 LDY #$00              */
    int x;
    for (x = 2; x >= 0; x--) {            /* L886F LDX #$02 ... DEX/BPL  */
        g.ram[0x164 + y] = g.ram[0xDD + x];  y++; /* 2 player fighters   */
        g.ram[0x164 + y] = g.ram[0xEC + x];  y++; /* 1 player fighter    */
        g.ram[0x164 + y] = g.ram[0xFB + x];  y++; /* 2 player space station */
        g.ram[0x164 + y] = g.ram[0x10A + x]; y++; /* 1 player space station */
        g.ram[0x164 + y] = g.ram[0x119 + x]; y++; /* initials: 2P fighter */
        g.ram[0x164 + y] = g.ram[0x128 + x]; y++; /* 1 player fighter    */
        g.ram[0x164 + y] = g.ram[0x137 + x]; y++; /* 2 player space station */
        g.ram[0x164 + y] = g.ram[0x155 + x]; y++; /* 2 plr station, alt set */
        g.ram[0x164 + y] = g.ram[0x146 + x]; y++; /* 1 player space station */
    }
}

/* SaveCopy ($8911): validate buffer byte $0164+y as a BCD score byte.
 * In: y = buffer index (not advanced - the caller INYs), x = 2,1,0 rank.
 * Out: the byte if both nybbles are BCD and < $9A, else Subnum[x].
 * (The ROM's PHA/PLA around the tests is a register save - dropped.) */
static uint8_t save_copy(uint8_t y, uint8_t x)
{
    uint8_t a = g.ram[0x164 + y];         /* L8911 LDA $0164,Y           */
    if (a < 0x9A &&                       /* L8915 CMP #$9A, BCS bad     */
        (a & 0x0F) < 0x0A)                /* L8919 AND #$0F, CMP #$0A    */
        return a;                         /* L891F restore original data */
    return subnum[x];                     /* L8922 replace with sub number */
}

/* SaveOriginal ($8929): pre-advance the buffer index, then validate the
 * byte as an initials character: $00 (blank) or $0A-$24 (A-Z) pass, else
 * substitute Subl[x]. In: *y = buffer index (incremented), x = rank. */
static uint8_t save_original(uint8_t *y, uint8_t x)
{
    uint8_t a;
    (*y)++;                               /* L8929 INY                   */
    a = g.ram[0x164 + *y];                /* L892A LDA $0164,Y           */
    if (a == 0)                           /* L892D a blank is OK         */
        return a;
    if (a >= 0x0A &&                      /* L892F CMP #$0A, BCC bad     */
        a < 0x25)                         /* L8933 CMP #$25, BCC good    */
        return a;
    return subl[x];                       /* L8937 LDA Subl,X            */
}

/* CopyFromBufferBack ($88B6): unpack the batch-0 buffer into the live
 * high-score cells, sanitising every byte on the way (a bad/blank EAROM
 * yields zeros, which validate). If the top 2-player-fighter score reads
 * all zero afterwards, the EAROM was just cleared: reseed every table's
 * top score with $05 in the middle byte (= 500 points). No arguments.
 * Call sites: boot $80CA (only when $0187 bit 0 clear), self-test.
 * The forced-absolute STA $00DD,X etc. hit the same cells as zero-page. */
void copy_from_buffer_back(void)
{
    uint8_t y = 0, a;                     /* L88B8 LDY #$00              */
    int x;
    for (x = 2; x >= 0; x--) {            /* L88B6 LDX #$02 ... DEX/BPL  */
        g.ram[0xDD + x]  = save_copy(y, (uint8_t)x); y++; /* L88BA scores */
        g.ram[0xEC + x]  = save_copy(y, (uint8_t)x); y++; /* L88C1       */
        g.ram[0xFB + x]  = save_copy(y, (uint8_t)x); y++; /* L88C8       */
        g.ram[0x10A + x] = save_copy(y, (uint8_t)x);      /* L88CF       */
        g.ram[0x119 + x] = save_original(&y, (uint8_t)x); /* L88D5 initials */
        g.ram[0x128 + x] = save_original(&y, (uint8_t)x); /* L88DB       */
        g.ram[0x137 + x] = save_original(&y, (uint8_t)x); /* L88E1       */
        g.ram[0x155 + x] = save_original(&y, (uint8_t)x); /* L88E7       */
        g.ram[0x146 + x] = save_original(&y, (uint8_t)x); /* L88ED       */
        y++;                              /* L88F3 INY                   */
    }
    a = (uint8_t)(g.ram[0xDD] | ROCKMIN | g.ram[0xDF]); /* L88F7 score 0? */
    if (a == 0) {                         /* L8900 must have just cleared */
        ROCKMIN = 0x05;                   /* L8904 STA $00DE: reinit tops */
        g.ram[0xED] = 0x05;               /* L8907                       */
        g.ram[0xFC] = 0x05;               /* L890A                       */
        g.ram[0x10B] = 0x05;              /* L890D                       */
    }
}                                         /* L8910 RTS                   */

/* CopyOntimeFromBuffer ($89A3): move the 4-byte ontime counter from its
 * bookkeeping-buffer slot (EABC, $0192) to the live cells the IRQ ticks
 * (EAREQU, $018E). The ROM brackets this with SEI/CLI so the IRQ cannot
 * update mid-copy - dropped, the C port cannot be preempted here.
 * No arguments. Call sites: boot $80CE, game start/end, self-test. */
void copy_ontime_from_buffer(void)
{
    int x;                                /* L89A3 SEI (dropped)         */
    for (x = 3; x >= 0; x--)              /* L89A4 LDX #$03 ... DEX/BPL  */
        g.ram[A_EAREQU + x] = g.ram[A_EABC + x];
}                                         /* L89AF CLI (dropped)         */

/* ------------------------------------------------------------------ */
/* game-end bookkeeping (UpdateInfoAtEnd $893E)                        */
/* ------------------------------------------------------------------ */

/* AddGameTimeSubroutime ($8997): one decimal byte of the just-finished
 * game's elapsed time folded into the per-game-type running total EACS
 * ($0196+). In: *x = EACS index, *y = GTIME index, cin = incoming carry
 * (0 from UpdateInfoAtEnd's CLC, then threaded call to call). Out: EACS[x]
 * updated; *x/*y advanced by 1; returns outgoing carry. Only caller:
 * UpdateInfoAtEnd (4x unrolled, $8948-$8951 - kept unrolled here too since
 * the ROM never turned it into a loop). */
static int add_game_time_subroutime(uint8_t *x, uint8_t *y, int cin)
{
    bcd_res r = bcd_adc(g.ram[A_EACS + *x], g.ram[A_GTIME + *y], cin);
    g.ram[A_EACS + *x] = r.r;             /* L8997-9D                    */
    (*x)++;                               /* L89A0                       */
    (*y)++;                               /* L89A1                       */
    return r.c;
}

/* UpdateInfoAtEnd ($893E): game-end bookkeeping - folds the just-finished
 * game's elapsed time (GTIME, $03B0) into its game type's running total
 * and into the live ontime counter (which the IRQ stops advancing during
 * play), bumps that game type's games-played counter, stages the ontime
 * counter for an EAROM write, and starts that write. No arguments (reads
 * ZP_34, the game-select switch, 0-3). Call site: mainline.c chkst1()
 * ($4397). Tail-calls (JMP) RequestBookkeepingUpdate. */
void update_info_at_end(void)
{
    uint8_t x, y, i;
    int carry;

    /* SED (L893E): decimal mode for the whole routine, until CLD below. */
    x = (uint8_t)(ZP_34 << 2);            /* L893F-46: game#*4           */
    y = 0;
    carry = 0;                            /* L8947 CLC                   */
    carry = add_game_time_subroutime(&x, &y, carry); /* L8948            */
    carry = add_game_time_subroutime(&x, &y, carry); /* L894B            */
    carry = add_game_time_subroutime(&x, &y, carry); /* L894E            */
    carry = add_game_time_subroutime(&x, &y, carry); /* L8951            */
    (void)carry;                          /* final carry unused           */

    /* L8954-64: EAREQU += GTIME (4 bytes) - this counter was off during
     * the game, so fold the elapsed game time back in. */
    carry = 0;                            /* L8958 CLC                   */
    for (i = 0; i < 4; i++) {
        bcd_res r = bcd_adc(g.ram[A_GTIME + i], g.ram[A_EAREQU + i], carry);
        g.ram[A_EAREQU + i] = r.r;
        carry = r.c;
    }

    /* L8966-6E: X = game# * 3 -> the 3-byte games-played BCD counter at
     * $01A6 (GAMES1 $01AF aliases game-type index 3 of this array). */
    x = (uint8_t)((uint8_t)(ZP_34 << 1) + ZP_34);
    {
        bcd_res r;
        r = bcd_adc(g.ram[0x1A6 + x], 0x01, 0);      /* L896F-75: ADC #$01 */
        g.ram[0x1A6 + x] = r.r;
        r = bcd_adc(g.ram[0x1A7 + x], 0x00, r.c);    /* L8978-7D: ADC #$00 */
        g.ram[0x1A7 + x] = r.r;
        r = bcd_adc(g.ram[0x1A8 + x], 0x00, r.c);    /* L8980-85: ADC #$00 */
        g.ram[0x1A8 + x] = r.r;
    }
    /* CLD (L8988): decimal mode ends here - nothing further to model. */

    /* L8989-92: stage EAREQU into EABC for the EAROM write. */
    for (i = 0; i < 4; i++)
        g.ram[A_EABC + i] = g.ram[A_EAREQU + i];

    request_bookkeeping_update();         /* L8994 JMP (tail call)        */
}
