/* probe_er2055.c - er2055.c's own checks, independent of the game, plus
 * round trips through earom.c's real state machine.
 *
 *     build_all.bat
 *     tests\probe_er2055.exe
 *
 * Checks (1)-(5) are the Asteroids Deluxe port's probe_er2055.c, verbatim
 * (that tree is the source of truth for er2055.c - README.md): they
 * drive a fresh, local ad_er2055 directly, with expectations derived
 * from MAME 0.286's er2055_device model and the EACTL decode both
 * asteroid.cpp and bwidow.cpp use, not from running this translation.
 * Check (6) is this port's own: it stands a local chip behind the
 * sd_hw_earom_* seam and drives it through A2EARO's state machine
 * (output_earom_erased_written, write_high_scores_initials,
 * read_everything, eazhis) end to end - the only way to see the ER2055
 * model through the ROM's own erase/write/read sequences, including the
 * one thing a simpler latch model gets away with: a write is an AND
 * against the cell, so a rewrite of the table only comes out right
 * because the ROM erases each byte first.
 */
#include <stdio.h>
#include <string.h>

#include "../sd_state.h"
#include "../sd_hw.h"
#include "../earom.h"
#include "../er2055.h"

static int fails;

#define CHECK(cond, ...) do { \
    if (!(cond)) { fails++; printf("  FAIL: "); \
                   printf(__VA_ARGS__); printf("\n"); } } while (0)

/* ------------------------------------------------------------------ */
/* (1) Fresh chip                                                       */
/* ------------------------------------------------------------------ */
static void check_fresh(void)
{
    ad_er2055 e;
    int i, allzero = 1;

    printf("1. Fresh chip: zero-filled (ROMREGION_ERASE00), data() is 0\n");
    ad_er2055_init(&e);
    for (i = 0; i < 64; i++)
        if (e.rom[i] != 0) allzero = 0;
    CHECK(allzero, "fresh chip: every byte should be 0");
    CHECK(ad_er2055_data(&e) == 0, "fresh chip: data() should be 0");
    CHECK(!e.dirty, "fresh chip: not dirty");
}

/* ------------------------------------------------------------------ */
/* (2) Erase sequence for address 5                                      */
/* ------------------------------------------------------------------ */
static void check_erase(void)
{
    ad_er2055 e;
    int i, others_ok;

    printf("2. Erase sequence for address 5 (EAC1+EAC2, then +EACE)\n");
    ad_er2055_init(&e);
    /* Give every byte a known non-$FF value, so "erase changed only
     * address 5" and "not before the chip is selected" are both real
     * assertions rather than accidentally-true zero comparisons. */
    for (i = 0; i < 64; i++)
        e.rom[i] = (uint8_t)(0x10 + i);
    e.dirty = false;

    ad_er2055_control(&e, 0x06);              /* EAC1|EAC2: deselected - mode set up only */
    CHECK(e.rom[5] == 0x15, "erase: address 5 must be unchanged before this call selects the chip");
    ad_er2055_set_addr_data(&e, 5, 0xAB);      /* STORE ADDRESS (data is don't-care for erase) */
    ad_er2055_control(&e, 0x0E);              /* EAC1|EAC2|EACE: selects the chip - erase fires HERE */
    CHECK(e.rom[5] == 0xFF, "erase: address 5 becomes $FF on the selecting call");

    others_ok = 1;
    for (i = 0; i < 64; i++)
        if (i != 5 && e.rom[i] != (uint8_t)(0x10 + i))
            others_ok = 0;
    CHECK(others_ok, "erase: no other address changed");
    CHECK(e.dirty, "erase sets dirty");
}

/* ------------------------------------------------------------------ */
/* (3) Write sequence for address 5, data $5A                            */
/* ------------------------------------------------------------------ */
static void check_write(void)
{
    ad_er2055 e;

    printf("3. Write sequence for address 5 = $5A (EAC1, then +EACE)\n");
    ad_er2055_init(&e);
    /* Erase address 5 first, through the real sequence, so the write
     * test starts from a genuinely erased byte. */
    ad_er2055_control(&e, 0x06);
    ad_er2055_set_addr_data(&e, 5, 0);
    ad_er2055_control(&e, 0x0E);
    CHECK(e.rom[5] == 0xFF, "setup: address 5 erased before the write test");
    e.dirty = false;

    ad_er2055_set_addr_data(&e, 5, 0x5A);
    ad_er2055_control(&e, 0x04);               /* EAC1: not yet selected */
    CHECK(e.rom[5] == 0xFF, "write: unchanged before this call selects the chip");
    ad_er2055_control(&e, 0x0C);               /* EAC1|EACE: selects - write (AND) fires HERE */
    CHECK(e.rom[5] == 0x5A, "write to an erased byte: $FF & $5A == $5A");
    CHECK(e.dirty, "write sets dirty");

    /* The same write on a byte holding $0F: a write without an erase
     * can only clear bits. */
    e.rom[5] = 0x0F;
    e.dirty = false;
    ad_er2055_set_addr_data(&e, 5, 0x5A);
    ad_er2055_control(&e, 0x04);
    ad_er2055_control(&e, 0x0C);
    CHECK(e.rom[5] == 0x0A, "write without erase ANDs: $0F & $5A == $0A");
    CHECK(e.dirty, "write sets dirty (second case)");
}

/* ------------------------------------------------------------------ */
/* (4) Read sequence for address 5                                       */
/* ------------------------------------------------------------------ */
static void check_read(void)
{
    ad_er2055 e;

    printf("4. Read sequence for address 5 (EACE, +EACK, EACE)\n");
    ad_er2055_init(&e);
    e.rom[5] = 0x42;

    ad_er2055_set_addr_data(&e, 5, 0xEE);      /* address latched; data is a
                                                 * poison placeholder - the
                                                 * ROM's own read sequence
                                                 * puts EACE (0x08) on the
                                                 * bus here, equally
                                                 * irrelevant, since a real
                                                 * read only ever gets its
                                                 * byte from the clock's
                                                 * falling edge below */
    ad_er2055_control(&e, 0x08);               /* EACE: select, read armed */
    CHECK(ad_er2055_data(&e) == 0xEE, "read: nothing latched before the clock's falling edge");
    ad_er2055_control(&e, 0x09);               /* EACE|EACK: clock rises */
    CHECK(ad_er2055_data(&e) == 0xEE, "read: a rising edge does not latch");
    ad_er2055_control(&e, 0x08);               /* EACE: clock falls while selected - latch */
    CHECK(ad_er2055_data(&e) == 0x42, "read: the falling edge latches rom[address]");

    /* Not selected at all: nothing latched, even across a real falling
     * clock edge. */
    ad_er2055_set_addr_data(&e, 5, 0x99);
    ad_er2055_control(&e, 0x01);               /* EACK only: chip not selected */
    ad_er2055_control(&e, 0x00);               /* clock falls, still not selected */
    CHECK(ad_er2055_data(&e) == 0x99, "read: no latch while the chip was never selected");
}

/* ------------------------------------------------------------------ */
/* (5) Control 0 on a fresh chip                                         */
/* ------------------------------------------------------------------ */
static void check_control_zero_noop(void)
{
    ad_er2055 e, before;

    printf("5. Control 0 on a fresh chip changes nothing observable\n");
    ad_er2055_init(&e);
    before = e;
    ad_er2055_control(&e, 0);
    /* Not a whole-struct compare: this driver's earom_control_w() passes
     * cs2 = 1 on every call (CS2 is tied high on the board), so the
     * internal composite control latch does pick up that bit even here
     * (0 -> C1|CS2, per MAME's own set_control - it always writes
     * m_control_state before checking whether the chip is selected).
     * With CS1 (EACE) still 0 the chip is not selected, so nothing
     * update_state() could touch - rom[], data() and dirty - moves at
     * all; that is the invariant "changes nothing" means. */
    CHECK(memcmp(e.rom, before.rom, sizeof e.rom) == 0, "control 0 on a fresh chip: rom[] unchanged");
    CHECK(e.data == before.data, "control 0 on a fresh chip: data() unchanged");
    CHECK(e.dirty == before.dirty, "control 0 on a fresh chip: dirty unchanged");
}

/* ------------------------------------------------------------------ */
/* (6) Round trips through the ROM's own state machine (A2EARO)         */
/* ------------------------------------------------------------------ */
/* The seam earom.c drives, over a local chip - the same three calls
 * app_loop.c makes on its chip, minus the NVRAM flush. */
static ad_er2055 host;
static unsigned  ctl_writes;

uint8_t sd_hw_earom_read(void)              { return ad_er2055_data(&host); }
void    sd_hw_earom_write(uint8_t off, uint8_t v)
                                            { ad_er2055_set_addr_data(&host, off, v); }
void    sd_hw_earom_ctl(uint8_t v)          { ctl_writes++; ad_er2055_control(&host, v); }

/* The batch-0 layout (NOTES_earom.md §1): 27 buffer bytes at $0164 go
 * to EAROM $02-$1C, their 8-bit sum to $1D. */
#define BUF0      0x164
#define BUF0_LEN  27
#define ROM0      0x02
#define CKS0      0x1D
#define EA_REQ    (g.ram[0x185])
#define EA_BAD    (g.ram[0x187])
#define EA_OP     (g.ram[0x188])

/* One IRQ's worth of the driver: the every-16th-tick call.  A write
 * batch needs two per byte (erase, then write), a read batch finishes
 * inside the first (the reads chain). */
static void run_until_idle(int limit)
{
    while ((EA_OP != 0 || EA_REQ != 0) && limit-- > 0)
        output_earom_erased_written();
}

static void fill_buffer(uint8_t seed)
{
    int i;
    for (i = 0; i < BUF0_LEN; i++)
        g.ram[BUF0 + i] = (uint8_t)(seed + 3 * i);
}

static int rom_matches_buffer(const uint8_t *buf)
{
    uint8_t sum = 0;
    int i;
    for (i = 0; i < BUF0_LEN; i++) {
        if (host.rom[ROM0 + i] != buf[i]) return 0;
        sum = (uint8_t)(sum + buf[i]);
    }
    return host.rom[CKS0] == sum;
}

static void check_round_trip(void)
{
    uint8_t first[BUF0_LEN], second[BUF0_LEN];
    int i, ok;

    printf("6. Round trips through A2EARO's state machine over the chip\n");
    memset(&g, 0, sizeof g);
    ad_er2055_init(&host);
    ad_er2055_control(&host, 0);

    /* A fresh part reads as two good, all-zero batches - the blank-EAROM
     * boot path NOTES_earom.md §5 proves. */
    read_everything();
    CHECK(EA_OP == 0 && EA_REQ == 0, "boot read of a blank part finishes idle");
    CHECK(EA_BAD == 0, "a blank part passes both checksums (flags $%02X)", EA_BAD);

    /* WriteHighScoresInitials: erase-then-write, two ticks a byte, the
     * checksum last.  The chip must hold the buffer bytes, not $FF, not
     * the erase's zero data - and only inside batch 0's window. */
    fill_buffer(0x11);
    memcpy(first, &g.ram[BUF0], BUF0_LEN);
    ctl_writes = 0;
    write_high_scores_initials();
    run_until_idle(200);
    CHECK(EA_OP == 0 && EA_REQ == 0, "the first write finishes idle");
    CHECK(rom_matches_buffer(first), "after the write the chip holds the 27 bytes and their checksum");
    ok = 1;
    for (i = 0; i < 64; i++)
        if ((i < ROM0 || i > CKS0) && host.rom[i] != 0) ok = 0;
    CHECK(ok, "nothing outside $02-$1D was touched");
    CHECK(host.dirty, "an erase/write leaves the chip dirty (the host's flush cue)");
    printf("   (%u EACTL writes for the 28-byte batch)\n", ctl_writes);

    /* The same batch again with different bits set.  The ER2055 write is
     * an AND, so this only comes out as the new bytes because the ROM
     * erases every cell to $FF first; a model that skipped the erase
     * would leave first & second behind. */
    fill_buffer(0xE4);                        /* bits the first fill cleared */
    memcpy(second, &g.ram[BUF0], BUF0_LEN);
    write_high_scores_initials();
    run_until_idle(200);
    CHECK(EA_OP == 0 && EA_REQ == 0, "the rewrite finishes idle");
    CHECK(rom_matches_buffer(second), "a rewrite replaces the bytes outright (erase before AND-write)");

    /* ReadEverything: the buffer comes back byte for byte, checksum good. */
    memset(&g.ram[BUF0], 0, BUF0_LEN);
    host.dirty = false;
    read_everything();
    CHECK(EA_OP == 0 && EA_REQ == 0, "the read finishes idle");
    CHECK(memcmp(&g.ram[BUF0], second, BUF0_LEN) == 0, "the read restores the buffer byte for byte");
    CHECK(EA_BAD == 0, "a clean read leaves the bad flags at 0 (got $%02X)", EA_BAD);
    CHECK(!host.dirty, "a read never changes a cell (chip stays clean)");

    /* A corrupted cell: the batch's checksum disagrees, the ROM zeroes
     * that batch's buffer and flags it (bit 0 = batch 0); the other
     * batch (bookkeeping, still blank) is unaffected. */
    host.rom[ROM0 + 7] = (uint8_t)(host.rom[ROM0 + 7] ^ 0xFF);
    read_everything();
    CHECK(EA_BAD == 0x01, "a corrupted batch-0 cell sets bad flag bit 0 only (got $%02X)", EA_BAD);
    ok = 1;
    for (i = 0; i < BUF0_LEN; i++)
        if (g.ram[BUF0 + i] != 0) ok = 0;
    CHECK(ok, "the failed batch's buffer is zeroed");

    /* Eazhis: the zeroing write.  Every cell of the batch ends at 0
     * (erased to $FF, then ANDed with 0) with a 0 checksum. */
    EA_BAD = 0;
    eazhis();
    run_until_idle(200);
    ok = 1;
    for (i = ROM0; i <= CKS0; i++)
        if (host.rom[i] != 0) ok = 0;
    CHECK(ok, "Eazhis leaves $02-$1D all zero on the chip");
    read_everything();
    CHECK(EA_BAD == 0, "and the zeroed batch reads back good (flags $%02X)", EA_BAD);
}

int main(void)
{
    check_fresh();
    check_erase();
    check_write();
    check_read();
    check_control_zero_noop();
    check_round_trip();

    printf("%s: %d failure(s)\n", fails ? "PROBE FAILED" : "PROBE OK", fails);
    return fails ? 1 : 0;
}
