@echo off
REM ============================================================================
REM  RunDimSweep.bat —— 潜维度 D=10/14 对照，输出写进 ..\_dim.log
REM  末行 RUN_DONE / RUN_CRASH。
REM
REM  用法：  rslds\RunDimSweep.bat --only 1 --iters 3 --dims 14   干跑测时
REM          rslds\RunDimSweep.bat                                3 只鼠全跑
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_dim.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === RunDimSweep 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" RunDimSweep.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
