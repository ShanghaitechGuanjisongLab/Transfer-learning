<#PSScriptInfo
.VERSION 1.0.0
.GUID 5308caa4-aa67-47ac-8bf8-1eac24ceeb46
.AUTHOR 埃博拉酱-机器人
.TAGS git github mirror proxy fetch pull 镜像 加速 China
.LICENSEURI https://opensource.org/licenses/MIT
.RELEASENOTES 初始版本。
#>

<#
.SYNOPSIS
    在国内网络环境下，通过多个 GitHub 镜像站点自动尝试 git fetch，根据历史成功率智能排序，优先使用最快镜像，拉取成功后自动快进合并。
.DESCRIPTION
    通过多个 GitHub 镜像站点自动尝试 git fetch，按历史成功率智能排序，实现国内无障碍拉取 GitHub 仓库。本脚本自动检测当前仓库的 origin 远程和当前分支，通过多个镜像代理站点依次尝试 git fetch，并根据历史成功/失败记录智能排序，优先使用成功率最高的镜像。拉取成功后自动执行快进合并（--ff-only）。
.PARAMETER 镜像站前缀
    镜像站地址前缀列表，默认内置 5 个国内常用镜像站。
.EXAMPLE
    .\GitHub镜像拉取.ps1
    从 origin 拉取当前分支，快进合并。
.EXAMPLE
    .\GitHub镜像拉取.ps1 -镜像站前缀 "https://gh.llkk.cc/", "https://gh-proxy.com/"
    仅使用指定的两个镜像站。
#>

param(
    [string[]]$镜像站前缀 = @(
        "https://gh.llkk.cc/",
        "https://gh-proxy.com/",
        "https://ghfast.top/",
        "https://gh-proxy.net/",
        "https://hub.gitmirror.com/"
    )
)

$ErrorActionPreference = "Stop"

function 执行-Git命令 {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$参数
    )

    & git @参数
    if ($LASTEXITCODE -ne 0) {
        throw "git $($参数 -join ' ') 执行失败。"
    }
}

function 尝试-Git命令 {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$参数
    )

    & git @参数
    return $LASTEXITCODE -eq 0
}

function 读取-Git文本 {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$参数
    )

    $输出 = & git @参数
    if ($LASTEXITCODE -ne 0) {
        throw "git $($参数 -join ' ') 执行失败。"
    }

    return ($输出 -join "`n").Trim()
}

function 新建-镜像记录 {
    return [pscustomobject]@{
        版本 = 1
        最后更新 = ""
        镜像 = [pscustomobject]@{}
    }
}

function 确保-对象属性 {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$对象,

        [Parameter(Mandatory = $true)]
        [string]$属性名,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $默认值
    )

    if ($null -eq $对象.PSObject.Properties[$属性名]) {
        $对象 | Add-Member -NotePropertyName $属性名 -NotePropertyValue $默认值
    }
}

function 确保-记录结构 {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$记录
    )

    确保-对象属性 $记录 "版本" 1
    确保-对象属性 $记录 "最后更新" ""
    确保-对象属性 $记录 "镜像" ([pscustomobject]@{})

    if ($null -eq $记录.镜像) {
        $记录.镜像 = [pscustomobject]@{}
    }

    return $记录
}

function 确保-镜像统计结构 {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$统计
    )

    确保-对象属性 $统计 "成功次数" 0
    确保-对象属性 $统计 "失败次数" 0
    确保-对象属性 $统计 "最近结果" ""
    确保-对象属性 $统计 "最近耗时毫秒" $null
    确保-对象属性 $统计 "最后尝试时间" ""
    确保-对象属性 $统计 "最后成功时间" ""
    确保-对象属性 $统计 "最后失败时间" ""

    return $统计
}

function 读取-镜像记录 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$路径
    )

    if (-not (Test-Path -LiteralPath $路径)) {
        return 新建-镜像记录
    }

    $内容 = Get-Content -Raw -LiteralPath $路径
    if ([string]::IsNullOrWhiteSpace($内容)) {
        return 新建-镜像记录
    }

    $记录 = $内容 | ConvertFrom-Json
    return 确保-记录结构 $记录
}

function 保存-镜像记录 {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$记录,

        [Parameter(Mandatory = $true)]
        [string]$路径
    )

    $目录 = Split-Path -Parent $路径
    if (-not [string]::IsNullOrWhiteSpace($目录) -and -not (Test-Path -LiteralPath $目录)) {
        New-Item -ItemType Directory -Path $目录 | Out-Null
    }

    $记录.最后更新 = (Get-Date).ToString("o")
    $记录 | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $路径 -Encoding UTF8
}

function 读取-镜像统计 {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$记录,

        [Parameter(Mandatory = $true)]
        [string]$镜像地址
    )

    $镜像属性 = $记录.镜像.PSObject.Properties[$镜像地址]
    if ($null -eq $镜像属性) {
        $统计 = [pscustomobject]@{}
        $记录.镜像 | Add-Member -NotePropertyName $镜像地址 -NotePropertyValue $统计
        return 确保-镜像统计结构 $统计
    }

    return 确保-镜像统计结构 $镜像属性.Value
}

function 计算-镜像评分 {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$统计
    )

    $成功次数 = [int]$统计.成功次数
    $失败次数 = [int]$统计.失败次数
    $总次数 = $成功次数 + $失败次数

    if ($总次数 -gt 0) {
        $成功率 = [double]$成功次数 / [double]$总次数
    }
    else {
        $成功率 = 0.5
    }

    $最近结果修正 = 0
    if ($统计.最近结果 -eq "成功") {
        $最近结果修正 = 10
    }
    elseif ($统计.最近结果 -eq "失败") {
        $最近结果修正 = -10
    }

    return ($成功率 * 100) + ($成功次数 * 2) - ($失败次数 * 2) + $最近结果修正
}

function 记录-镜像尝试 {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$记录,

        [Parameter(Mandatory = $true)]
        [string]$镜像地址,

        [Parameter(Mandatory = $true)]
        [bool]$成功,

        [Parameter(Mandatory = $true)]
        [int]$耗时毫秒
    )

    $统计 = 读取-镜像统计 $记录 $镜像地址
    $当前时间 = (Get-Date).ToString("o")
    $统计.最后尝试时间 = $当前时间
    $统计.最近耗时毫秒 = $耗时毫秒

    if ($成功) {
        $统计.成功次数 = [int]$统计.成功次数 + 1
        $统计.最近结果 = "成功"
        $统计.最后成功时间 = $当前时间
    }
    else {
        $统计.失败次数 = [int]$统计.失败次数 + 1
        $统计.最近结果 = "失败"
        $统计.最后失败时间 = $当前时间
    }
}

function 转换为-HTTPS仓库地址 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$仓库地址
    )

    if ($仓库地址 -match "^git@github\.com:(.+)$") {
        return "https://github.com/$($Matches[1])"
    }

    if ($仓库地址 -match "^ssh://git@github\.com/(.+)$") {
        return "https://github.com/$($Matches[1])"
    }

    return $仓库地址
}

function 合成-镜像仓库地址 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$镜像站,

        [Parameter(Mandatory = $true)]
        [string]$仓库地址
    )

    return "$($镜像站.TrimEnd('/'))/$仓库地址"
}

$源远程名 = "origin"
$记录文件 = Join-Path (Join-Path $env:USERPROFILE "Temp") "镜像拉取记录.json"

$分支 = 读取-Git文本 @("branch", "--show-current")
if ([string]::IsNullOrWhiteSpace($分支)) {
    throw "当前处于分离 HEAD 状态。"
}

$源仓库地址 = 读取-Git文本 @("remote", "get-url", $源远程名)
$HTTPS仓库地址 = 转换为-HTTPS仓库地址 $源仓库地址
$候选镜像地址 = @()

foreach ($镜像站 in $镜像站前缀) {
    if (-not [string]::IsNullOrWhiteSpace($镜像站)) {
        $候选镜像地址 += 合成-镜像仓库地址 $镜像站 $HTTPS仓库地址
    }
}

$候选镜像地址 = @($候选镜像地址 | Select-Object -Unique)
if ($候选镜像地址.Count -eq 0) {
    throw "没有可用的内置镜像站地址。"
}

$镜像记录 = 读取-镜像记录 $记录文件
$候选镜像条目 = @()
$原始序号 = 0
foreach ($镜像地址 in $候选镜像地址) {
    $统计 = 读取-镜像统计 $镜像记录 $镜像地址
    $评分 = 计算-镜像评分 $统计
    $候选镜像条目 += [pscustomobject]@{
        地址 = $镜像地址
        评分 = $评分
        排序值 = ($评分 * 1000000) - $原始序号
    }

    $原始序号 += 1
}

$候选镜像条目 = @($候选镜像条目 | Sort-Object -Property 排序值 -Descending)

$成功镜像地址 = ""
foreach ($镜像条目 in $候选镜像条目) {
    $镜像地址 = $镜像条目.地址
    $显示评分 = [math]::Round($镜像条目.评分, 2)
    Write-Host "尝试从镜像拉取（评分 $显示评分）：$镜像地址"

    $开始时间 = Get-Date
    $拉取成功 = 尝试-Git命令 @("fetch", $镜像地址, $分支)
    $耗时毫秒 = [int]((Get-Date) - $开始时间).TotalMilliseconds
    记录-镜像尝试 $镜像记录 $镜像地址 $拉取成功 $耗时毫秒
    保存-镜像记录 $镜像记录 $记录文件

    if ($拉取成功) {
        $成功镜像地址 = $镜像地址
        break
    }

    Write-Host "该镜像不可用，继续尝试下一个。"
}

if ([string]::IsNullOrWhiteSpace($成功镜像地址)) {
    throw "所有内置镜像站都未能获取 $分支。"
}

Write-Host "将当前分支快进到镜像中的 $分支..."
执行-Git命令 @("merge", "--ff-only", "FETCH_HEAD")

$最新提交 = 读取-Git文本 @("log", "-1", "--pretty=format:%h %s")
Write-Host "完成。当前最新提交：$最新提交"