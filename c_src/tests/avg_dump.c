/* avg_dump.c - Space Duel C port: AVG walker verification dump.
 *
 * Builds a small display list in g.vram the way the game would (JMPL slot
 * at $2000, then CNTR / SCAL / COLOR / glyph JSRLs / VCTR / SVEC / HALT),
 * runs avg_run(), and prints every segment as text. The Python twin
 * (c_src/tools/avg_check.py) prints the identical format over the same
 * bytes - the two outputs must diff clean.
 *
 * With an argument, loads a 2048-byte vector-RAM capture (tests/ref/
 * frame_NNNN.vram, CPU $2000-$27FF) into g.vram instead and walks that -
 * same output format, so real frames diff against the Python twin too.
 *
 * Plain C11, no platform deps beyond stdio. Link: avg.c sd_vecrom.c
 * sd_state.c.
 */
#define _CRT_SECURE_NO_WARNINGS         /* fopen, under MSVC /W4 /WX */
#include <stdio.h>
#include <stdint.h>
#include "sd_state.h"
#include "sd_vecrom.h"
#include "avg.h"

/* The character JSRL table at CPU $324A (ASCVG.MAC order: 0=blank,
 * 1..10='0'..'9', 11..36='A'..'Z'): read the stored words from the
 * generated ROM bytes, exactly as DisplayDigit ($8E55) copies them. */
static uint16_t glyph_jsrl(int entry)
{
    uint32_t off = (0x324Au - SD_VECROM_BASE) + 2u * (uint32_t)entry;
    return (uint16_t)(sd_vecrom[off] | ((uint16_t)sd_vecrom[off + 1] << 8));
}

static void put_word(uint16_t cpu_addr, uint8_t lo, uint8_t hi)
{
    g.vram[cpu_addr - 0x2000u] = lo;
    g.vram[cpu_addr - 0x2000u + 1u] = hi;
}

static void seg_print(float x0, float y0, float x1, float y1,
                      int color, int lum)
{
    printf("SEG %.4f %.4f -> %.4f %.4f c=%d l=%d\n",
           (double)x0, (double)y0, (double)x1, (double)y1, color, lum);
}

static const char *stop_name(avg_stop s)
{
    switch (s) {
    case AVG_STOP_HALT:        return "HALT";
    case AVG_STOP_JUMP0:       return "JUMP0";
    case AVG_STOP_STACK_OVER:  return "STACK_OVER";
    case AVG_STOP_STACK_UNDER: return "STACK_UNDER";
    case AVG_STOP_BADFETCH:    return "BADFETCH";
    case AVG_STOP_RUNAWAY:     return "RUNAWAY";
    default:                   return "?";
    }
}

static void build_list(void)
{
    uint16_t a = glyph_jsrl(11);            /* 'A' */
    uint16_t b = glyph_jsrl(12);            /* 'B' */

    put_word(0x2000, 0x01, 0xE0);           /* JMPL word $001 -> $2002      */
    put_word(0x2002, 0x40, 0x80);           /* CNTR (CenterBeamInMiddle)    */
    put_word(0x2004, 0x00, 0x71);           /* SCAL 1,$00 (~0.498)          */
    put_word(0x2006, 0xE1, 0x64);           /* COLOR: lum $E, color 1       */
    put_word(0x2008, (uint8_t)a, (uint8_t)(a >> 8));
    put_word(0x200A, 0xCE, 0x1F);           /* VCTR dy=-50 (w0=$1FCE)...    */
    put_word(0x200C, 0x64, 0x20);           /* ...dx=+100, z=1 (w1=$2064)   */
    put_word(0x200E, 0xFE, 0x43);           /* SVEC dx=-4, dy=+6, z=7       */
    put_word(0x2010, (uint8_t)b, (uint8_t)(b >> 8));
    put_word(0x2012, 0x00, 0x20);           /* HALT                         */
}

static int load_vram(const char *path)
{
    FILE  *f = fopen(path, "rb");
    size_t n;

    if (f == NULL) {
        fprintf(stderr, "cannot open %s\n", path);
        return 0;
    }
    n = fread(g.vram, 1, sizeof g.vram, f);
    fclose(f);
    if (n != sizeof g.vram) {
        fprintf(stderr, "%s: read %u bytes, want %u\n",
                path, (unsigned)n, (unsigned)sizeof g.vram);
        return 0;
    }
    return 1;
}

int main(int argc, char **argv)
{
    int words = 0;

    if (argc > 1) {
        if (!load_vram(argv[1]))
            return 2;
    } else {
        build_list();
    }

    avg_run(seg_print, &words);

    printf("STOP %s words=%d time=%.4f\n",
           stop_name(avg_last_stop()), words, avg_draw_time_units());
    printf("TIME cycles=%lu ms=%.4f\n",
           (unsigned long)avg_frame_cycles(), avg_frame_time_ms());
    if (avg_last_flags() != 0)
        printf("FLAGS %02X\n", avg_last_flags());
    return avg_last_stop() == AVG_STOP_HALT ? 0 : 1;
}
