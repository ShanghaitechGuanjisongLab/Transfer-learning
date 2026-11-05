@echo off
REM ============================================================================
REM  CheckLickAxis.bat —— 状态轴里舔水占多少，输出写进 ..\_lickaxis.log
REM  末行 RUN_DONE / RUN_CRASH。
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_lickaxis.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === CheckLickAxis 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" CheckLickAxis.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
