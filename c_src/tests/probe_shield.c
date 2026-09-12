#include <stdio.h>
#include <stdint.h>
#include "c012294.h"
#include "sd_state.h"
#include "sound.h"

static ad_pokey chips[2];
void sd_hw_pokey_write(int which, uint8_t reg, uint8_t val)
{ ad_pokey_write(&chips[which], reg, val); }
uint8_t sd_hw_pokey_random(int which)
{ return ad_pokey_read(&chips[which], 10); }
void sd_sample_trigger(uint8_t code) { (void)code; }
void sd_sample_fuse_stop(void) { }
void sd_sample_stop_all(void) { }
void sd_sample_hum(int on, uint8_t freq) { (void)on; (void)freq; }

int main(int argc, char **argv)
{
    FILE *f = argc > 1 ? fopen(argv[1], "wb") : NULL;
    int player = argc > 2 && argv[2][0] == '1';
    if (argc > 1 && !f) return 1;
    uint32_t hash = 2166136261u;
    unsigned samples = 0;
    int nonzero = 0;
    for (int i = 0; i < 2; ++i) ad_pokey_init(&chips[i], 1512000, 44100);
    if (argc > 3 && argv[3][0] == 'c')
        for (int i = 0; i < 2; ++i) ad_pokey_set_cycle_audio(&chips[i], true);
    inisou();
    g.ram[0x35] = 0x80;
    for (int tick = 0; tick < 1500; ++tick) {
        int16_t pcm[180];
        if (!(tick % 4)) {
            if (player) sh1sn(1, 0xF0);
            else sh0sn(0, 0xF0);
        }
        continue_sounds();
        for (int i = 0; i < 2; ++i) ad_pokey_advance(&chips[i], 6144);
        int n = (tick % 5 == 4) ? 180 : 179;
        ad_pokey_render(&chips[0], pcm, n);
        for (int j = 0; j < n; ++j) {
            hash = (hash ^ (uint16_t)pcm[j]) * 16777619u;
            if (pcm[j]) nonzero = 1;
        }
        if (f && fwrite(pcm, sizeof *pcm, n, f) != (size_t)n) return 1;
        samples += n;
    }
    if (f && fclose(f)) return 1;
    printf("shield player=%d samples=%u hash=%08X nonzero=%d\n", player, samples, hash, nonzero);
    return nonzero ? 0 : 1;
}
