@echo off
REM ============================================================================
REM  CheckSlowMode.bat —— 慢模式 vs 全局共模，输出写进 ..\_slow.log
REM  末行 RUN_DONE / RUN_CRASH。
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_slow.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === CheckSlowMode 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" CheckSlowMode.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
