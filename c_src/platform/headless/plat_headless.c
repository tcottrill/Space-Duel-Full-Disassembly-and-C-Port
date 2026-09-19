/* plat_headless.c - Space Duel C port: shared harness backend.
 *
 * The whole sd_platform.h contract with no window, no sound and no real
 * clock (see plat_headless.h). Harnesses drive machine time themselves
 * and inspect the captured segment buffer after each frame.
 */
#include <stddef.h>
#include <string.h>
#include "plat_headless.h"

plat_inputs hl_inputs;                 /* zeroed = nothing pressed */
uint8_t hl_dsw_pokey1 = 0x01;
uint8_t hl_dsw_pokey2 = 0x00;

double hl_now_ms = 0.0;

hl_seg hl_segs[HL_MAX_SEGS];
int    hl_nsegs;
int    hl_frames;

void (*hl_vec_line_hook)(float, float, float, float, int, int) = NULL;
void (*hl_present_hook)(void) = NULL;
void (*hl_sample_start_hook)(int, int, int) = NULL;
void (*hl_sample_stop_hook)(int) = NULL;
void (*hl_sample_freq_hook)(int, float) = NULL;
void (*hl_audio_hook)(const int16_t*, int) = NULL;

int      hl_audio_rate;
uint64_t hl_audio_frames;
int      hl_audio_peak;

uint8_t  hl_nvram[HL_NVRAM_MAX];
unsigned hl_nvram_len = 0;

/* ---- lifecycle -------------------------------------------------------- */

int  plat_init(void)     { return 0; }
void plat_shutdown(void) { }

/* ---- video: capture --------------------------------------------------- */

void plat_video_begin(void) { hl_nsegs = 0; }

void plat_video_line(float x0, float y0, float x1, float y1, int color, int lum)
{
    if (hl_nsegs < HL_MAX_SEGS) {
        hl_seg* s = &hl_segs[hl_nsegs++];
        s->x0 = x0; s->y0 = y0; s->x1 = x1; s->y1 = y1;
        s->color = color; s->lum = lum;
    }
    if (hl_vec_line_hook) hl_vec_line_hook(x0, y0, x1, y1, color, lum);
}

void plat_video_present(void)
{
    hl_frames++;
    if (hl_present_hook) hl_present_hook();
}

/* ---- input ------------------------------------------------------------ */

void plat_input_poll(plat_inputs* in) { *in = hl_inputs; }

uint8_t plat_dsw_pokey1(void) { return hl_dsw_pokey1; }
int     plat_pokey_skip(void) { return 1; }
uint8_t plat_dsw_pokey2(void) { return hl_dsw_pokey2; }

/* ---- audio ------------------------------------------------------------ */

void plat_sample_start(int channel, int sample, int loop)
{
    if (hl_sample_start_hook) hl_sample_start_hook(channel, sample, loop);
}

void plat_sample_stop(int channel)
{
    if (hl_sample_stop_hook) hl_sample_stop_hook(channel);
}

void plat_sample_freq(int channel, float ratio)
{
    if (hl_sample_freq_hook) hl_sample_freq_hook(channel, ratio);
}

/* The POKEY stream: nothing plays, but every push is counted and its
 * loudest sample kept, so a harness can check the core's render rate
 * (frames pushed vs machine time) and that the chips made a sound. */
int plat_audio_open(int sample_rate)
{
    hl_audio_rate   = sample_rate;
    hl_audio_frames = 0;
    hl_audio_peak   = 0;
    return 0;
}

void plat_audio_push(const int16_t* pcm, int frames)
{
    int i;
    if (!pcm || frames <= 0) return;
    hl_audio_frames += (uint64_t)frames;
    for (i = 0; i < frames; i++) {
        int v = pcm[i] < 0 ? -(int)pcm[i] : (int)pcm[i];
        if (v > hl_audio_peak) hl_audio_peak = v;
    }
    if (hl_audio_hook) hl_audio_hook(pcm, frames);
}

void plat_audio_close(void) { hl_audio_rate = 0; }

/* ---- time: simulated --------------------------------------------------- */

double plat_now_ms(void)   { return hl_now_ms; }
void   plat_sleep_ms(int ms) { hl_now_ms += (double)ms; }

/* ---- NVRAM: in-memory image -------------------------------------------- */

int plat_nvram_read(void* buf, unsigned len)
{
    if (hl_nvram_len == 0 || len > hl_nvram_len || len > HL_NVRAM_MAX)
        return 1;
    memcpy(buf, hl_nvram, len);
    return 0;
}

int plat_nvram_write(const void* buf, unsigned len)
{
    if (len > HL_NVRAM_MAX) return 1;
    memcpy(hl_nvram, buf, len);
    hl_nvram_len = len;
    return 0;
}

/* ---- misc -------------------------------------------------------------- */

void plat_leds_out(uint8_t out_shadow) { (void)out_shadow; }
void plat_status_text(const char* s)   { (void)s; }
