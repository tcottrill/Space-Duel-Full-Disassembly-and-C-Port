@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=amd64 -no_logo
cd /d "%~dp0.."
if not exist obj mkdir obj
set CORE=avg.c coins.c display.c display_data.c earom.c irq.c lowones.c lowones_data.c mainline.c mainline_data.c msgs.c msgs_data.c objects.c objects_data.c er2055.c samples.c score.c score_data.c sd_state.c sd_vecrom.c sd_progrom.c selftest.c selftest_data.c sound.c sound_data.c vgutil.c platform\headless\plat_headless.c
cl /nologo /O2 /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS /DUSE_C012294 /I. /Foobj\ tests\probe_shield_app.c c012294.c %CORE% /Fe:tests\shield_app_new.exe || exit /b 1
tests\shield_app_new.exe obj\shield_app_new.pcm 0 || exit /b 1
tests\shield_app_new.exe obj\shield_app_60.pcm 60 || exit /b 1
tests\shield_app_new.exe obj\shield_app_liveboot.pcm 60 obj\shield_liveboot_registers.csv liveboot || exit /b 1
exit /b 0
