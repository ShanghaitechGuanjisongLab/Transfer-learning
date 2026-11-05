@echo off
REM ============================================================================
REM  RunPilot.bat —— 后台跑 Stage 1 pilot，输出写进 ..\_pilot.log
REM
REM  为什么要单独的 .bat：VS Code 的终端输出工具跑长命令会静默卡死。
REM  这里把 stdout/stderr 全重定向到日志文件，再看文件，就能随时知道跑到哪了。
REM  末行是 RUN_DONE（跑完，结论看正文的 PILOT_OK / PILOT_WARN）或 RUN_CRASH（崩了）。
REM
REM  用法：  rslds\RunPilot.bat                  全量（150 轮，约 18 min）
REM          rslds\RunPilot.bat --iters 3        干跑，验证流程
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_pilot.log"
cd /d "%~dp0"
set PYTHONIOENCODING=utf-8
set PYTHONUNBUFFERED=1

echo === RunRSLDS 开始 %DATE% %TIME%  args=[%*] ===	>  "%LOG%"
"%PY%" RunRSLDS.py %* >> "%LOG%" 2>&1
if errorlevel 1 (echo RUN_CRASH >> "%LOG%") else (echo RUN_DONE >> "%LOG%")
