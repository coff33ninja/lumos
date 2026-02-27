param(
    [string]$OutputDir = "build/sbom"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$resolvedOutputDir = $OutputDir
if (-not [System.IO.Path]::IsPathRooted($resolvedOutputDir)) {
    $resolvedOutputDir = Join-Path $repoRoot $resolvedOutputDir
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null

$agentDir = Join-Path $repoRoot "lumos-agent"
$appDir = Join-Path $repoRoot "lumos_app"

$goOut = Join-Path $resolvedOutputDir "go-modules.json"
$flutterOut = Join-Path $resolvedOutputDir "flutter-packages.txt"

Push-Location $agentDir
try {
    go list -m -json all | Set-Content -Path $goOut
}
finally {
    Pop-Location
}

Push-Location $appDir
try {
    flutter pub deps > $flutterOut
}
finally {
    Pop-Location
}

Write-Host "SBOM outputs:" -ForegroundColor Green
Write-Host "  - $goOut"
Write-Host "  - $flutterOut"
