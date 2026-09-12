@echo off
rem Build the Space Duel C port's headless probe harness(es).
rem Modeled on the Omega Race port's build_all.bat.
rem Harness sources live in tests\ and their exes are built there;
rem intermediate objects go to obj\.
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=amd64 -no_logo
cd /d "%~dp0"

set CORE=avg.c coins.c display.c display_data.c earom.c irq.c lowones.c lowones_data.c mainline.c mainline_data.c msgs.c msgs_data.c objects.c objects_data.c samples.c sd_state.c sd_vecrom.c sd_progrom.c selftest.c selftest_data.c sound.c sound_data.c vgutil.c
if exist score.c       set CORE=%CORE% score.c
if exist score_data.c  set CORE=%CORE% score_data.c

set FLAGS=/nologo /W4 /std:c11 /I. /Foobj\

if not exist obj mkdir obj

echo === probe_attract
cl %FLAGS% tests\probe_attract.c %CORE% /Fe:tests\probe_attract.exe || exit /b 1

echo === probe_selftest
cl %FLAGS% tests\probe_selftest.c %CORE% /Fe:tests\probe_selftest.exe || exit /b 1

rem The chip models' own checks (verbatim from the Asteroids Deluxe port,
rem see README.md), independent of the game: probe_c012294_audio drives a
rem local ad_pokey through probe_pokey.c's audio and table checks (its
rem matching header; the full core suite lives in tests\build_mute_phase.bat
rem and tests\build_c012294_ab.bat); probe_er2055 drives a local ad_er2055
rem directly and then through earom.c's real state machine.  AD_PROBE
rem exposes c012294.c's table accessors.
echo === probe_c012294_audio
cl %FLAGS% /DAD_PROBE tests\probe_c012294_audio.c c012294.c /Fe:tests\probe_c012294_audio.exe || exit /b 1

echo === probe_er2055
cl %FLAGS% tests\probe_er2055.c er2055.c earom.c sd_state.c /Fe:tests\probe_er2055.exe || exit /b 1

rem avg_dump has no hardware seam of its own: it links only the AVG walker.
echo === avg_dump
cl %FLAGS% tests\avg_dump.c avg.c sd_vecrom.c sd_state.c /Fe:tests\avg_dump.exe || exit /b 1

echo ALL BUILDS OK
