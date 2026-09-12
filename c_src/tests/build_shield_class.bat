@echo off
rem Build the shield poly-4 class probe (see probe_shield_class.c).
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=amd64 -no_logo
cd /d "%~dp0.."
if not exist obj mkdir obj
set CORE=avg.c coins.c display.c display_data.c earom.c irq.c lowones.c lowones_data.c mainline.c mainline_data.c msgs.c msgs_data.c objects.c objects_data.c er2055.c samples.c score.c score_data.c sd_state.c sd_vecrom.c sd_progrom.c selftest.c selftest_data.c sound.c sound_data.c vgutil.c platform\headless\plat_headless.c
cl /nologo /O2 /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS /I. /Foobj\ tests\probe_shield_class.c c012294.c %CORE% /Fe:tests\shield_class.exe || exit /b 1
exit /b 0
