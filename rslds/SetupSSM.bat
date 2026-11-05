@echo off
REM ============================================================================
REM  SetupSSM.bat —— 装 numba/seaborn，并从源码编译 ssm（含 C++ 扩展 ssm.cstats）
REM
REM  为什么要编译：`ssm` 的 `cstats.pyx` 是 C++ 扩展（快速消息传递与梯度），PyPI
REM  上没有可用的 Windows 轮子，必须用 MSVC 现场编译。
REM  为什么用 vcvars64.bat 而不是 VsDevCmd.bat：后者在本机（VS 2026 Community）被 call
REM  之后进程会静默终止，日志里一点痕迹都没有；vcvars64.bat 是传统入口，稳。
REM  为什么不带 OpenMP：`setup.py` 在 USE_OPENMP 时写死 `-fopenmp`，那是 GCC 参数，MSVC
REM  不认，会直接编译失败。本机 6 核，先拿到可用的单线程版本。
REM
REM  用法（仓库根目录）：  rslds\SetupSSM.bat
REM  结果：  _ssmbuild.log 末行是 SSM_OK 或 SSM_FAIL
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_ssmbuild.log"
set "SSMSRC=%~dp0third_party\ssm"
set "MIRROR=https://pypi.tuna.tsinghua.edu.cn/simple"

echo === SetupSSM 开始 %DATE% %TIME% ===	>  "%LOG%"

REM ---- 1. ssm 运行期还缺的纯 Python 依赖（seaborn 只给官方示例画图用）----
echo MARK_DEPS >> "%LOG%"
uv pip install --python "%PY%" --default-index %MIRROR% numba seaborn >> "%LOG%" 2>&1
if errorlevel 1 (echo DEPS_FAIL >> "%LOG%" & exit /b 1)
echo MARK_DEPS_DONE >> "%LOG%"

REM ---- 2. 手动设置 MSVC 编译环境 ----
REM   为什么不用 vcvars64.bat：本机（VS 2026 Community）call 它之后父批处理会被一起终止，
REM   日志里连一行后续输出都没有。手动设 PATH/INCLUDE/LIB 行为完全确定。
REM   ⚠ 为什么必须设 DISTUTILS_USE_SDK：Python 的 distutils 用 `vswhere -version ^(15|16|17)\.`
REM   找 VS，而本机 VS 2026 报的是 18.x —— 于是它认为"没有编译器"直接报错。设了
REM   DISTUTILS_USE_SDK=1 它就跳过自己那套探测，直接采用当前环境。
echo MARK_VCVARS >> "%LOG%"
set "MSVC=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.52.36815"
set "SDK=C:\Program Files (x86)\Windows Kits\10"
set "SDKVER=10.0.26100.0"
set "PATH=%MSVC%\bin\Hostx64\x64;%SDK%\bin\%SDKVER%\x64;%PATH%"
set "INCLUDE=%MSVC%\include;%SDK%\Include\%SDKVER%\ucrt;%SDK%\Include\%SDKVER%\um;%SDK%\Include\%SDKVER%\shared;%SDK%\Include\%SDKVER%\winrt;%SDK%\Include\%SDKVER%\cppwinrt"
set "LIB=%MSVC%\lib\x64;%SDK%\Lib\%SDKVER%\ucrt\x64;%SDK%\Lib\%SDKVER%\um\x64"
set "DISTUTILS_USE_SDK=1"
set "MSSdk=1"
where cl >> "%LOG%" 2>&1
echo MARK_VCVARS_DONE >> "%LOG%"

REM ---- 3. 编译并就地安装 ssm ----
REM   --no-build-isolation : 复用 venv 里的 numpy/cython/setuptools，避免另建隔离环境
REM   --no-deps            : 依赖已单独装过，别让 uv 再去解析一遍
echo MARK_BUILD >> "%LOG%"
uv pip install --python "%PY%" -e "%SSMSRC%" --no-build-isolation --no-deps --default-index %MIRROR% >> "%LOG%" 2>&1
if errorlevel 1 (echo SSM_FAIL >> "%LOG%" & exit /b 1)
echo MARK_BUILD_DONE >> "%LOG%"

REM ---- 4. 自检 ----
"%PY%" -c "import ssm, numpy; print('ssm from', ssm.__file__); m=ssm.SLDS(4, 2, 2, transitions='recurrent_only'); print('SLDS(recurrent_only) OK', type(m).__name__)" >> "%LOG%" 2>&1
if errorlevel 1 (echo SMOKE_FAIL >> "%LOG%" & exit /b 1)

echo SSM_OK >> "%LOG%"
exit /b 0
