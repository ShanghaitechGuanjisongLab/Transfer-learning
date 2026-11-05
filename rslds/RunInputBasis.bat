@echo off
REM ============================================================================
REM  RunInputBasis.bat —— 输入从 3 维扩到 8 维，看 ΔK 塌不塌。输出写进 ..\_inp.log
REM  末行 RUN_DONE / RUN_CRASH。
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_inp.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === RunInputBasis 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" RunInputBasis.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
