@echo off
rem Build the AAE-trace replay probe against the golden core (obj\c012294_golden.c)
rem and the working core.  Usage: tests\build_replay.bat, then
rem   tests\replay_b.exe <trace> obj\<prefix> [oneclock]
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=amd64 -no_logo
cd /d "%~dp0.."
if not exist obj mkdir obj
if not exist obj\c012294_golden.c copy /y c012294.c obj\c012294_golden.c >nul
cl /nologo /O2 /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS /DNO_QUIET_SKIP_API /I. /Foobj\ tests\probe_c012294_replay.c obj\c012294_golden.c /Fe:tests\replay_a.exe || exit /b 1
cl /nologo /O2 /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS /I. /Foobj\ tests\probe_c012294_replay.c c012294.c /Fe:tests\replay_b.exe || exit /b 1
exit /b 0
