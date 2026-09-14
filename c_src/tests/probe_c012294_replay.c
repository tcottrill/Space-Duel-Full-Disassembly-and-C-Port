/* probe_c012294_replay.c - replay an AAE adapter trace through the core.
 *
 * The AAE adapter (aae_pokey.cpp) writes, with AAE_POKEY_TRACE=<path> set,
 * a header "I chips clock samplerate buffer_len fps" and then one line per
 * event in order: "A chip clocks" (a catch-up advance), "W chip reg val",
 * "R chip reg val" (the value the emulator saw), "F chip got" (the frame
 * drain).  This replays it on fresh chips exactly as the adapter did, writes
 * each chip's drained audio to <out>_chipN.pcm (mono s16 at the trace's
 * sample rate), pads short frames the way the adapter does, and prints a
 * hash per chip, the RANDOM/register read mismatches against the trace,
 * and per-chip frame statistics.  Build once against the golden core and
 * once against the working copy to compare, or against one core with
 * ad_pokey_set_quiet_skip off ("oneclock" as the third argument).
 *   probe_c012294_replay <trace> <out_prefix> [oneclock]            */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "c012294.h"

int main(int argc, char **argv)
{
    if (argc < 3) { fputs("usage: probe_c012294_replay <trace> <out_prefix> [oneclock]\n", stderr); return 2; }
    FILE *in = fopen(argv[1], "r");
    if (!in) { perror(argv[1]); return 2; }
    int oneclock = argc > 3 && argv[3][0] == 'o';

    char line[128];
    int chips = 0, clock = 0, rate = 0, buflen = 0, fps = 0;
    if (!fgets(line, sizeof line, in) || sscanf(line, "I %d %d %d %d %d", &chips, &clock, &rate, &buflen, &fps) != 5 ||
        chips < 1 || chips > 4 || buflen < 1 || buflen > 4096) {
        fputs("bad trace header\n", stderr); return 2;
    }
    static ad_pokey p[4];
    static int16_t buf[4096];
    static int16_t last[4];
    static uint32_t hash[4];
    static unsigned frames[4], shortframes[4], samples[4], mismatches[4], writes[4], advances[4];
    static uint64_t clocks_total[4];
    FILE *out[4] = { 0 };
    for (int i = 0; i < chips; ++i) {
        ad_pokey_init(&p[i], (uint32_t)clock, (uint32_t)rate);
#ifndef NO_QUIET_SKIP_API   /* the golden one-clock core predates the setter */
        ad_pokey_set_quiet_skip(&p[i], !oneclock);
#endif
        ad_pokey_set_allpot(&p[i], 0xFF);
        hash[i] = 2166136261u;
        char name[512];
        snprintf(name, sizeof name, "%s_chip%d.pcm", argv[2], i);
        out[i] = fopen(name, "wb");
        if (!out[i]) { perror(name); return 2; }
    }
    unsigned long lineno = 1;
    while (fgets(line, sizeof line, in)) {
        ++lineno;
        char op; int c, a, b;
        int n = sscanf(line, "%c %d %d %d", &op, &c, &a, &b);
        if (n < 3 || c < 0 || c >= chips) { fprintf(stderr, "line %lu: bad event\n", lineno); continue; }
        switch (op) {
        case 'A':
            ad_pokey_advance(&p[c], (uint32_t)a); clocks_total[c] += (uint32_t)a; advances[c]++;
            break;
        case 'W':
            ad_pokey_write(&p[c], (uint8_t)a, (uint8_t)b); writes[c]++;
            break;
        case 'R': {
            int v = ad_pokey_read(&p[c], (uint8_t)a);
            if (n == 4 && (a & 0x0F) == R_RANDOM && v != b) mismatches[c]++;
            break;
        }
        case 'F': {
            int got = ad_pokey_audio_read(&p[c], buf, buflen);
            if (got) last[c] = buf[got - 1];
            if (got < a) { /* the adapter's own shortfall; keep our count */ }
            if (got < buflen) { shortframes[c]++; for (int j = got; j < buflen; ++j) buf[j] = last[c]; }
            for (int j = 0; j < buflen; ++j) hash[c] = (hash[c] ^ (uint16_t)buf[j]) * 16777619u;
            fwrite(buf, sizeof *buf, (size_t)buflen, out[c]);
            frames[c]++; samples[c] += (unsigned)got;
            break;
        }
        default: break;
        }
    }
    fclose(in);
    printf("trace: %d chips, clock %d, rate %d, %d samples/frame, %d fps%s\n",
           chips, clock, rate, buflen, fps, oneclock ? ", one-clock path" : "");
    for (int i = 0; i < chips; ++i) {
        fclose(out[i]);
        printf("chip %d: hash %08X  frames %u (short %u)  samples %u  writes %u  advances %u  "
               "clocks %llu (%.1f per frame)  RANDOM mismatches %u  queue left %u\n",
               i, hash[i], frames[i], shortframes[i], samples[i], writes[i], advances[i],
               (unsigned long long)clocks_total[i], frames[i] ? (double)clocks_total[i] / frames[i] : 0.0,
               mismatches[i], ad_pokey_audio_available(&p[i]));
    }
    return 0;
}
