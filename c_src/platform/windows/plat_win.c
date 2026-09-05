/* plat_win.c - Space Duel C port: the modern Windows backend.
 *
 * Adapted from the Omega Race port's plat_win.c. Win32 + OpenGL 3.3 core
 * built on the framework files vendored into this directory: raw input
 * (key[] buffer), XAudio2 mixer, the shader beam renderer, DirectInput
 * joystick, DPI-aware window with ALT+ENTER borderless fullscreen, ini
 * config. Implements platform/sd_platform.h; the core neither knows nor
 * cares.
 *
 * Space Duel differences from the Omega Race backend:
 *  - COLOR vector game: plat_video_line carries (color 0..7, lum 0..15)
 *    instead of a mono z. The beam renderer runs in additive color mode
 *    (beam_set_color_mode(1)); the color map is the AVG hardware's
 *    3-bit RGB (see avg_rgb[] below).
 *  - no spinner: rotation is two buttons (Left/Right arrows).
 *  - files: sd_win.ini, sd_win.log, sd_c.nv.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "../sd_platform.h"
#include "../../samples.h" /* sample indices + wav names (core policy) */
#include "framework.h"     /* Windows.h, glew, log */
#include "sys_gl.h"
#include "rawinput.h"
#include "joystick.h"
#include "mixer.h"
#include "vector_draw.h"
#include "mat4.h"
#include "ini.h"
#include "colordefs.h"
#include <mmsystem.h>
#pragma comment(lib, "winmm.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")

/* ---- AVG color map ---------------------------------------------------
 * The STAT word's low 3 bits select the beam color directly as RGB
 * enable bits. Provenance: AAE's AVG transcription (aae_avg.cpp): for
 * the bwidow/spacduel/gravitar board the STAT handler does
 * `color = firstwd & 0x7` and draw_avg() maps it with VECTOR_COLOR111,
 * i.e. bit2 = RED, bit1 = GREEN, bit0 = BLUE (colordefs.h). Intensity
 * is draw_avg's `((z & 0xf) << 4) | 0xf`. MAME's avg_device for this
 * board family agrees. */
static const rgb_t avg_rgb[8] = {
    MAKE_RGB(0x00, 0x00, 0x00),   /* 0 black (never lit)      */
    MAKE_RGB(0x00, 0x00, 0xff),   /* 1 blue                   */
    MAKE_RGB(0x00, 0xff, 0x00),   /* 2 green                  */
    MAKE_RGB(0x00, 0xff, 0xff),   /* 3 cyan                   */
    MAKE_RGB(0xff, 0x00, 0x00),   /* 4 red                    */
    MAKE_RGB(0xff, 0x00, 0xff),   /* 5 magenta                */
    MAKE_RGB(0xff, 0xff, 0x00),   /* 6 yellow                 */
    MAKE_RGB(0xff, 0xff, 0xff),   /* 7 white                  */
};

/* ---- phosphor -------------------------------------------------------
 * Same scheme as the Omega Race backend: a vector monitor's phosphor is
 * still glowing from earlier frames when the beam comes round again, so
 * the screen shows a superposition of the last few frames at falling
 * brightness. Decay is a function of a frame's age in milliseconds
 * (never frames-back: the frame rate floats with display-list length).
 *
 * [vector] phosphor_ms in sd_win.ini is the decay time constant: a
 * frame is drawn at exp(-age_ms / phosphor_ms) of the intensity the AVG
 * gave it (the color stays; only intensity decays). 0 turns the path
 * off (one frame, full brightness). */
#define PH_FRAMES  8            /* history depth                        */
#define PH_SEGS    4096         /* segments captured per frame          */
#define PH_FLOOR   0.02         /* drop a frame once it fades below this */

typedef struct { float x0, y0, x1, y1; int color, lum; } ph_seg;
typedef struct { ph_seg seg[PH_SEGS]; int n; double t; int used; } ph_frame;

static ph_frame ph_buf[PH_FRAMES];
static int      ph_cur;
static double   ph_tau;         /* ms; 0 = phosphor off                 */
static int      ph_dropped;     /* segments lost to PH_SEGS, logged once */

/* ------------------------------------------------------------------ */
/* framework externs (framework.h declares these; the host defines)    */
/* ------------------------------------------------------------------ */

static HWND hWnd;
static int  g_quit;

int SCREEN_W = 1024;      /* window client area, physical pixels */
int SCREEN_H = 768;
int DESIGN_W = 1024;      /* the design rect ViewOrthoScaled letterboxes */
int DESIGN_H = 768;

HWND win_get_window(void) { return hWnd; }

static void msg_box(const char* title, const char* message)
{
    MessageBoxA(NULL, message, title, MB_ICONEXCLAMATION | MB_OK);
}

static void set_window_title(const char* title) { SetWindowTextA(hWnd, title); }

/* ------------------------------------------------------------------ */
/* DPI awareness                                                       */
/* ------------------------------------------------------------------ */

#ifndef DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
#define DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 ((DPI_AWARENESS_CONTEXT)-4)
#endif
#ifndef USER_DEFAULT_SCREEN_DPI
#define USER_DEFAULT_SCREEN_DPI 96
#endif
#ifndef WM_DPICHANGED
#define WM_DPICHANGED 0x02E0
#endif

static void enable_dpi_awareness(void)
{
    typedef BOOL(WINAPI* SetProcessDpiAwarenessContext_t)(DPI_AWARENESS_CONTEXT);
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    if (user32) {
        SetProcessDpiAwarenessContext_t set_ctx = (SetProcessDpiAwarenessContext_t)
            GetProcAddress(user32, "SetProcessDpiAwarenessContext");
        if (set_ctx && set_ctx(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2))
            return;
    }
    SetProcessDPIAware();
}

static UINT window_dpi(HWND hwnd)
{
    typedef UINT(WINAPI* GetDpiForWindow_t)(HWND);
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    UINT dpi = 0;
    if (user32) {
        GetDpiForWindow_t get_dpi = (GetDpiForWindow_t)
            GetProcAddress(user32, "GetDpiForWindow");
        if (get_dpi) dpi = get_dpi(hwnd);
    }
    if (dpi == 0) {
        HDC hdc = GetDC(NULL);
        if (hdc) {
            dpi = (UINT)GetDeviceCaps(hdc, LOGPIXELSY);
            ReleaseDC(NULL, hdc);
        }
    }
    return dpi ? dpi : USER_DEFAULT_SCREEN_DPI;
}

static void size_window_for_dpi(HWND hwnd, UINT dpi, DWORD style)
{
    typedef BOOL(WINAPI* AdjustWindowRectExForDpi_t)(LPRECT, DWORD, BOOL, DWORD, UINT);
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    AdjustWindowRectExForDpi_t adjust_for_dpi = NULL;
    RECT wr;

    wr.left = 0;
    wr.top = 0;
    wr.right = MulDiv(DESIGN_W, (int)dpi, USER_DEFAULT_SCREEN_DPI);
    wr.bottom = MulDiv(DESIGN_H, (int)dpi, USER_DEFAULT_SCREEN_DPI);

    if (user32)
        adjust_for_dpi = (AdjustWindowRectExForDpi_t)
            GetProcAddress(user32, "AdjustWindowRectExForDpi");
    if (adjust_for_dpi)
        adjust_for_dpi(&wr, style, FALSE, 0, dpi);
    else
        AdjustWindowRect(&wr, style, FALSE);

    SetWindowPos(hwnd, NULL, 0, 0, wr.right - wr.left, wr.bottom - wr.top,
                 SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
}

/* ------------------------------------------------------------------ */
/* borderless fullscreen, ALT+ENTER                                    */
/* ------------------------------------------------------------------ */

static int      is_fullscreen;
static RECT     windowed_rect;
static LONG_PTR windowed_style;
static LONG_PTR windowed_exstyle;

int IsFullscreen(void) { return is_fullscreen; }

void ToggleFullscreen(void)
{
    if (is_fullscreen) {
        SetWindowLongPtr(hWnd, GWL_STYLE, windowed_style);
        SetWindowLongPtr(hWnd, GWL_EXSTYLE, windowed_exstyle);
        SetWindowPos(hWnd, HWND_NOTOPMOST,
                     windowed_rect.left, windowed_rect.top,
                     windowed_rect.right - windowed_rect.left,
                     windowed_rect.bottom - windowed_rect.top,
                     SWP_FRAMECHANGED | SWP_SHOWWINDOW);
        is_fullscreen = 0;
    } else {
        MONITORINFO mi = { sizeof(mi) };
        GetMonitorInfo(MonitorFromWindow(hWnd, MONITOR_DEFAULTTONEAREST), &mi);
        GetWindowRect(hWnd, &windowed_rect);
        windowed_style = GetWindowLongPtr(hWnd, GWL_STYLE);
        windowed_exstyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE);
        SetWindowLongPtr(hWnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
        SetWindowLongPtr(hWnd, GWL_EXSTYLE, WS_EX_APPWINDOW | WS_EX_TOPMOST);
        SetWindowPos(hWnd, HWND_TOPMOST,
                     mi.rcMonitor.left, mi.rcMonitor.top,
                     mi.rcMonitor.right - mi.rcMonitor.left,
                     mi.rcMonitor.bottom - mi.rcMonitor.top,
                     SWP_FRAMECHANGED | SWP_SHOWWINDOW);
        is_fullscreen = 1;
    }
}

/* ------------------------------------------------------------------ */
/* resolution-independent beam width                                   */
/* ------------------------------------------------------------------ */

/* The beam renderer takes its width and AA feather in DESIGN units (520
 * AVG units span the letterboxed viewport), so a fixed design width gets
 * FAT at small windows: 2.0 design units + a 1.5-unit feather is ~7 px
 * of line at a 600-px-tall window.  So in THIS backend the two ini keys
 * the renderer reads, [vector] linewidth and line_smoothing, mean
 * the beam width in PIXELS AT THE DEFAULT 1024-WIDE WINDOW,
 * scaling in proportion with the picture from there, and the AA feather
 * in PHYSICAL PIXELS on any screen (defaults 2.5 and 1.25) - see
 * update_beam_width() for both conversions.  (Until 2026-09-03 the pixel width was a separate
 * linewidth_px key that silently overrode both - editing linewidth did
 * nothing; that key is ignored now.  The Asteroids Deluxe port still
 * reads these two as design units.) */
static float beam_px = 2.5f;             /* [vector] linewidth, pixels      */
static float beam_feather_px = 1.25f;    /* [vector] line_smoothing, pixels */

static void update_beam_width(void)
{
    double vw;

    /* WIDTH IS PROPORTIONAL (2026-09-03, user's choice after trying
     * constant-pixel): the beam scales with the picture, so a window and
     * fullscreen look the same relative to the drawing.  [vector]
     * linewidth is calibrated as pixels at the default DESIGN_W-wide
     * (1024) window: one design unit of the beam projection's 520-unit
     * span is 520 / 1024 of a pixel there, so linewidth=2.5 draws 2.5 px
     * at that size and 2.5 * (viewport width / 1024) px on a bigger
     * screen. */
    beam_set_linewidth((float)(beam_px * 520.0 / (double)DESIGN_W));

    /* THE FEATHER IS PHYSICAL PIXELS: anti-aliasing is a property of the
     * pixel grid, not of the drawing, so [vector] line_smoothing means
     * that many pixels of edge ramp on ANY screen - converted from the
     * letterboxed viewport's actual pixel width (ViewOrthoScaled's fit),
     * and redone on every WM_SIZE, fullscreen toggles included.  (Scaling
     * the feather with the picture, as the first proportional version
     * did, made every setting look fully anti-aliased in fullscreen: a
     * 0.8 ramp became 2 px on a 2560-wide panel.) */
    vw = (double)SCREEN_W;
    if ((double)SCREEN_H * DESIGN_W < vw * DESIGN_H)
        vw = (double)SCREEN_H * DESIGN_W / (double)DESIGN_H;
    if (vw < 1.0) vw = 1.0;
    beam_set_smoothing((float)(beam_feather_px * 520.0 / vw));
}

/* ------------------------------------------------------------------ */
/* window procedure                                                    */
/* ------------------------------------------------------------------ */

static LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    switch (message) {
    case WM_SIZE:
        if (wParam != SIZE_MINIMIZED) {
            SCREEN_W = LOWORD(lParam);
            SCREEN_H = HIWORD(lParam);
            ViewOrthoScaled(SCREEN_W, SCREEN_H, DESIGN_W, DESIGN_H);
            update_beam_width();
        }
        return 0;

    case WM_DPICHANGED: {
        const RECT* suggested = (const RECT*)lParam;
        SetWindowPos(hwnd, NULL, suggested->left, suggested->top,
                     suggested->right - suggested->left,
                     suggested->bottom - suggested->top,
                     SWP_NOZORDER | SWP_NOACTIVATE);
        return 0;
    }

    case WM_SYSKEYDOWN:
        /* ALT+ENTER; lParam bit 29 is the recorded ALT context flag. */
        if (wParam == VK_RETURN && (lParam & (1 << 29))) {
            ToggleFullscreen();
            key[KEY_ENTER] = 0;    /* raw input saw the keystroke too */
            return 0;
        }
        return DefWindowProc(hwnd, message, wParam, lParam);

    case WM_ERASEBKGND:
        return 1;                  /* GL owns every pixel */

    case WM_SYSCOMMAND:
        /* Thrust is bound to ALT, and DefWindowProc turns a lone ALT
         * release into SC_KEYMENU - the modal window-menu loop, which
         * blocks the game loop until the next input (reads as a
         * multi-second freeze). No menu exists; eat it. */
        if ((wParam & 0xFFF0) == SC_KEYMENU) return 0;
        return DefWindowProc(hwnd, message, wParam, lParam);

    case WM_SETCURSOR:
        /* Fullscreen is the cabinet: no cursor over the game. Windowed
         * mode (and the frame edges) keep the arrow for resizing. */
        if (is_fullscreen && LOWORD(lParam) == HTCLIENT) {
            SetCursor(NULL);
            return 1;
        }
        return DefWindowProc(hwnd, message, wParam, lParam);

    case WM_CLOSE:
        DestroyWindow(hwnd);
        return 0;

    case WM_INPUT:
        RawInput_ProcessInput(hwnd, wParam, lParam);
        return DefWindowProc(hwnd, message, wParam, lParam);

    case WM_DEVICECHANGE:
        joystick_device_change();
        return DefWindowProc(hwnd, message, wParam, lParam);

    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;

    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE) { PostQuitMessage(0); return 0; }
        return 0;

    default:
        return DefWindowProc(hwnd, message, wParam, lParam);
    }
}

/* ------------------------------------------------------------------ */
/* lifecycle                                                           */
/* ------------------------------------------------------------------ */

static float beam_proj[16];

#define KEY_HELP "Left/Right rotate, Ctrl fire, Up or Alt thrust, " \
                 "Space/Down/Shift shield, 5 coin, 1/2 start, 7 select, Esc quit"

/* [sound] settings, read in plat_init (see there). */
static int pokey_volume = 100;        /* pokey_volume, percent, 0 = off  */
static int samples_on = 1;            /* samples: 1 play wavs, 0 mute    */

int plat_init(void)
{
    WNDCLASS wc;
    DWORD dwStyle;
    RECT wr = { 0, 0, 1024, 768 };
    int swap_mode;
    HINSTANCE hInstance = GetModuleHandle(NULL);

    enable_dpi_awareness();

    memset(&wc, 0, sizeof wc);
    wc.style = CS_OWNDC;
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.hIcon = LoadIcon(NULL, IDI_APPLICATION);
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
    wc.lpszClassName = L"SpaceDuelWin";
    if (!RegisterClass(&wc)) {
        msg_box("Space Duel C", "Failed to register the window class.");
        return 1;
    }

    dwStyle = WS_CAPTION | WS_POPUPWINDOW | WS_VISIBLE | WS_CLIPSIBLINGS
            | WS_CLIPCHILDREN | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
    AdjustWindowRect(&wr, dwStyle, FALSE);
    hWnd = CreateWindow(L"SpaceDuelWin", L"Space Duel C", dwStyle,
                        0, 0, wr.right - wr.left, wr.bottom - wr.top,
                        NULL, NULL, hInstance, NULL);
    if (!hWnd) {
        msg_box("Space Duel C", "Failed to create the main window.");
        return 1;
    }

    log_open("sd_win.log");
    log_set_level(LOG_LEVEL_INFO);
    LOG_INFO("sd_win backend starting");

    size_window_for_dpi(hWnd, window_dpi(hWnd), dwStyle);

    /* Settings. beam_init reads [vector] from the same file. */
    set_config_file("sd_win.ini");
    /* vsync OFF by default: the game will pace itself at the hardware's
     * floating rate (as the Omega Race port established) and a vsynced
     * flip quantizes that to the panel's refresh, which reads as
     * judder. [main] vsync: 0 off / 1 on / 2 adaptive. */
    swap_mode = get_config_int("main", "vsync", 0);
    set_config_int("main", "vsync", swap_mode);

    /* Phosphor decay time constant, ms (see the block above). A tuning
     * knob, defaulted short. 0 = off. */
    ph_tau = (double)get_config_float("vector", "phosphor_ms", 12.0f);
    set_config_float("vector", "phosphor_ms", (float)ph_tau);

    if (FAILED(RawInput_Initialize(hWnd))) {
        msg_box("Space Duel C",
            "Failed to register for raw input; keyboard and mouse will not work.");
        LOG_ERROR("RawInput_Initialize failed");
    }

    install_joystick();          /* zero sticks is fine */

    if (mixer_init() != 0)
        LOG_ERROR("mixer_init failed; continuing without audio");

    /* [sound] pokey_volume: the two POKEYs' streamed output, 0..100
     * percent (0 = off, the core then skips rendering); samples: 1 plays
     * the recorded-sample path (samples\*.wav) on top of it, 0 mutes it.
     * Both paths are independent seams (SOUNDS.md), so either can run
     * alone. */
    pokey_volume = get_config_int("sound", "pokey_volume", 100);
    if (pokey_volume < 0)   pokey_volume = 0;
    if (pokey_volume > 100) pokey_volume = 100;
    set_config_int("sound", "pokey_volume", pokey_volume);
    samples_on = get_config_int("sound", "samples", 1) != 0;
    set_config_int("sound", "samples", samples_on);

    if (!CreateGLContext()) {
        msg_box("Space Duel C", "Failed to create an OpenGL context.");
        return 1;
    }
    SetSwapMode(swap_mode);
    ViewOrthoScaled(SCREEN_W, SCREEN_H, DESIGN_W, DESIGN_H);

    if (!beam_init()) {
        msg_box("Space Duel C",
            "Beam renderer failed to build (needs OpenGL 3.3) - see sd_win.log.");
        return 1;
    }
    beam_set_color_mode(1);      /* color game: additive blending */

    /* Pixel-based beam width (see update_beam_width above).  beam_init has
     * just read the same two keys as design units and applied them; read
     * them again here as pixels and re-apply, so the ini's numbers are the
     * ones on screen at any window size. */
    beam_px = get_config_float("vector", "linewidth", 2.5f);
    beam_feather_px = get_config_float("vector", "line_smoothing", 1.25f);
    if (beam_px < 0.1f) beam_px = 0.1f;
    if (beam_feather_px < 0.0f) beam_feather_px = 0.0f;
    set_config_float("vector", "linewidth", beam_px);
    set_config_float("vector", "line_smoothing", beam_feather_px);
    update_beam_width();
    LOG_INFO("beam: %.2f px wide at a 1024-wide window (proportional), %.2f px feather on any screen ([vector] linewidth / line_smoothing)",
             beam_px, beam_feather_px);

    /* [main] fps_lock: underclock the whole machine so the frame gate
     * lands on the panel's refresh rate instead of the hardware's
     * 61.5234 Hz, which beats against a 60 Hz monitor as a dropped frame
     * every ~0.65 s. fps_lock=60 runs 2.48% slow but stutter-free;
     * 0 (default) = authentic. Pairs well with vsync=1 on a matching
     * panel. */
    {
        float fps_lock = get_config_float("main", "fps_lock", 0.0f);
        set_config_float("main", "fps_lock", fps_lock);
        sd_app_set_fps_lock((double)fps_lock);
    }

    /* The AVG screen window for this board: x 0..520, y 0..395, y up
     * (AAE drv_spacduel AAE_DRIVER_SCREEN), squeezed into the 4:3
     * design rect. */
    mat4_ortho(beam_proj, 0.0f, 520.0f, 0.0f, 395.0f, -1.0f, 1.0f);

    /* 1 ms scheduler resolution: without it Sleep(1) rounds up to the
     * 15.6 ms quantum and the pacing loop repays the debt by firing
     * frames early - which reads as judder. */
    timeBeginPeriod(1);

    set_window_title("Space Duel C - " KEY_HELP);
    ShowWindow(hWnd, SW_SHOW);
    return 0;
}

void plat_shutdown(void)
{
    timeEndPeriod(1);
    beam_shutdown();
    remove_joystick();
    plat_audio_close();     /* stream voice first: mixer_end tears down g_xa2 */
    mixer_end();
    DeleteGLContext();
    LOG_INFO("sd_win backend closing");
    log_close();
    if (IsWindow(hWnd)) DestroyWindow(hWnd);
}

/* ------------------------------------------------------------------ */
/* video: the color beam segment sink                                  */
/* ------------------------------------------------------------------ */

void plat_video_begin(void)
{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    ph_cur = (ph_cur + 1) % PH_FRAMES;
    ph_buf[ph_cur].n = 0;
    ph_buf[ph_cur].used = 1;
}

/* Line sink for the AVG walker. (color 0..7, lum 0..15) as the STAT/VCTR
 * words produced them; the mapping to RGB and to the (lum<<4)|0x0f
 * brightness happens at present time so phosphor decay can scale the
 * intensity while the hue stays put. A zero-length segment is a dot:
 * the beam renderer gives the degenerate segment's lone endpoint a
 * round end-cap disc. */
void plat_video_line(float x0, float y0, float x1, float y1, int color, int lum)
{
    ph_frame* f = &ph_buf[ph_cur];
    if (f->n < PH_SEGS) {
        ph_seg* s = &f->seg[f->n++];
        s->x0 = x0; s->y0 = y0; s->x1 = x1; s->y1 = y1;
        s->color = color & 7;
        s->lum = lum & 15;
    } else if (!ph_dropped) {
        ph_dropped = 1;
        LOG_WARN("display list exceeded %d segments; phosphor history "
                 "is truncating frames", PH_SEGS);
    }
}

/* Replay the phosphor history oldest-first, each frame's intensity
 * scaled by its own decay, then draw the batch additively (color mode:
 * overlapping beams sum, corner joins fill via GL_MAX - see
 * vector_draw.c). */
void plat_video_present(void)
{
    double now = plat_now_ms();
    int i;

    ph_buf[ph_cur].t = now;

    beam_clear();
    for (i = 0; i < PH_FRAMES; i++) {
        /* oldest first: start one past the newest and wrap */
        ph_frame* f = &ph_buf[(ph_cur + 1 + i) % PH_FRAMES];
        double fac;
        int k;

        if (!f->used) continue;
        if (f == &ph_buf[ph_cur]) fac = 1.0;
        else if (ph_tau <= 0.0)   continue;  /* phosphor off */
        else {
            fac = exp(-(now - f->t) / ph_tau);
            if (fac < PH_FLOOR) continue;
        }
        for (k = 0; k < f->n; k++) {
            const ph_seg* s = &f->seg[k];
            int intens = (int)((double)((s->lum << 4) | 0x0f) * fac + 0.5);
            if (intens <= 0) continue;
            beam_add_line(s->x0, s->y0, s->x1, s->y1, intens, avg_rgb[s->color]);
        }
    }

    beam_draw_all(beam_proj);
    glSwap();
}

/* ------------------------------------------------------------------ */
/* input                                                               */
/* ------------------------------------------------------------------ */

void plat_input_poll(plat_inputs* in)
{
    memset(in, 0, sizeof *in);

    /* Fire, thrust and shield each answer to two keys (Alt grabs the
     * window menu on Windows, so Up/Space are first-class). */
    in->fire         = key[KEY_LCONTROL] ? 1 : 0;
    in->thrust       = (key[KEY_ALT] || key[KEY_UP]) ? 1 : 0;
    in->shield       = (key[KEY_LSHIFT] || key[KEY_DOWN] || key[KEY_SPACE]) ? 1 : 0;
    in->rotate_left  = key[KEY_LEFT] ? 1 : 0;
    in->rotate_right = key[KEY_RIGHT] ? 1 : 0;
    in->coin1        = key[KEY_5] ? 1 : 0;
    in->coin2        = key[KEY_6] ? 1 : 0;
    in->coin3        = key[KEY_8] ? 1 : 0;   /* utility coin line */
    in->start1       = key[KEY_1] ? 1 : 0;
    in->start2       = key[KEY_2] ? 1 : 0;
    in->game_select  = key[KEY_7] ? 1 : 0;
    /* 9 is the cabinet self-test switch line (held = on), F1 the
     * diagnostic-step button, F2 the host's service-mode TOGGLE (edge-
     * detected in the core, as MAME's F2 - press once for the bookkeeping
     * screen, again to leave; held at launch = power-on diagnostics). */
    in->test         = key[KEY_9] ? 1 : 0;
    in->diag_step    = key[KEY_F1] ? 1 : 0;
    in->diag         = key[KEY_F2] ? 1 : 0;
    in->quit         = key[KEY_ESC] ? 1 : 0;

    /* Joystick: stick left/right rotates, button 1 fires, 2 thrusts,
     * 3 shields, 8 coins, 9 starts (an Xbox pad's Back/Start land
     * there). Inert with no device. */
    poll_joystick();
    if (num_joysticks > 0 && joystick_is_connected(0)) {
        if (joy_left)  in->rotate_left  = 1;
        if (joy_right) in->rotate_right = 1;
        if (joy[0].num_buttons > 0 && joy[0].button[0].b) in->fire   = 1;
        if (joy[0].num_buttons > 1 && joy[0].button[1].b) in->thrust = 1;
        if (joy[0].num_buttons > 2 && joy[0].button[2].b) in->shield = 1;
        if (joy[0].num_buttons > 7 && joy[0].button[7].b) in->coin1  = 1;
        if (joy[0].num_buttons > 8 && joy[0].button[8].b) in->start1 = 1;
    }
}

/* DIP defaults = the MAME/AAE spacduel factory settings:
 * POKEY1 bank (DSW0): 0x01 = 3 lives, normal difficulty, English,
 * bonus at 10000. POKEY2 bank (DSW1): 0x00 = 1 coin 1 credit, no
 * bonus coins. Which bank answers which POKEY is core policy (sd_hw.h);
 * these just supply the bytes. */
uint8_t plat_dsw_pokey1(void) { return 0x01; }
uint8_t plat_dsw_pokey2(void) { return 0x00; }

void plat_leds_out(uint8_t out_shadow) { (void)out_shadow; }

/* ------------------------------------------------------------------ */
/* audio                                                               */
/* ------------------------------------------------------------------ */

/* Recorded-sample path. Sample indices and wav base names are core
 * policy (samples.h); this backend resolves index -> mixer sample
 * lazily: a loose file samples\<name>.wav first, then <name>.wav inside
 * a MAME-style samples\spacduel.zip, then the core's fallback index
 * (fire2 -> fire1 etc.). A wav that is nowhere stays silent. */
#define SAMPLES_ZIP "samples\\spacduel.zip"

static int wav_tried[SD_SMP_COUNT];
static int wav_num[SD_SMP_COUNT];     /* mixer sample number, -1 = missing */
static int chan_base[MIXER_MAX_CHANNELS]; /* native Hz of playing sample */

static int wav_lookup(int sample)
{
    if (sample < 0 || sample >= SD_SMP_COUNT) return -1;
    if (!wav_tried[sample]) {
        char path[96];
        wav_tried[sample] = 1;
        snprintf(path, sizeof path, "samples\\%s.wav",
                 sd_sample_names[sample]);
        wav_num[sample] = load_sample(NULL, path);
        if (wav_num[sample] < 0) {
            snprintf(path, sizeof path, "%s.wav", sd_sample_names[sample]);
            wav_num[sample] = load_sample(SAMPLES_ZIP, path);
        }
        if (wav_num[sample] < 0 && sd_sample_fallback[sample] >= 0)
            wav_num[sample] = wav_lookup(sd_sample_fallback[sample]);
    }
    return wav_num[sample];
}

void plat_sample_start(int channel, int sample, int loop)
{
    int n;

    if (channel < 0 || channel >= MIXER_MAX_CHANNELS) return;
    if (!samples_on) return;
    n = wav_lookup(sample);
    if (n < 0) return;
    sample_start(channel, n, loop);
    chan_base[channel] = sample_get_freq(channel);  /* native rate */
}

void plat_sample_stop(int channel)
{
    if (channel < 0 || channel >= MIXER_MAX_CHANNELS) return;
    sample_stop(channel);
}

void plat_sample_freq(int channel, float ratio)
{
    if (channel < 0 || channel >= MIXER_MAX_CHANNELS) return;
    if (chan_base[channel] <= 0 || ratio <= 0.0f) return;
    sample_set_freq(channel, (int)(ratio * (float)chan_base[channel] + 0.5f));
}

/* The POKEYs' own output, streamed: the core renders both chips (pokey.c)
 * into one mono block per IRQ tick and pushes it here; mixer.c's stream
 * voice (XAudio2) plays the blocks back to back. [sound] pokey_volume=0
 * refuses the open, and the core stops rendering. */
int plat_audio_open(int sample_rate)
{
    if (pokey_volume <= 0) {
        LOG_INFO("POKEY stream off ([sound] pokey_volume=0)");
        return -1;
    }
    if (stream_open(sample_rate, 1) != 0)    /* mono, matches ad_pokey_render */
        return -1;
    stream_set_volume(mixer_percent_to_byte(pokey_volume));
    return 0;
}

void plat_audio_push(const int16_t* pcm, int frames)
{
    stream_push(pcm, frames);
}

void plat_audio_close(void)
{
    stream_close();
}

/* ------------------------------------------------------------------ */
/* time                                                                */
/* ------------------------------------------------------------------ */

double plat_now_ms(void)
{
    LARGE_INTEGER cnt;
    static LARGE_INTEGER freq;
    if (!freq.QuadPart) QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&cnt);
    return (double)cnt.QuadPart * 1000.0 / (double)freq.QuadPart;
}

void plat_sleep_ms(int ms) { Sleep((DWORD)ms); }

/* ------------------------------------------------------------------ */
/* NVRAM (EAROM): the core's blob, stored as sd_c.nv                   */
/* ------------------------------------------------------------------ */

int plat_nvram_read(void* buf, unsigned len)
{
    size_t got;
    FILE* f = fopen("sd_c.nv", "rb");
    if (!f) return 1;
    got = fread(buf, 1, len, f);
    fclose(f);
    return got == len ? 0 : 1;
}

int plat_nvram_write(const void* buf, unsigned len)
{
    FILE* f = fopen("sd_c.nv", "wb");
    if (!f) return 1;
    fwrite(buf, 1, len, f);
    fclose(f);
    return 0;
}

/* ------------------------------------------------------------------ */
/* status + main loop                                                  */
/* ------------------------------------------------------------------ */

void plat_status_text(const char* s)
{
    char buf[240];
    snprintf(buf, sizeof buf, "Space Duel C  %s  - " KEY_HELP, s);
    set_window_title(buf);
    /* Also to sd_win.log. The core sends this about once a second and it
     * carries the pacing numbers (fps, frame time, display-list size); a
     * window title cannot be read back from a scripted/background run, and
     * measuring the delivered frame rate is exactly what the pacing model
     * needs to be checked against. */
    LOG_INFO("%s", s);
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
                   LPSTR lpCmdLine, int iCmdShow)
{
    MSG msg;
    (void)hInstance; (void)hPrevInstance; (void)lpCmdLine; (void)iCmdShow;

    if (plat_init()) return 1;
    sd_app_init();

    while (!g_quit) {
        /* Drain the queue - raw input arrives at the mouse's report rate
         * and would starve the loop if handled one message per pass. */
        while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) { g_quit = 1; break; }
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }
        if (g_quit) break;

        {
            double wait = sd_app_step(plat_now_ms());
            if (wait > 3.0) plat_sleep_ms(1);   /* 1 ms sleep, then spin */
        }
    }

    sd_app_exit();
    plat_shutdown();
    return 0;
}
