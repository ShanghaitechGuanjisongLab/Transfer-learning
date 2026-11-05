@echo off
REM ============================================================================
REM  RunControl.bat —— 后台跑 A/B 门控实验，输出写进 ..\_control.log
REM  末行 RUN_DONE / RUN_CRASH。
REM
REM  用法：  rslds\RunControl.bat --iters 3     干跑
REM          rslds\RunControl.bat                全量（默认 300 轮，4 次拟合）
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_control.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === RunControl 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" RunControl.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
