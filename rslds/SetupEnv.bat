@echo off
REM ============================================================================
REM  SetupEnv.bat —— 在 rslds\.venv 里装齐 rSLDS 需要的 Python 依赖
REM
REM  为什么用清华镜像：直连 PyPI 下 scipy（39 MiB）会卡十几分钟，镜像几秒。
REM  为什么要单独的 .bat：VS Code 的终端输出工具不可靠，把结果写进日志文件再读。
REM
REM  用法（在仓库根目录）：  rslds\SetupEnv.bat
REM  结果：  _pipenv.log 末行是 INSTALL_OK 或 INSTALL_FAIL
REM ============================================================================
setlocal
set "PY=%~dp0.venv\Scripts\python.exe"
set "LOG=%~dp0..\_pipenv.log"

if not exist "%PY%" (
	echo [ERROR] 找不到 venv：%PY%
	echo [ERROR] 找不到 venv：%PY% > "%LOG%"
	exit /b 1
)

echo === SetupEnv 开始 %DATE% %TIME% ===				>  "%LOG%"
echo python = %PY%									>> "%LOG%"

uv pip install --python "%PY%" ^
	--default-index https://pypi.tuna.tsinghua.edu.cn/simple ^
	"numpy<2" scipy matplotlib scikit-learn tqdm autograd cython wheel setuptools h5py ^
	>> "%LOG%" 2>&1
if errorlevel 1 (
	echo INSTALL_FAIL >> "%LOG%"
	exit /b 1
)

"%PY%" -c "import sys,numpy,scipy,sklearn,cython,h5py;print('python',sys.version.split()[0]);print('numpy',numpy.__version__);print('scipy',scipy.__version__);print('sklearn',sklearn.__version__);print('cython',cython.__version__);print('h5py',h5py.__version__)" >> "%LOG%" 2>&1

echo INSTALL_OK >> "%LOG%"
exit /b 0
