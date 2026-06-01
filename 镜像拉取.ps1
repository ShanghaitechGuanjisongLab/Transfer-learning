param(
    [string]$源远程名 = "origin",
    [string]$分支 = "",
    [string[]]$镜像站前缀 = @(
        "https://gh.llkk.cc/",
        "https://gh-proxy.com/",
        "https://ghfast.top/",
        "https://gh-proxy.net/",
        "https://hub.gitmirror.com/"
    ),
    [string[]]$额外镜像地址 = @(),
    [switch]$仅获取,
    [switch]$变基
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

执行-Git命令 @("rev-parse", "--is-inside-work-tree") | Out-Null

if ([string]::IsNullOrWhiteSpace($分支)) {
    $分支 = 读取-Git文本 @("branch", "--show-current")
}

if ([string]::IsNullOrWhiteSpace($分支)) {
    throw "当前处于分离 HEAD 状态，请用 -分支 指定要拉取的分支。"
}

$源仓库地址 = 读取-Git文本 @("remote", "get-url", $源远程名)
$HTTPS仓库地址 = 转换为-HTTPS仓库地址 $源仓库地址
$候选镜像地址 = @()
$候选镜像地址 += $额外镜像地址 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

foreach ($镜像站 in $镜像站前缀) {
    if (-not [string]::IsNullOrWhiteSpace($镜像站)) {
        $候选镜像地址 += 合成-镜像仓库地址 $镜像站 $HTTPS仓库地址
    }
}

$候选镜像地址 = @($候选镜像地址 | Select-Object -Unique)
if ($候选镜像地址.Count -eq 0) {
    throw "没有可用的内置镜像站地址。"
}

$成功镜像地址 = ""
foreach ($镜像地址 in $候选镜像地址) {
    Write-Host "尝试从镜像拉取：$镜像地址"
    if (尝试-Git命令 @("fetch", $镜像地址, $分支)) {
        $成功镜像地址 = $镜像地址
        break
    }

    Write-Host "该镜像不可用，继续尝试下一个。"
}

if ([string]::IsNullOrWhiteSpace($成功镜像地址)) {
    throw "所有内置镜像站都未能获取 $分支。"
}

if ($仅获取) {
    Write-Host "已从镜像获取 $分支：$成功镜像地址"
    exit 0
}

if ($变基) {
    Write-Host "将当前分支变基到镜像中的 $分支..."
    执行-Git命令 @("rebase", "FETCH_HEAD")
}
else {
    Write-Host "将当前分支快进到镜像中的 $分支..."
    执行-Git命令 @("merge", "--ff-only", "FETCH_HEAD")
}

$最新提交 = 读取-Git文本 @("log", "-1", "--pretty=format:%h %s")
Write-Host "完成。当前最新提交：$最新提交"