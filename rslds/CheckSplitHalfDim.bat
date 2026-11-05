@echo off
REM ============================================================================
REM  CheckSplitHalfDim.bat —— split-half 维度检验，输出写进 ..\_half.log
REM  末行 RUN_DONE / RUN_CRASH。
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_half.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === CheckSplitHalfDim 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" CheckSplitHalfDim.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
