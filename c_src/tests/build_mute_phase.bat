@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=amd64 -no_logo
cd /d "%~dp0.."
if not exist obj mkdir obj
cl /nologo /O2 /W4 /std:c11 /I. /Foobj\ tests\test_pokey_mute_phase.c c012294.c /Fe:tests\test_pokey_mute_phase.exe || exit /b 1
tests\test_pokey_mute_phase.exe || exit /b 1
cl /nologo /O2 /W4 /std:c11 /DAD_PROBE /I. /Foobj\ tests\probe_c012294_audio.c c012294.c /Fe:tests\probe_c012294_audio.exe || exit /b 1
tests\probe_c012294_audio.exe
exit /b %errorlevel%
