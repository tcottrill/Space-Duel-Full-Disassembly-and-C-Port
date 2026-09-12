@echo off
rem Isolated shield-script capture through the real sound engine (probe_shield.c):
rem legacy render and cycle audio, both players.  Hashes are printed for
rem comparison against earlier captures (see SHIELD_INVESTIGATION.md).
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=amd64 -no_logo
cd /d "%~dp0.."
if not exist obj mkdir obj
cl /nologo /O2 /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS /I. /Foobj\ tests\probe_shield.c c012294.c sound.c sound_data.c sd_state.c /Fe:tests\shield_new.exe || exit /b 1
tests\shield_new.exe obj\shield_new.pcm || exit /b 1
tests\shield_new.exe obj\shield_new_p2.pcm 1 || exit /b 1
tests\shield_new.exe obj\shield_cycle_comparison.pcm 0 cycle || exit /b 1
exit /b 0
