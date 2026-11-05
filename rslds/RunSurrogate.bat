@echo off
REM ============================================================================
REM  RunSurrogate.bat —— B：逐鼠配对替代数据，输出写进 ..\_sur.log
REM  末行 RUN_DONE / RUN_CRASH。
REM
REM  用法：  rslds\RunSurrogate.bat --only 2     先跑 2 只鼠验证
REM          rslds\RunSurrogate.bat              11 只鼠全跑（约 2 h）
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_sur.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === RunSurrogatePaired 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" RunSurrogatePaired.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
