param(
    [Parameter(Mandatory = $true)]
    [string[]]$Artifacts,
    [string]$OutputPath = "build/checksums.txt"
)

$ErrorActionPreference = "Stop"

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$lines = New-Object System.Collections.Generic.List[string]
foreach ($artifact in $Artifacts) {
    if (-not (Test-Path $artifact)) {
        throw "Artifact not found for checksum generation: $artifact"
    }
    $hash = (Get-FileHash -Path $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
    $name = [System.IO.Path]::GetFileName($artifact)
    $lines.Add("$hash  $name")
}

Set-Content -Path $OutputPath -Value ($lines -join "`r`n")
Write-Host "Wrote checksums: $OutputPath" -ForegroundColor Green
