@echo off
REM ============================================================================
REM  CheckInputShift.bat —— 定点随输入移动量，输出写进 ..\_shift.log
REM  末行 RUN_DONE / RUN_CRASH。
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_shift.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === CheckInputShift 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" CheckInputShift.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
