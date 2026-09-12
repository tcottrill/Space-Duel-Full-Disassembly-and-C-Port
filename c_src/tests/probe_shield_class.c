/* probe_shield_class.c - which poly-4 interleaving does the shield lock into?
 *
 * The shield's 4956-clock period is 0 mod 3, so channel 0 samples one of
 * three residue classes of the 15-bit poly-4 for as long as the period
 * runs.  Class = (p4 + tcnt0) mod 3 while the $B0 period is running and
 * no reload is in flight; 0 is the one-pulse-in-five pattern.  Runs the
 * real loop headless: A attract frames, coin/select/start, P frames of
 * play, optional shots, then the shield held; prints the class and the
 * machine-time inputs that could decide it.
 *   probe_shield_class <attract_frames> <preshield_frames> [shots] [fps] */
#include "c012294.h"
#define SD_SELFTEST_MAIN
#define main original_selftest_main
#include "../app_loop.c"
#undef main

static int class_now(void)
{
    const ad_pokey *p = &pokey[0];
    return (int)((p->p4 + p->tcnt[0]) % 3);
}

int main(int argc, char **argv)
{
    int attract = argc > 1 ? atoi(argv[1]) : 120;
    int pre     = argc > 2 ? atoi(argv[2]) : 0;
    int shots   = argc > 3 ? atoi(argv[3]) : 0;
    selftest_mode = 1;
    if (argc > 4) sd_app_set_fps_lock(atof(argv[4]));
    if (plat_init()) return 2;
    sd_app_init();
    st_run(attract);
    hl_inputs.coin1 = 1; st_run(12);
    hl_inputs.coin1 = 0; st_run(120);
    hl_inputs.game_select = 1; st_run(6);
    hl_inputs.game_select = 0; st_run(6);
    hl_inputs.start1 = 1; st_run(10);
    hl_inputs.start1 = 0;
    uint64_t cyc_start = pokey[0].cycles;
    unsigned irq_start = g.irq_count;
    st_run(pre);
    for (int s = 0; s < shots; ++s) {
        hl_inputs.fire = 1; st_run(2);
        hl_inputs.fire = 0; st_run(20);
    }
    hl_inputs.shield = 1;
    st_run(120);
    /* settle away from a reload, then read the class twice a frame apart */
    while (pokey[0].timer_reload_delay[0] || pokey[0].tcnt[0] < 8) ad_pokey_advance(&pokey[0], 1), ad_pokey_advance(&pokey[1], 1);
    int c1 = class_now();
    st_run(1);
    while (pokey[0].timer_reload_delay[0] || pokey[0].tcnt[0] < 8) ad_pokey_advance(&pokey[0], 1), ad_pokey_advance(&pokey[1], 1);
    int c2 = class_now();
    printf("attract=%d pre=%d shots=%d  class=%d%s  AUDF1=%02X divisor=%u  "
           "irqs_since_start=%u cycles_since_start=%llu (mod84=%llu) p4=%u tcnt0=%u\n",
           attract, pre, shots, c1, c1 == c2 ? "" : " (UNSTABLE)",
           pokey[0].AUDF[0], pokey[0].divisor[0],
           g.irq_count - irq_start, (unsigned long long)(pokey[0].cycles - cyc_start),
           (unsigned long long)((pokey[0].cycles - cyc_start) % 84), pokey[0].p4, pokey[0].tcnt[0]);
    return 0;
}
