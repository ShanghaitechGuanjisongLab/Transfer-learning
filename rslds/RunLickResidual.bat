@echo off
REM ============================================================================
REM  RunLickResidual.bat —— 舔水回归（真 vs 伪），输出写进 ..\_lick.log
REM  末行 RUN_DONE / RUN_CRASH。
REM
REM  用法：  rslds\RunLickResidual.bat --only 1 --iters 3    干跑
REM          rslds\RunLickResidual.bat                       11 只鼠全跑（约 4 h）
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_lick.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === RunLickResidual 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" RunLickResidual.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
