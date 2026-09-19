/* plat_headless.h - injection/capture hooks for the shared harness backend.
 *
 * Harness builds (probes, future test_drive) link plat_headless.c as
 * their platform backend: the full sd_platform.h contract with no
 * window, no sound and no real clock. Inputs are injected by the
 * harness; every plat_video_line segment is captured into a per-frame
 * buffer (and optionally forwarded to a hook) so probes can diff the
 * rendered list; sample commands go to hooks and the POKEY audio stream
 * is counted (frames, peak level) and optionally forwarded; NVRAM is an
 * in-memory image the harness can preload or inspect; time is a
 * simulated clock the harness advances.
 *
 * Adapted from the Omega Race port's plat_headless.[ch]. One deliberate
 * difference: Omega's headless also owned the game state and the
 * omega_hw_* seam. Space Duel probes diff raw RAM/vram against the
 * oracle at the sd_hw_* level (sd_hw.h), so that seam stays with the
 * harness; this file is only the plat_* contract.
 */
#ifndef PLAT_HEADLESS_H
#define PLAT_HEADLESS_H

#include <stdint.h>
#include "../sd_platform.h"

/* ---- injected inputs -------------------------------------------------- */
extern plat_inputs hl_inputs;      /* copied out by plat_input_poll        */
extern uint8_t hl_dsw_pokey1;      /* default 0x01 (factory DSW0)          */
extern uint8_t hl_dsw_pokey2;      /* default 0x00 (factory DSW1)          */

/* ---- simulated clock --------------------------------------------------- */
extern double hl_now_ms;           /* plat_now_ms returns this;
                                      plat_sleep_ms(ms) advances it        */

/* ---- captured video ---------------------------------------------------- */
typedef struct {
    float x0, y0, x1, y1;
    int color, lum;
} hl_seg;

#define HL_MAX_SEGS 8192
extern hl_seg hl_segs[HL_MAX_SEGS];  /* the current frame's segments       */
extern int    hl_nsegs;              /* reset by plat_video_begin           */
extern int    hl_frames;             /* frames completed (present count)    */

/* optional hooks, NULL = just the buffer / discard */
extern void (*hl_vec_line_hook)(float x0, float y0, float x1, float y1,
                                int color, int lum);
extern void (*hl_present_hook)(void);
extern void (*hl_sample_start_hook)(int channel, int sample, int loop);
extern void (*hl_sample_stop_hook)(int channel);
extern void (*hl_sample_freq_hook)(int channel, float ratio);
extern void (*hl_audio_hook)(const int16_t* pcm, int frames);

/* ---- the POKEY audio stream, counted ----------------------------------- */
extern int      hl_audio_rate;     /* plat_audio_open's rate, 0 = closed   */
extern uint64_t hl_audio_frames;   /* frames pushed since open             */
extern int      hl_audio_peak;     /* loudest |sample| pushed since open   */

/* ---- NVRAM: in-memory image -------------------------------------------- */
#define HL_NVRAM_MAX 256
extern uint8_t hl_nvram[HL_NVRAM_MAX];
extern unsigned hl_nvram_len;      /* 0 = no stored image (read fails)     */

#endif /* PLAT_HEADLESS_H */
