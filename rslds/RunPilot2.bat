@echo off
REM ============================================================================
REM  RunPilot2.bat —— 后台跑 Stage 1 pilot 第二轮（置换 null + τ 诊断）
REM  输出写进 ..\_pilot2.log，末行 RUN_DONE / RUN_CRASH。
REM
REM  用法：  rslds\RunPilot2.bat --iters 3       干跑
REM          rslds\RunPilot2.bat                 全量（默认 300 轮，K=2/3）
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_pilot2.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === RunRSLDS2 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" RunRSLDS2.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
