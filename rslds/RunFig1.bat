@echo off
REM ============================================================================
REM  RunFig1.bat —— 后台跑档 2 的景观切片，输出写进 ..\_fig1.log
REM  末行 RUN_DONE / RUN_CRASH。
REM
REM  用法：  rslds\RunFig1.bat --only 1 --iters 3    干跑（验证做图代码）
REM          rslds\RunFig1.bat --only 1              单鼠
REM          rslds\RunFig1.bat                       11 只鼠全跑（约 1.6 h）
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_fig1.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === RunFig1 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" RunFig1.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
