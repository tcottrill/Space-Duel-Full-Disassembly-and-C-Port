/* Reuse the existing audio/table checks with the replacement's actual ABI.
 * RANDOM/timer expectations from the older core are deliberately excluded. */
#include "c012294.h"
#define main old_probe_main
#include "probe_pokey.c"
#undef main
int main(void)
{
    check_periods();
    check_tone();
    check_silence();
    check_skctl_audio_reset();
    printf("c012294 audio checks: %d failure(s)\n", fails);
    return fails ? 1 : 0;
}
