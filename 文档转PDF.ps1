<#
.SYNOPSIS
    将 Markdown 文件转换为 PDF（支持中文、数学公式、表格、Mermaid 流程图）
.DESCRIPTION
    使用 Pandoc 生成 HTML（MathML 渲染数学），mmdc 预渲染 Mermaid 流程图，
    再用 Edge headless 打印为 PDF。缺失依赖时自动安装。
.PARAMETER 路径
    要转换的 Markdown 文件路径。默认为当前目录下的 *.md。
.PARAMETER 输出目录
    PDF 输出目录。默认与源文件同目录。
.EXAMPLE
    .\文档转PDF.ps1 -路径 "响应异质性与学习速度_模型综述.md"
    .\文档转PDF.ps1 -路径 *.md -输出目录 D:\Output
#>
param(
    [Parameter(Position = 0)]
    [string[]]$路径,

    [string]$输出目录
)

$ErrorActionPreference = 'Stop'

# ── 检查并自动安装依赖 ────────────────────────────────────

# Pandoc
$Pandoc命令 = Get-Command pandoc -ErrorAction SilentlyContinue
if (-not $Pandoc命令) {
    Write-Host "未找到 pandoc，正在通过 winget 安装 ..." -ForegroundColor Yellow
    winget install --id JohnMacFarlane.Pandoc --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Error "自动安装 pandoc 失败。请手动安装: https://pandoc.org/installing.html"
        return
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $Pandoc命令 = Get-Command pandoc -ErrorAction SilentlyContinue
    if (-not $Pandoc命令) {
        Write-Error "pandoc 已安装但未在 PATH 中找到，请重启终端后重试。"
        return
    }
    Write-Host "pandoc 安装成功: $(pandoc --version | Select-Object -First 1)" -ForegroundColor Green
}

# Node.js / npm / npx
$Npx命令 = Get-Command npx -ErrorAction SilentlyContinue
if (-not $Npx命令) {
    Write-Host "未找到 Node.js (npx)，正在通过 winget 安装 ..." -ForegroundColor Yellow
    winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Error "自动安装 Node.js 失败。请手动安装: https://nodejs.org/"
        return
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $Npx命令 = Get-Command npx -ErrorAction SilentlyContinue
    if (-not $Npx命令) {
        Write-Error "Node.js 已安装但 npx 未在 PATH 中找到，请重启终端后重试。"
        return
    }
    Write-Host "Node.js 安装成功: $(node --version)" -ForegroundColor Green
}

# mermaid-cli (mmdc)
$Mmdc命令 = Get-Command mmdc -ErrorAction SilentlyContinue
if (-not $Mmdc命令) {
    Write-Host "未找到 mermaid-cli (mmdc)，正在全局安装 ..." -ForegroundColor Yellow
    $原错误策略 = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & npm install -g @mermaid-js/mermaid-cli 2>&1 | Where-Object { $_ -notmatch 'warn' } | Write-Host
    $ErrorActionPreference = $原错误策略
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $Mmdc命令 = Get-Command mmdc -ErrorAction SilentlyContinue
    if (-not $Mmdc命令) {
        Write-Host "全局安装 mmdc 未成功，将回退使用 npx 调用。" -ForegroundColor Yellow
    } else {
        Write-Host "mermaid-cli 安装成功: $(mmdc --version)" -ForegroundColor Green
    }
}

# Edge 浏览器
$Edge路径列表 = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)
$Edge路径 = $Edge路径列表 | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Edge路径) {
    Write-Error "未找到 Microsoft Edge。Edge 为 Windows 内置组件，无法自动安装。"
    return
}

# ── 解析输入文件 ──────────────────────────────────────────
if (-not $路径) {
    $路径 = @("*.md")
}
$文件列表 = @()
foreach ($路径项 in $路径) {
    $文件列表 += Get-Item $路径项 -ErrorAction SilentlyContinue
}
if ($文件列表.Count -eq 0) {
    Write-Error "未找到匹配的 Markdown 文件。"
    return
}

# ── 网页头尾（手动拼接，避免 Pandoc 模板转义问题） ────
$网页头部 = @'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8"/>
<style>
  @page { size: A4; margin: 20mm 18mm; }
  body {
    font-family: "Microsoft YaHei", "SimSun", "Noto Sans CJK SC", sans-serif;
    font-size: 11pt;
    line-height: 1.6;
    color: #222;
    max-width: 100%;
  }
  h1 { font-size: 18pt; margin-top: 1em; }
  h2 { font-size: 15pt; margin-top: 0.8em; }
  h3 { font-size: 13pt; margin-top: 0.6em; }
  table { border-collapse: collapse; width: 100%; margin: 0.6em 0; font-size: 10pt; }
  th, td { border: 1px solid #999; padding: 4px 8px; text-align: left; }
  th { background: #f0f0f0; }
  code { font-family: Consolas, "Courier New", monospace; font-size: 10pt; background: #f5f5f5; padding: 1px 4px; border-radius: 3px; }
  pre { background: #f5f5f5; padding: 10px; border-radius: 4px; overflow-x: auto; font-size: 9.5pt; }
  pre code { background: none; padding: 0; }
  blockquote { border-left: 3px solid #ccc; margin-left: 0; padding-left: 1em; color: #555; }
  img { max-width: 100%; }
  math { font-size: 1.05em; }
</style>
</head>
<body>
'@

$网页尾部 = @'
</body>
</html>
'@

# ── 逐文件转换 ────────────────────────────────────────────
foreach ($文件 in $文件列表) {
    $文件名 = [System.IO.Path]::GetFileNameWithoutExtension($文件.Name)
    $源目录 = $文件.DirectoryName
    $目标目录 = if ($输出目录) { $已解析 = Resolve-Path $输出目录 -ErrorAction SilentlyContinue; if ($已解析) { $已解析.Path } else { $输出目录 } } else { $源目录 }
    if (-not (Test-Path $目标目录)) { New-Item -ItemType Directory -Path $目标目录 -Force | Out-Null }

    $临时网页 = Join-Path $env:TEMP "文档转PDF_$PID`_$文件名.html"
    $PDF路径 = Join-Path $目标目录 "$文件名.pdf"

    try {
        # Pandoc: Markdown → HTML 片段
        Write-Host "[1/2] 转换 $($文件.Name) → HTML ..." -ForegroundColor Cyan
        $临时片段 = Join-Path $env:TEMP "文档转PDF_片段_$PID`_$文件名.html"
        & pandoc $文件.FullName `
            --from markdown+tex_math_dollars+pipe_tables+fenced_code_blocks `
            --to html5 `
            --mathml `
            --syntax-highlighting=none `
            -o $临时片段
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Pandoc 转换失败: $($文件.Name)"
            continue
        }

        # 拼接完整网页
        $正文内容 = [System.IO.File]::ReadAllText($临时片段, [System.Text.Encoding]::UTF8)

        # 预渲染 Mermaid 代码块为内联 SVG
        $流程图正则 = [regex]'<pre class="mermaid"><code>([\s\S]*?)</code></pre>'
        $流程图计数 = 0
        $正文内容 = $流程图正则.Replace($正文内容, {
            param($匹配)
            $流程图计数++
            $流程图源码 = [System.Net.WebUtility]::HtmlDecode($匹配.Groups[1].Value)
            $流程图输入 = Join-Path $env:TEMP "文档转PDF_图_$PID`_$流程图计数.mmd"
            $流程图输出 = Join-Path $env:TEMP "文档转PDF_图_$PID`_$流程图计数.svg"
            [System.IO.File]::WriteAllText($流程图输入, $流程图源码, [System.Text.Encoding]::UTF8)
            $流程图命令 = Get-Command mmdc -ErrorAction SilentlyContinue
            $原错误策略2 = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            if ($流程图命令) {
                & mmdc -i $流程图输入 -o $流程图输出 -b transparent --quiet 2>$null
            } else {
                & npx --yes @mermaid-js/mermaid-cli -i $流程图输入 -o $流程图输出 -b transparent --quiet 2>$null
            }
            $ErrorActionPreference = $原错误策略2
            if (Test-Path $流程图输出) {
                $矢量图 = [System.IO.File]::ReadAllText($流程图输出, [System.Text.Encoding]::UTF8)
                Remove-Item $流程图输入, $流程图输出 -ErrorAction SilentlyContinue
                return "<div style=`"text-align:center;margin:1em 0`">$矢量图</div>"
            } else {
                Remove-Item $流程图输入 -ErrorAction SilentlyContinue
                return $匹配.Value
            }
        })

        $完整网页 = $网页头部 + "`n" + $正文内容 + "`n" + $网页尾部
        [System.IO.File]::WriteAllText($临时网页, $完整网页, [System.Text.Encoding]::UTF8)

        # Edge headless: HTML → PDF
        Write-Host "[2/2] 打印 PDF → $PDF路径 ..." -ForegroundColor Cyan
        $Edge参数 = @(
            "--headless",
            "--disable-gpu",
            "--no-sandbox",
            "--run-all-compositor-stages-before-draw",
            "--virtual-time-budget=10000",
            "--print-to-pdf=$PDF路径",
            "--print-to-pdf-no-header",
            $临时网页
        )
        $进程 = Start-Process -FilePath $Edge路径 -ArgumentList $Edge参数 -Wait -PassThru -WindowStyle Hidden -RedirectStandardError (Join-Path $env:TEMP "文档转PDF_Edge日志.log")
        if ($进程.ExitCode -ne 0) {
            Write-Warning "Edge 退出码 $($进程.ExitCode)，PDF 可能不完整。"
        }

        if (Test-Path $PDF路径) {
            $大小 = (Get-Item $PDF路径).Length / 1KB
            Write-Host "完成: $PDF路径 ($([math]::Round($大小, 1)) KB)" -ForegroundColor Green
        } else {
            Write-Error "PDF 生成失败: $PDF路径"
        }
    }
    finally {
        Remove-Item $临时片段 -ErrorAction SilentlyContinue
        Remove-Item $临时网页 -ErrorAction SilentlyContinue
    }
}
