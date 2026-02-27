param(
    [string]$ExpectedTag = "",
    [string]$ExpectedCommit = "",
    [string]$NotesFile = "docs/RELEASE_NOTES.md",
    [switch]$Rebuild
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-Command {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "Required command not found: $Name"
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

Require-Command "git"
Require-Command "go"
Require-Command "flutter"

$isGitHubActions = "$env:GITHUB_ACTIONS".Trim().ToLowerInvariant() -eq "true"
if ($Rebuild -and -not $isGitHubActions) {
    throw "release-doctor -Rebuild is restricted to GitHub Actions because release APK signing is CI-only."
}

if ([string]::IsNullOrWhiteSpace($ExpectedCommit)) {
    $ExpectedCommit = (git rev-parse --short HEAD).Trim()
}

Write-Step "Validate version policy"
& (Join-Path $repoRoot "scripts\validate-version-policy.ps1")

$compatibilityValidator = Join-Path $repoRoot "scripts\validate-release-compatibility.ps1"
if (Test-Path $compatibilityValidator) {
    Write-Step "Validate release compatibility matrix"
    if (-not [string]::IsNullOrWhiteSpace($ExpectedTag)) {
        & $compatibilityValidator -PolicyFile (Join-Path $repoRoot "release-policy.json") -AgentVersion $ExpectedTag
    }
    else {
        & $compatibilityValidator -PolicyFile (Join-Path $repoRoot "release-policy.json")
    }
}

Write-Step "Agent checks"
Push-Location (Join-Path $repoRoot "lumos-agent")
try {
    go test ./...
    go vet ./...
}
finally {
    Pop-Location
}

Write-Step "App checks"
Push-Location (Join-Path $repoRoot "lumos_app")
try {
    flutter pub get
    flutter analyze
    flutter test
}
finally {
    Pop-Location
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedTag)) {
    Write-Step "Validate release notes metadata"
    & (Join-Path $repoRoot "scripts\validate-release-metadata.ps1") `
        -ExpectedTag $ExpectedTag `
        -ExpectedCommit $ExpectedCommit `
        -NotesFile $NotesFile

    $docsVersionValidator = Join-Path $repoRoot "scripts\validate-docs-version.ps1"
    if (Test-Path $docsVersionValidator) {
        Write-Step "Validate docs version metadata"
        & $docsVersionValidator `
            -ExpectedTag $ExpectedTag `
            -DocsVersionFile (Join-Path $repoRoot "docs\docs-version.json")
    }
}

if ($Rebuild) {
    Write-Step "Rebuild and integrity artifacts"
    & (Join-Path $repoRoot "rebuild-all.ps1")
    $artifacts = @(
        (Join-Path $repoRoot "build\windows\agent.exe"),
        (Join-Path $repoRoot "build\linux\agent-linux-amd64"),
        (Join-Path $repoRoot "build\android\app-release.apk")
    )
    $expectedApkSignerSha256 = ""
    $releasePolicyPath = Join-Path $repoRoot "release-policy.json"
    if (Test-Path $releasePolicyPath) {
        try {
            $releasePolicy = Get-Content -Path $releasePolicyPath -Raw | ConvertFrom-Json
            $expectedApkSignerSha256 = "$($releasePolicy.android_signing.required_cert_sha256)".Trim()
        } catch {
            Write-Warning "Unable to parse android_signing policy from release-policy.json: $($_.Exception.Message)"
        }
    }
    $apkSigningValidator = Join-Path $repoRoot "scripts\validate-apk-signing.ps1"
    if (Test-Path $apkSigningValidator) {
        Write-Step "Validate APK signing certificate"
        & $apkSigningValidator -ApkPath (Join-Path $repoRoot "build\android\app-release.apk") -ExpectedSha256 $expectedApkSignerSha256
    }
    & (Join-Path $repoRoot "scripts\generate-checksums.ps1") -Artifacts $artifacts -OutputPath (Join-Path $repoRoot "build\checksums.txt")
    & (Join-Path $repoRoot "scripts\generate-sbom.ps1") -OutputDir (Join-Path $repoRoot "build\sbom")
}

Write-Step "Release doctor checks passed"
