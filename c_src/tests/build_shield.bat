@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=amd64 -no_logo
cd /d "%~dp0.."
if not exist obj mkdir obj
cl /nologo /O2 /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS /I. /Foobj\ tests\probe_shield.c pokey.c sound.c sound_data.c sd_state.c /Fe:tests\shield_old.exe || exit /b 1
cl /nologo /O2 /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS /DUSE_C012294 /I. /Foobj\ tests\probe_shield.c c012294.c sound.c sound_data.c sd_state.c /Fe:tests\shield_new.exe || exit /b 1
tests\shield_old.exe obj\shield_old.pcm || exit /b 1
tests\shield_new.exe obj\shield_new.pcm || exit /b 1
fc /b obj\shield_old.pcm obj\shield_new.pcm >nul
if errorlevel 1 echo Player 1 differs from the old core.
tests\shield_old.exe obj\shield_old_p2.pcm 1 || exit /b 1
tests\shield_new.exe obj\shield_new_p2.pcm 1 || exit /b 1
fc /b obj\shield_old_p2.pcm obj\shield_new_p2.pcm >nul
if errorlevel 1 echo Player 2 differs from the old core.
exit /b 0
