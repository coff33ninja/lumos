param(
    [string]$FromTag = "",
    [string]$ToRef = "HEAD",
    [switch]$ShowStats
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$changelogScript = Join-Path $repoRoot "scripts\generate-changelog.ps1"
if (-not (Test-Path $changelogScript)) {
    throw "Changelog generator not found: $changelogScript"
}

# Auto-detect last tag if not provided
if ([string]::IsNullOrWhiteSpace($FromTag)) {
    Write-Host "Auto-detecting last release tag..." -ForegroundColor Cyan
    $FromTag = (git describe --tags --abbrev=0 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($FromTag)) {
        $FromTag = (git rev-list --max-parents=0 HEAD).Trim()
        Write-Host "No tags found. Using first commit: $FromTag" -ForegroundColor Yellow
    } else {
        Write-Host "Last release tag: $FromTag" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Changelog Preview ===" -ForegroundColor Cyan
Write-Host "From: $FromTag" -ForegroundColor White
Write-Host "To:   $ToRef" -ForegroundColor White
Write-Host ""

& $changelogScript -FromTag $FromTag -ToRef $ToRef -MarkdownFormat -GroupByType

if ($ShowStats) {
    Write-Host ""
    Write-Host "=== Commit Statistics ===" -ForegroundColor Cyan
    
    $commitCount = (git rev-list "$FromTag..$ToRef" --count).Trim()
    $authorCount = (git log "$FromTag..$ToRef" --format="%an" | Sort-Object -Unique | Measure-Object).Count
    $fileCount = (git diff --name-only "$FromTag..$ToRef" | Measure-Object).Count
    
    Write-Host "Total commits:  $commitCount" -ForegroundColor White
    Write-Host "Contributors:   $authorCount" -ForegroundColor White
    Write-Host "Files changed:  $fileCount" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Top contributors:" -ForegroundColor Cyan
    git shortlog -sn "$FromTag..$ToRef" | Select-Object -First 5
}

Write-Host ""
Write-Host "This changelog will be automatically included in the next release." -ForegroundColor Green
