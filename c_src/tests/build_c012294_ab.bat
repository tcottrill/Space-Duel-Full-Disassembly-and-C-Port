@echo off
rem A/B check of c012294.c against a saved golden copy (obj\c012294_golden.c),
rem plus the cost benchmark.  Usage: tests\build_c012294_ab.bat [save]
rem   save  - copy the working c012294.c to obj\c012294_golden.c first.
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=amd64 -no_logo
cd /d "%~dp0.."
if not exist obj mkdir obj
if "%1"=="save" copy /y c012294.c obj\c012294_golden.c >nul
if not exist obj\c012294_golden.c copy /y c012294.c obj\c012294_golden.c >nul
cl /nologo /O2 /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS /I. /Foobj\ tests\probe_c012294_golden.c obj\c012294_golden.c /Fe:tests\golden_a.exe || exit /b 1
cl /nologo /O2 /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS /I. /Foobj\ tests\probe_c012294_golden.c c012294.c /Fe:tests\golden_b.exe || exit /b 1
tests\golden_a.exe > obj\golden_a.txt || exit /b 1
tests\golden_b.exe > obj\golden_b.txt || exit /b 1
fc obj\golden_a.txt obj\golden_b.txt >nul
if errorlevel 1 (
  echo A/B MISMATCH:
  type obj\golden_a.txt
  echo ---- working copy:
  type obj\golden_b.txt
  exit /b 1
)
echo A/B identical:
type obj\golden_b.txt
cl /nologo /O2 /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS /I. /Foobj\ tests\probe_c012294_bench.c obj\c012294_golden.c /Fe:tests\bench_a.exe || exit /b 1
cl /nologo /O2 /W4 /std:c11 /D_CRT_SECURE_NO_WARNINGS /I. /Foobj\ tests\probe_c012294_bench.c c012294.c /Fe:tests\bench_b.exe || exit /b 1
echo golden:  & tests\bench_a.exe
echo working: & tests\bench_b.exe
exit /b 0
