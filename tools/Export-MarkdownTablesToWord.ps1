param(
    [string]$SourcePath = "盲审/文稿.md",
    [string]$OutputDir = "盲审/表格导出",
    [string]$OutputFileName = "文稿_全部表格.docx"
)

$ErrorActionPreference = 'Stop'

function Test-TableLine {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }

    return $Line.Contains('|')
}

function Test-SeparatorLine {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }

    return $Line -match '^[\s\|:\-]+$'
}

function Get-SafeFileName {
    param([string]$Name)

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $safeName = $Name
    foreach ($char in $invalidChars) {
        $safeName = $safeName.Replace([string]$char, '_')
    }

    return $safeName.Trim().TrimEnd('.')
}

$workspace = (Get-Location).Path
$sourceFullPath = Join-Path $workspace $SourcePath
$outputFullDir = Join-Path $workspace $OutputDir

if (-not (Test-Path $sourceFullPath)) {
    throw "Source file not found: $sourceFullPath"
}

New-Item -ItemType Directory -Path $outputFullDir -Force | Out-Null

$lines = Get-Content -Path $sourceFullPath -Encoding UTF8
$tables = [System.Collections.Generic.List[object]]::new()

for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = $lines[$index].Trim()
    if ($line -notmatch '^表\s*[0-9A-Za-z\.-]+') {
        continue
    }

    $titleCn = $lines[$index].Trim()
    $titleEn = $null
    $searchIndex = $index + 1

    while ($searchIndex -lt $lines.Count -and [string]::IsNullOrWhiteSpace($lines[$searchIndex])) {
        $searchIndex++
    }

    if ($searchIndex -lt $lines.Count -and $lines[$searchIndex].Trim() -match '^Table\s+') {
        $titleEn = $lines[$searchIndex].Trim()
        $searchIndex++
    }

    while ($searchIndex -lt $lines.Count -and [string]::IsNullOrWhiteSpace($lines[$searchIndex])) {
        $searchIndex++
    }

    $tableStart = $searchIndex
    $tableLines = [System.Collections.Generic.List[string]]::new()

    while ($searchIndex -lt $lines.Count -and (Test-TableLine $lines[$searchIndex])) {
        $tableLines.Add($lines[$searchIndex])
        $searchIndex++
    }

    if ($tableLines.Count -lt 2) {
        continue
    }

    if (-not (Test-SeparatorLine $tableLines[1])) {
        continue
    }

    $tables.Add([pscustomobject]@{
        TitleCn = $titleCn
        TitleEn = $titleEn
        StartLine = $index + 1
        EndLine = $searchIndex
        TableLines = @($tableLines)
    })

    $index = $searchIndex - 1
}

if ($tables.Count -eq 0) {
    throw 'No markdown tables were detected.'
}

$combinedMdPath = Join-Path $outputFullDir '文稿_全部表格.__tmp__.md'
$combinedDocxPath = Join-Path $outputFullDir $OutputFileName
$combinedSections = [System.Collections.Generic.List[string]]::new()

foreach ($table in $tables) {
    $combinedSections.Add('# ' + $table.TitleCn)
    $combinedSections.Add('')
    if ($table.TitleEn) {
        $combinedSections.Add($table.TitleEn)
        $combinedSections.Add('')
    }
    foreach ($tableLine in $table.TableLines) {
        $combinedSections.Add($tableLine)
    }
    $combinedSections.Add('')
    $combinedSections.Add('\newpage')
    $combinedSections.Add('')
}

Set-Content -Path $combinedMdPath -Value $combinedSections -Encoding UTF8
& pandoc $combinedMdPath -f gfm -t docx -o $combinedDocxPath

Remove-Item -Path $combinedMdPath -Force

Get-ChildItem -Path $outputFullDir | Select-Object Name, Length, LastWriteTime