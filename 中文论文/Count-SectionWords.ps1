[CmdletBinding()]
param([string]$FilePath)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
function Resolve-DefaultManuscriptPath {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $candidates = @(Get-ChildItem -LiteralPath $scriptDir -Filter '*v5.md' -File)
    if ($candidates.Count -eq 0) { throw "No '*v5.md' manuscript was found" }
    return $candidates[0].FullName
}
function Get-NumberedSectionText {
    param([string]$Text, [string]$StartNumber, [string]$EndNumber)
    $escapedStart = [regex]::Escape($StartNumber)
    $escapedEnd = [regex]::Escape($EndNumber)
    $pattern = "(?ms)^\s*##\s+$escapedStart\b.*?(?=^\s*##\s+$escapedEnd\b|\z)"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { throw "Cannot find $StartNumber before $EndNumber" }
    return $match.Value
}
if ([string]::IsNullOrWhiteSpace($FilePath)) { $FilePath = Resolve-DefaultManuscriptPath }
$resolvedPath = (Resolve-Path -LiteralPath $FilePath).ProviderPath
$manuscript = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8
$s11 = Get-NumberedSectionText -Text $manuscript -StartNumber '1.1' -EndNumber '1.2'
$s12 = Get-NumberedSectionText -Text $manuscript -StartNumber '1.2' -EndNumber '1.3'
$s13 = Get-NumberedSectionText -Text $manuscript -StartNumber '1.3' -EndNumber '1.4'
$s14 = Get-NumberedSectionText -Text $manuscript -StartNumber '1.4' -EndNumber '1.5'
Write-Output ($s11.Length + $s12.Length + $s13.Length + $s14.Length)
