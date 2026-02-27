param(
    [string]$Repo = "",
    [string]$Tag = "",
    [switch]$IncludeMetadata,
    [switch]$UseApiBrowserDownload,
    [switch]$SkipChecksumValidation,
    [switch]$SkipSignatureVerification
)

$ErrorActionPreference = "Stop"

function Resolve-RepoFromRemote {
    $url = (git remote get-url origin).Trim()
    if ($url -match "github\.com[:/](.+?)(?:\.git)?$") {
        return $Matches[1]
    }
    throw "Unable to parse GitHub repository from origin URL: $url"
}

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Download-Asset {
    param(
        $Release,
        [string]$Repo,
        [string]$Name,
        [string]$TargetDir,
        [switch]$UseApiBrowserDownload
    )
    $asset = $Release.assets | Where-Object { "$($_.name)" -eq $Name } | Select-Object -First 1
    if (-not $asset) {
        return $false
    }
    $targetPath = Join-Path $TargetDir $Name
    Write-Host "Downloading $Name -> $targetPath"
    if ($UseApiBrowserDownload) {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $targetPath
    } else {
        gh release download $Release.tag_name --repo $Repo --pattern $Name --dir $TargetDir --clobber | Out-Null
    }
    return $true
}

function Validate-Checksums {
    param(
        [string]$BuildRoot,
        [hashtable]$AssetMap
    )

    $checksumsPath = Join-Path $BuildRoot "checksums.txt"
    if (-not (Test-Path $checksumsPath)) {
        throw "checksums.txt not found at $checksumsPath"
    }

    $expected = @{}
    Get-Content $checksumsPath | ForEach-Object {
        if ($_ -match '^([a-fA-F0-9]{64})\s+(.+)$') {
            $expected[$Matches[2].Trim()] = $Matches[1].ToLower()
        }
    }
    if ($expected.Count -eq 0) {
        throw "No valid checksum entries found in checksums.txt"
    }

    $errors = @()
    foreach ($assetName in $AssetMap.Keys) {
        $targetPath = Join-Path $AssetMap[$assetName] $assetName
        if (-not (Test-Path $targetPath)) {
            $errors += "MISSING $assetName ($targetPath)"
            continue
        }
        if (-not $expected.ContainsKey($assetName)) {
            $errors += "NO_EXPECTED_HASH $assetName"
            continue
        }
        $actual = (Get-FileHash -Path $targetPath -Algorithm SHA256).Hash.ToLower()
        $wanted = $expected[$assetName]
        if ($actual -ne $wanted) {
            $errors += "MISMATCH $assetName expected=$wanted actual=$actual"
        } else {
            Write-Host "Checksum OK: $assetName" -ForegroundColor Green
        }
    }

    if ($errors.Count -gt 0) {
        $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        throw "Checksum validation failed for one or more assets."
    }
}

function Validate-Signature {
    param(
        [string]$Repo,
        [string]$Tag,
        [string]$BuildRoot
    )

    if (-not (Get-Command cosign -ErrorAction SilentlyContinue)) {
        throw "cosign is required for signature verification. Install cosign or pass -SkipSignatureVerification."
    }

    $checksumsPath = Join-Path $BuildRoot "checksums.txt"
    $sigPath = Join-Path $BuildRoot "checksums.txt.sig"
    $pemPath = Join-Path $BuildRoot "checksums.txt.pem"
    if (-not (Test-Path $checksumsPath)) { throw "Missing $checksumsPath" }
    if (-not (Test-Path $sigPath)) { throw "Missing $sigPath" }
    if (-not (Test-Path $pemPath)) { throw "Missing $pemPath" }

    $identityRegex = "^https://github\\.com/$([regex]::Escape($Repo))/\\.github/workflows/release\\.yml@refs/tags/$([regex]::Escape($Tag))$"
    cosign verify-blob `
        --certificate $pemPath `
        --signature $sigPath `
        --certificate-identity-regexp $identityRegex `
        --certificate-oidc-issuer "https://token.actions.githubusercontent.com" `
        $checksumsPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "cosign signature verification failed for checksums.txt"
    }
    Write-Host "Signature OK: checksums.txt (tag $Tag)" -ForegroundColor Green
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

if ([string]::IsNullOrWhiteSpace($Repo)) {
    $Repo = Resolve-RepoFromRemote
}

$buildRoot = Join-Path $repoRoot "build"
$windowsDir = Join-Path $buildRoot "windows"
$linuxDir = Join-Path $buildRoot "linux"
$androidDir = Join-Path $buildRoot "android"
Ensure-Dir $buildRoot
Ensure-Dir $windowsDir
Ensure-Dir $linuxDir
Ensure-Dir $androidDir

if ([string]::IsNullOrWhiteSpace($Tag)) {
    $release = gh api "repos/$Repo/releases/latest" | ConvertFrom-Json
} else {
    $release = gh api "repos/$Repo/releases/tags/$Tag" | ConvertFrom-Json
}

if (-not $release -or -not $release.assets) {
    throw "No assets found for release."
}

Write-Host "Using release: $($release.tag_name)" -ForegroundColor Cyan
Write-Host "URL: $($release.html_url)"

$assetMap = @{
    "agent.exe" = $windowsDir
    "agent-linux-amd64" = $linuxDir
    "app-release.apk" = $androidDir
}

$metadataAssets = @(
    "checksums.txt",
    "checksums.txt.sig",
    "checksums.txt.pem",
    "go-modules.json",
    "flutter-packages.txt"
)

# Always fetch checksums first when validation is enabled.
if (-not $SkipChecksumValidation) {
    $downloadedChecksums = Download-Asset -Release $release -Repo $Repo -Name "checksums.txt" -TargetDir $buildRoot -UseApiBrowserDownload:$UseApiBrowserDownload
    if (-not $downloadedChecksums) {
        throw "checksums.txt is required for validation but was not found in release assets."
    }
    if (-not $SkipSignatureVerification) {
        [void](Download-Asset -Release $release -Repo $Repo -Name "checksums.txt.sig" -TargetDir $buildRoot -UseApiBrowserDownload:$UseApiBrowserDownload)
        [void](Download-Asset -Release $release -Repo $Repo -Name "checksums.txt.pem" -TargetDir $buildRoot -UseApiBrowserDownload:$UseApiBrowserDownload)
    }
}

foreach ($asset in $release.assets) {
    $name = "$($asset.name)"
    $targetDir = $null

    if (-not $SkipChecksumValidation -and $name -eq "checksums.txt") {
        continue
    }

    if ($assetMap.ContainsKey($name)) {
        $targetDir = $assetMap[$name]
    } elseif ($IncludeMetadata -and ($metadataAssets -contains $name)) {
        $targetDir = $buildRoot
    }

    if (-not $targetDir) {
        continue
    }

    [void](Download-Asset -Release $release -Repo $Repo -Name $name -TargetDir $targetDir -UseApiBrowserDownload:$UseApiBrowserDownload)
}

if (-not $SkipChecksumValidation) {
    Write-Host ""
    if (-not $SkipSignatureVerification) {
        Write-Host "Validating signature..." -ForegroundColor Cyan
        Validate-Signature -Repo $Repo -Tag $release.tag_name -BuildRoot $buildRoot
    }
    Write-Host "Validating checksums..." -ForegroundColor Cyan
    Validate-Checksums -BuildRoot $buildRoot -AssetMap $assetMap
}

Write-Host ""
Write-Host "Done. Assets pulled into build/." -ForegroundColor Green
