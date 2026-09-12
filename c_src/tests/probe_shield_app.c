/* Include the real loop so this diagnostic can select its synthetic clock. */
#include "c012294.h"
static void trace_pokey_write(ad_pokey *p, uint8_t reg, uint8_t val);
#define ad_pokey_write trace_pokey_write
#define SD_SELFTEST_MAIN
#define main original_selftest_main
#include "../app_loop.c"
#undef main
#undef ad_pokey_write

static FILE *capture;
static FILE *register_log;
static unsigned capture_samples;
static void trace_pokey_write(ad_pokey *p, uint8_t reg, uint8_t val)
{
    if (register_log)
        fprintf(register_log, "%u,%u,%u,%d,%u,%u\n", capture_samples,
                g.frame_count, g.irq_count, p == &pokey[1], reg, val);
    ad_pokey_write(p, reg, val);
}
static void capture_audio(const int16_t *pcm, int n)
{
    if (capture && fwrite(pcm, sizeof *pcm, n, capture) != (size_t)n) exit(2);
    capture_samples += (unsigned)n;
}
int main(int argc, char **argv)
{
    if (argc < 2) return 2;
    selftest_mode = argc > 4 ? 0 : 1;
    if (argc > 2) sd_app_set_fps_lock(atof(argv[2]));
    if (plat_init()) return 2;
    sd_app_init();
    if (!selftest_mode) {
        selftest_mode = 1;
        fast_clock = 1;
        last_ms = -1.0;
        if (ad_pokey_audio_available(&pokey[0]) || ad_pokey_audio_available(&pokey[1])) {
            puts("FAIL: fast boot left stale samples queued");
            return 1;
        }
    }
    if (!pokey[0].cycle_audio || !pokey[1].cycle_audio) {
        puts("FAIL: gameplay is not using the verified cycle-audio renderer");
        return 1;
    }
    st_run(120);
    hl_inputs.coin1 = 1; st_run(12);
    hl_inputs.coin1 = 0; st_run(120);
    hl_inputs.game_select = 1; st_run(6);
    hl_inputs.game_select = 0; st_run(6);
    hl_inputs.start1 = 1; st_run(10);
    hl_inputs.start1 = 0;
    hl_inputs.shield = 1;
    capture = fopen(argv[1], "wb");
    if (!capture) return 2;
    if (argc > 3) {
        register_log = fopen(argv[3], "w");
        if (!register_log) return 2;
        fputs("sample,frame,irq,chip,reg,value\n", register_log);
    }
    hl_audio_hook = capture_audio;
    uint64_t start_cycles = pokey[0].cycles;
    unsigned start_irqs = g.irq_count;
    st_run(360);
    hl_audio_hook = NULL;
    if (fclose(capture)) return 2;
    if (register_log && fclose(register_log)) return 2;
    double expected = (g.irq_count - start_irqs) * mach_tick_ms * SD_AUDIO_RATE / 1000.0;
    int64_t drift = (int64_t)(pokey[0].cycles - start_cycles) -
        (int64_t)(g.irq_count - start_irqs) * SD_IRQ_POKEY_CYCLES;
    printf("audio samples=%u expected=%.2f clock drift=%lld queue=%u overruns=%llu\n",
           capture_samples, expected, (long long)drift,
           ad_pokey_audio_available(&pokey[0]),
           (unsigned long long)ad_pokey_audio_overruns(&pokey[0]));
    if (capture_samples < expected - 2 || capture_samples > expected + 2 ||
        drift <= -(int64_t)SD_IRQ_POKEY_CYCLES || drift >= SD_IRQ_POKEY_CYCLES ||
        ad_pokey_audio_overruns(&pokey[0]) || ad_pokey_audio_overruns(&pokey[1]) ||
        ad_pokey_audio_available(&pokey[0]) > 512 || audio_underrun_frames) {
        printf("FAIL: audio underrun frames=%u\n", audio_underrun_frames);
        return 1;
    }
    printf("game=%02X IRQs=%u frames=%u\n", ZP_35, g.irq_count, g.frame_count);
    return (ZP_35 & 0x80) ? 0 : 1;
}
