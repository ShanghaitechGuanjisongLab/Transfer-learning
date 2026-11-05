@echo off
REM ============================================================================
REM  CheckCriticalSlowing.bat —— 切换前临界慢化 + 锁时潜伏期，输出写进 ..\_csd.log
REM  末行 RUN_DONE / RUN_CRASH。
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_csd.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === CheckCriticalSlowing 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" CheckCriticalSlowing.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
