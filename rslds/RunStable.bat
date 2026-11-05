@echo off
REM ============================================================================
REM  RunStable.bat —— 稳定性约束重拟，输出写进 ..\_sta.log
REM  末行 RUN_DONE / RUN_CRASH。
REM
REM  用法：  rslds\RunStable.bat --only 1 --iters 3    干跑
REM          rslds\RunStable.bat                       11 只鼠全跑（约 2 h）
REM          rslds\RunStable.bat --rho 0.995           换更松的约束
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_sta.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === RunStable 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" RunStable.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
