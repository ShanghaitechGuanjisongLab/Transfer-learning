param(
	[Parameter(Mandatory = $true, Position = 0)]
	[string]$TeX字符串,

	[Parameter(Mandatory = $true, Position = 1)]
	[string]$SVG文件路径,

	[Parameter(Position = 2)]
	[string]$字号 = '',

	[switch]$行内公式,

	[switch]$跳过依赖安装
)

$错误动作偏好_原值 = $ErrorActionPreference
$ErrorActionPreference = 'Stop'

function Get-仓库根目录 {
	$当前目录 = Split-Path -Parent $PSCommandPath
	while ($当前目录) {
		$包含项目文件 = (Test-Path (Join-Path $当前目录 'Transferlearning.prj')) -or (Test-Path (Join-Path $当前目录 '+TransferLearning'))
		if ($包含项目文件) {
			return (Resolve-Path $当前目录).Path
		}
		$父目录 = Split-Path -Parent $当前目录
		if ([string]::IsNullOrEmpty($父目录) -or $父目录 -eq $当前目录) {
			break
		}
		$当前目录 = $父目录
	}
	return (Resolve-Path (Split-Path -Parent $PSCommandPath)).Path
}

function Get-节点命令路径 {
	$节点命令 = Get-Command node -ErrorAction SilentlyContinue
	if (-not $节点命令) {
		throw '未找到 node。请先安装 Node.js，或确认 node 已加入 PATH。'
	}
	return $节点命令.Source
}

function Get-依赖目录([string]$仓库根目录) {
	return (Join-Path $仓库根目录 'Temp\formula-svg-tools')
}

function Install-MathJax依赖([string]$依赖目录, [switch]$跳过安装) {
	$MathJax入口 = Join-Path $依赖目录 'node_modules\mathjax-full\js\mathjax.js'
	if (Test-Path $MathJax入口) {
		return
	}
	if ($跳过安装) {
		throw "未找到 MathJax 依赖：$MathJax入口"
	}
	$Npm命令 = Get-Command npm -ErrorAction SilentlyContinue
	if (-not $Npm命令) {
		throw '未找到 npm，无法自动安装 MathJax 依赖。'
	}
	$安装日志 = Join-Path (Split-Path -Parent $依赖目录) 'tex_formula_svg_npm_install.log'
	& $Npm命令.Source install --prefix $依赖目录 mathjax-full *> $安装日志
	if (-not (Test-Path $MathJax入口)) {
		throw "MathJax 安装后仍未找到入口文件。安装日志：$安装日志"
	}
}

function Set-渲染配置([string]$TeX字符串, [string]$SVG文件路径, [string]$字号, [bool]$是否行内, [string]$临时目录) {
	$渲染配置路径 = Join-Path $临时目录 'tex公式渲染配置.json'
	$渲染配置 = [ordered]@{
		TeX字符串 = $TeX字符串
		SVG文件路径 = $SVG文件路径
		字号 = $字号
		是否行内 = $是否行内
	}
	$渲染配置 | ConvertTo-Json -Depth 4 | Set-Content -Path $渲染配置路径 -Encoding UTF8
	return $渲染配置路径
}

function Set-节点渲染脚本([string]$临时目录) {
	$节点脚本路径 = Join-Path $临时目录 'tex公式渲染为svg.cjs'
	$节点脚本内容 = @'
const 文件系统 = require('fs');
const 路径 = require('path');

function 读取模块(模块相对路径) {
  const 仓库根目录 = process.cwd();
  const 候选路径 = [
    路径.join(仓库根目录, 'node_modules', 模块相对路径),
    路径.join(仓库根目录, 'Temp', 'formula-svg-tools', 'node_modules', 模块相对路径),
    模块相对路径,
  ];
  const 错误列表 = [];
  for (const 候选 of 候选路径) {
    try {
      return require(候选);
    } catch (错误) {
      错误列表.push(`${候选}: ${错误.message}`);
    }
  }
  throw new Error(`无法载入 ${模块相对路径}\n${错误列表.join('\n')}`);
}

function 取出SVG标记(渲染标记) {
  const 清理后标记 = 渲染标记.trim();
  if (清理后标记.startsWith('<svg')) {
    return 清理后标记;
  }
  const SVG匹配 = 清理后标记.match(/<svg[\s\S]*<\/svg>/);
  if (!SVG匹配) {
    throw new Error('MathJax 输出中没有 SVG 元素。');
  }
  return SVG匹配[0];
}

function 解析字号为pt(字号) {
	if (字号 === undefined || 字号 === null || String(字号).trim() === '') {
		return null;
	}
	const 字号文本 = String(字号).trim();
	const 匹配 = 字号文本.match(/^([0-9]*\.?[0-9]+)\s*(pt)?$/i);
	if (!匹配) {
		throw new Error(`字号只支持 pt 或不写单位的数字，例如 6pt 或 6。当前值：${字号文本}`);
	}
	const 字号pt = Number(匹配[1]);
	if (!Number.isFinite(字号pt) || 字号pt <= 0) {
		throw new Error(`字号必须是正数。当前值：${字号文本}`);
	}
	return 字号pt;
}

function 应用字号(SVG标记, 字号) {
	const 字号pt = 解析字号为pt(字号);
	if (字号pt === null) {
		return SVG标记;
	}
	const 视窗匹配 = SVG标记.match(/viewBox="([^"]+)"/);
	if (!视窗匹配) {
		throw new Error('SVG 中没有 viewBox，无法按字号换算尺寸。');
	}
	const 视窗数值 = 视窗匹配[1].trim().split(/\s+/).map(Number);
	if (视窗数值.length !== 4 || 视窗数值.some((值) => !Number.isFinite(值))) {
		throw new Error(`无法解析 SVG viewBox：${视窗匹配[1]}`);
	}
	const 宽度pt = 视窗数值[2] / 1000 * 字号pt;
	const 高度pt = 视窗数值[3] / 1000 * 字号pt;
	const 字号样式 = `font-size: ${字号pt}pt;`;
	let 输出标记 = SVG标记.replace(/\swidth="[^"]*"/, ` width="${宽度pt.toFixed(4)}pt"`);
	输出标记 = 输出标记.replace(/\sheight="[^"]*"/, ` height="${高度pt.toFixed(4)}pt"`);
	输出标记 = 输出标记.replace(/<svg\s/, `<svg data-tex-font-size="${字号pt}pt" `);
	if (/style="[^"]*"/.test(输出标记)) {
		输出标记 = 输出标记.replace(/style="([^"]*)"/, (全部, 原样式) => `style="${字号样式} ${原样式}"`);
	} else {
		输出标记 = 输出标记.replace(/<svg\s/, `<svg style="${字号样式}" `);
	}
	return 输出标记;
}

const 渲染配置路径 = process.argv[2];
if (!渲染配置路径) {
  throw new Error('缺少渲染配置路径。');
}

const 渲染配置文本 = 文件系统.readFileSync(渲染配置路径, 'utf8').replace(/^\uFEFF/, '');
const 渲染配置 = JSON.parse(渲染配置文本);
const { mathjax: 数学渲染器 } = 读取模块('mathjax-full/js/mathjax.js');
const { TeX: TeX输入器 } = 读取模块('mathjax-full/js/input/tex.js');
const { SVG: SVG输出器 } = 读取模块('mathjax-full/js/output/svg.js');
const { liteAdaptor: 轻量适配器 } = 读取模块('mathjax-full/js/adaptors/liteAdaptor.js');
const { RegisterHTMLHandler: 注册HTML处理器 } = 读取模块('mathjax-full/js/handlers/html.js');
const { AllPackages: 全部宏包 } = 读取模块('mathjax-full/js/input/tex/AllPackages.js');

const 适配器 = 轻量适配器();
注册HTML处理器(适配器);
const TeX输入 = new TeX输入器({ packages: 全部宏包 });
const SVG输出 = new SVG输出器({ fontCache: 'none' });
const 空文档 = 数学渲染器.document('', { InputJax: TeX输入, OutputJax: SVG输出 });
const 节点 = 空文档.convert(渲染配置.TeX字符串, { display: !渲染配置.是否行内 });
const SVG标记 = 应用字号(取出SVG标记(适配器.innerHTML(节点)), 渲染配置.字号);
const SVG文本 = `<?xml version="1.0" encoding="UTF-8"?>\n${SVG标记}\n`;

文件系统.mkdirSync(路径.dirname(渲染配置.SVG文件路径), { recursive: true });
文件系统.writeFileSync(渲染配置.SVG文件路径, SVG文本, 'utf8');
'@
	Set-Content -Path $节点脚本路径 -Value $节点脚本内容 -Encoding UTF8
	return $节点脚本路径
}

function Test-文件名合法性([string]$文件名) {
	$非法字符 = [System.IO.Path]::GetInvalidFileNameChars()
	if ($文件名.IndexOfAny($非法字符) -ge 0) {
		throw [System.ArgumentException]::new("TeX 字符串不能作为文件名：$文件名")
	}
}

function Resolve-输出文件路径([string]$输入路径, [string]$TeX字符串, [string]$仓库根目录) {
	$候选路径 = $输入路径
	if (-not [System.IO.Path]::IsPathRooted($候选路径)) {
		$候选路径 = Join-Path $仓库根目录 $候选路径
	}
	$候选路径 = [System.IO.Path]::GetFullPath($候选路径)
	if (Test-Path -LiteralPath $候选路径 -PathType Container) {
		$输出文件名 = "$TeX字符串.svg"
		Test-文件名合法性 $输出文件名
		$候选路径 = Join-Path $候选路径 $输出文件名
	}
	return [System.IO.Path]::GetFullPath($候选路径)
}

try {
	$仓库根目录 = Get-仓库根目录
	$节点命令路径 = Get-节点命令路径
	$依赖目录 = Get-依赖目录 $仓库根目录
	Install-MathJax依赖 $依赖目录 $跳过依赖安装

	$临时目录 = Join-Path $仓库根目录 'Temp\tex-formula-svg'
	if (-not (Test-Path $临时目录)) {
		New-Item -ItemType Directory -Path $临时目录 | Out-Null
	}

	$输出文件路径 = Resolve-输出文件路径 $SVG文件路径 $TeX字符串 $仓库根目录

	$渲染配置路径 = Set-渲染配置 $TeX字符串 $输出文件路径 $字号 ([bool]$行内公式) $临时目录
	$节点脚本路径 = Set-节点渲染脚本 $临时目录

	Push-Location $仓库根目录
	try {
		& $节点命令路径 $节点脚本路径 $渲染配置路径
	} finally {
		Pop-Location
	}

	Write-Output "已写出：$输出文件路径"
} finally {
	$ErrorActionPreference = $错误动作偏好_原值
}