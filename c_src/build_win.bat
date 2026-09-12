@echo off
rem Build the Space Duel C port with the Windows backend (x64).
rem Modeled on the Omega Race port's build_win.bat: the vendored
rem framework files compile at /W3 (verbatim copies, not ours to
rem rewrite); our code stays /W4 /std:c11.
rem
rem Targets:
rem   sd_win.exe            the game: app_loop.c + every core module +
rem                         platform\windows\* (c012294.c/er2055.c are the
rem                         chip models the seam drives - see README.md)
rem   tests\sd_selftest.exe headless scripted/timed run of the SAME
rem                         app_loop.c over platform\headless (see the
rem                         SD_SELFTEST_MAIN block in app_loop.c)
rem   tests\color_wheel.exe standalone beam-renderer diagnostic (no ROM,
rem                         no display list) - it defines its own sd_app_*
rem                         hooks, so it is NEVER linked with app_loop.c
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=amd64 -no_logo
cd /d "%~dp0"

set CORE=app_loop.c avg.c coins.c display.c display_data.c earom.c irq.c ^
lowones.c lowones_data.c mainline.c mainline_data.c msgs.c msgs_data.c ^
objects.c objects_data.c c012294.c er2055.c samples.c score.c score_data.c sd_state.c ^
sd_vecrom.c sd_progrom.c selftest.c selftest_data.c sound.c sound_data.c vgutil.c

if not exist obj mkdir obj

rem ---- vendored framework (verbatim copies: /W3, their own warnings) ----
cl /nologo /W3 /MD /D_CRT_SECURE_NO_WARNINGS /DUNICODE /D_UNICODE /c ^
   platform\windows\sys_gl.c platform\windows\glew.c ^
   platform\windows\log.c platform\windows\vector_draw.c ^
   platform\windows\mat4.c platform\windows\rawinput.c ^
   platform\windows\mixer.c platform\windows\fileio.c ^
   platform\windows\miniz.c platform\windows\ini.c ^
   platform\windows\joystick.c ^
   /Foobj\ || exit /b 1

rem ---- the game ---------------------------------------------------------
echo === sd_win.exe
cl /nologo /O2 /W4 /std:c11 /MD /D_CRT_SECURE_NO_WARNINGS /DUNICODE /D_UNICODE /I. /Foobj\ ^
   %CORE% platform\windows\plat_win.c ^
   obj\sys_gl.obj obj\glew.obj obj\log.obj ^
   obj\vector_draw.obj obj\mat4.obj obj\rawinput.obj ^
   obj\mixer.obj obj\fileio.obj obj\miniz.obj ^
   obj\ini.obj obj\joystick.obj ^
   /Fe:sd_win.exe ^
   /link user32.lib gdi32.lib winmm.lib || exit /b 1

rem ---- headless self-test (same loop, simulated clock, scripted input) ---
rem Objects go to obj\selftest\ so they never collide with the game's.
echo === tests\sd_selftest.exe
if not exist obj\selftest mkdir obj\selftest
cl /nologo /O2 /W4 /std:c11 /MD /D_CRT_SECURE_NO_WARNINGS /DSD_SELFTEST_MAIN /I. ^
   /Foobj\selftest\ ^
   %CORE% platform\headless\plat_headless.c ^
   /Fe:tests\sd_selftest.exe || exit /b 1

rem ---- renderer diagnostic (standalone; own sd_app_* hooks) -------------
echo === tests\color_wheel.exe
cl /nologo /W4 /std:c11 /MD /D_CRT_SECURE_NO_WARNINGS /DUNICODE /D_UNICODE /I. ^
   /Foobj\ ^
   tests\color_wheel.c samples.c platform\windows\plat_win.c ^
   obj\sys_gl.obj obj\glew.obj obj\log.obj ^
   obj\vector_draw.obj obj\mat4.obj obj\rawinput.obj ^
   obj\mixer.obj obj\fileio.obj obj\miniz.obj ^
   obj\ini.obj obj\joystick.obj ^
   /Fe:tests\color_wheel.exe ^
   /link user32.lib gdi32.lib winmm.lib || exit /b 1

echo ALL BUILDS OK
