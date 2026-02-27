param(
    [ValidateSet("beta", "unreleased", "stable")]
    [string]$Channel = "beta",
    [string]$Tag = "",
    [string]$Title = "",
    [string]$Repo = "",
    [string]$NotesFile = "docs/RELEASE_NOTES.md",
    [switch]$Rebuild,
    [switch]$SkipApp,
    [switch]$Draft,
    [switch]$AllowDirty,
    [switch]$DryRun
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

function Resolve-RepoFromRemote {
    $url = (git remote get-url origin).Trim()
    if ($url -match "github\.com[:/](.+?)(?:\.git)?$") {
        return $Matches[1]
    }
    throw "Unable to parse GitHub repository from origin URL: $url"
}

function Get-DefaultTag {
    param(
        [string]$RelChannel,
        [string]$AppSemVer
    )
    $stamp = Get-Date -Format "yyyyMMddHHmm"
    switch ($RelChannel) {
        "stable" { return "$AppSemVer" }
        "beta" { return "$AppSemVer-beta.$stamp" }
        default { return "$AppSemVer-unreleased.$stamp" }
    }
}

function Get-DefaultTitle {
    param(
        [string]$RelChannel,
        [string]$AppSemVer
    )
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    switch ($RelChannel) {
        "stable" { return "Lumos $AppSemVer" }
        "beta" { return "Lumos $AppSemVer Beta ($stamp)" }
        default { return "Lumos $AppSemVer Unreleased ($stamp)" }
    }
}

function Get-AppVersion {
    param([string]$RepoRoot)
    $pubspec = Join-Path $RepoRoot "lumos_app\pubspec.yaml"
    if (-not (Test-Path $pubspec)) {
        return "unknown"
    }
    $line = Select-String -Path $pubspec -Pattern "^version:\s*(.+)$" | Select-Object -First 1
    if (-not $line) {
        return "unknown"
    }
    return $line.Matches[0].Groups[1].Value.Trim()
}

function Get-AppSemVer {
    param([string]$RepoRoot)
    $raw = Get-AppVersion -RepoRoot $RepoRoot
    if ($raw -eq "unknown") {
        throw "Unable to infer app version from lumos_app/pubspec.yaml"
    }
    $semver = ($raw -split '\+')[0].Trim()
    if ($semver -notmatch '^\d+\.\d+\.\d+([\-][0-9A-Za-z.-]+)?$') {
        throw "Invalid app semantic version '$raw' in pubspec.yaml"
    }
    return $semver
}

function Validate-ReleaseNotesForCut {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return
    }
    $raw = Get-Content -Path $Path -Raw
    if ($raw -match "<fill at release time>") {
        throw "Release notes still contain '<fill at release time>' placeholders. Update metadata before publishing."
    }
    $unchecked = Select-String -Path $Path -Pattern "^- \[ \]" -SimpleMatch:$false
    if ($unchecked) {
        throw "Release notes checklist contains unchecked items. Complete checklist before publishing."
    }
}

function Invoke-ReleaseMetadataValidation {
    param(
        [string]$RepoRoot,
        [string]$NotesPath,
        [string]$Tag,
        [string]$Commit
    )
    $validator = Join-Path $RepoRoot "scripts\validate-release-metadata.ps1"
    if (-not (Test-Path $validator)) {
        return
    }
    & $validator -ExpectedTag $Tag -ExpectedCommit $Commit -NotesFile $NotesPath
}

function Invoke-DocsVersionValidation {
    param(
        [string]$RepoRoot,
        [string]$Tag,
        [string]$RelChannel
    )
    $validator = Join-Path $RepoRoot "scripts\validate-docs-version.ps1"
    if (-not (Test-Path $validator)) {
        return
    }
    & $validator `
        -ExpectedTag $Tag `
        -Channel $RelChannel `
        -DocsVersionFile (Join-Path $RepoRoot "docs\docs-version.json")
}

$repoRoot = $PSScriptRoot
Set-Location $repoRoot

Require-Command "git"
Require-Command "gh"

$isGitHubActions = "$env:GITHUB_ACTIONS".Trim().ToLowerInvariant() -eq "true"
if (-not $isGitHubActions -and -not $DryRun) {
    throw "publish-release.ps1 is restricted to GitHub Actions for real publishes. Use workflow_dispatch in '.github/workflows/release.yml' or run with -DryRun locally."
}

Write-Step "Validating GitHub CLI authentication"
gh auth status | Out-Null

if (-not $AllowDirty) {
    $dirty = git status --porcelain
    if ($dirty) {
        throw "Working tree is not clean. Commit/stash changes or pass -AllowDirty."
    }
}

if ($Rebuild) {
    Write-Step "Running full rebuild"
    $rebuildArgs = @()
    if ($SkipApp) {
        $rebuildArgs += "-SkipApp"
    }
    & (Join-Path $repoRoot "rebuild-all.ps1") @rebuildArgs
}

$buildRoot = Join-Path $repoRoot "build"
$artifacts = @(
    (Join-Path $buildRoot "windows\agent.exe"),
    (Join-Path $buildRoot "linux\agent-linux-amd64")
)
if (-not $SkipApp) {
    $artifacts += (Join-Path $buildRoot "android\app-release.apk")
}

Write-Step "Checking build artifacts"
foreach ($path in $artifacts) {
    if (-not (Test-Path $path)) {
        throw "Missing required artifact: $path. Run .\rebuild-all.ps1 first (or pass -Rebuild)."
    }
}

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
if (-not $SkipApp -and (Test-Path $apkSigningValidator)) {
    Write-Step "Validating APK signing certificate"
    & $apkSigningValidator -ApkPath (Join-Path $buildRoot "android\app-release.apk") -ExpectedSha256 $expectedApkSignerSha256
}

if ([string]::IsNullOrWhiteSpace($Repo)) {
    $Repo = Resolve-RepoFromRemote
}

$appVersion = Get-AppVersion -RepoRoot $repoRoot
$appSemVer = Get-AppSemVer -RepoRoot $repoRoot

if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = Get-DefaultTag -RelChannel $Channel -AppSemVer $appSemVer
}

if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = Get-DefaultTitle -RelChannel $Channel -AppSemVer $appSemVer
}

$compatibilityValidator = Join-Path $repoRoot "scripts\validate-release-compatibility.ps1"
if (Test-Path $compatibilityValidator) {
    Write-Step "Validating release compatibility policy"
    & $compatibilityValidator `
        -PolicyFile (Join-Path $repoRoot "release-policy.json") `
        -PubspecPath (Join-Path $repoRoot "lumos_app\pubspec.yaml") `
        -AgentVersion $Tag `
        -Channel $Channel
}

Write-Step "Validating docs version metadata"
Invoke-DocsVersionValidation -RepoRoot $repoRoot -Tag $Tag -RelChannel $Channel

$head = (git rev-parse --short HEAD).Trim()
$notesIntro = @(
    "Channel: $Channel",
    "Commit: $head",
    "Generated by publish-release.ps1"
) -join "`n"

$compatibilityBlock = @"

## Compatibility Matrix

| Component | Version |
|---|---|
| App (`lumos_app`) | $appVersion |
| Agent (`lumos-agent`) | $Tag |
| Commit | $head |
"@

$cmd = @(
    "release", "create", $Tag,
    "--repo", $Repo,
    "--title", $Title
)

$tempNotesPath = $null
if (Test-Path (Join-Path $repoRoot $NotesFile)) {
    $notesPath = Join-Path $repoRoot $NotesFile
    Validate-ReleaseNotesForCut -Path $notesPath
    Invoke-ReleaseMetadataValidation -RepoRoot $repoRoot -NotesPath $notesPath -Tag $Tag -Commit $head
    $tempNotesPath = [System.IO.Path]::GetTempFileName()
    $notesBody = Get-Content -Path $notesPath -Raw
    Set-Content -Path $tempNotesPath -Value ($notesBody + "`r`n" + $compatibilityBlock)
    $cmd += @("--notes-file", $tempNotesPath)
} else {
    $cmd += @("--generate-notes", "--notes", ($notesIntro + "`r`n" + $compatibilityBlock))
}

if ($Channel -ne "stable") {
    $cmd += "--prerelease"
}
if ($Draft) {
    $cmd += "--draft"
}

$checksumScript = Join-Path $repoRoot "scripts\generate-checksums.ps1"
$sbomScript = Join-Path $repoRoot "scripts\generate-sbom.ps1"
$checksumsPath = Join-Path $buildRoot "checksums.txt"
if (Test-Path $checksumScript) {
    & $checksumScript -Artifacts $artifacts -OutputPath $checksumsPath
    if (Test-Path $checksumsPath) {
        $artifacts += $checksumsPath
    }
}
if (Test-Path $sbomScript) {
    & $sbomScript -OutputDir (Join-Path $buildRoot "sbom")
    $goSbomPath = Join-Path $buildRoot "sbom\go-modules.json"
    $flutterSbomPath = Join-Path $buildRoot "sbom\flutter-packages.txt"
    if (Test-Path $goSbomPath) {
        $artifacts += $goSbomPath
    }
    if (Test-Path $flutterSbomPath) {
        $artifacts += $flutterSbomPath
    }
}
$cmd += $artifacts

Write-Step "Creating GitHub release"
Write-Host "Repo: $Repo"
Write-Host "Tag: $Tag"
Write-Host "Title: $Title"
Write-Host "Artifacts:"
foreach ($artifact in $artifacts) {
    Write-Host "  - $artifact"
}

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry run command:" -ForegroundColor Yellow
    Write-Host "gh $($cmd -join ' ')" -ForegroundColor Yellow
    exit 0
}

$tempNotesPathCleanup = $tempNotesPath
try {
    $releaseExists = $false
    gh release view $Tag --repo $Repo --json tagName 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $releaseExists = $true
    }

    if ($releaseExists) {
        Write-Step "Release exists for tag $Tag; updating metadata and assets"
        $editCmd = @("release", "edit", $Tag, "--repo", $Repo, "--title", $Title)
        if ($tempNotesPathCleanup -and (Test-Path $tempNotesPathCleanup)) {
            $editCmd += @("--notes-file", $tempNotesPathCleanup)
        }
        if ($Channel -ne "stable") {
            $editCmd += "--prerelease"
        }
        gh @editCmd
        if ($LASTEXITCODE -ne 0) {
            throw "gh release edit failed with exit code $LASTEXITCODE."
        }

        $uploadCmd = @("release", "upload", $Tag, "--repo", $Repo, "--clobber")
        $uploadCmd += $artifacts
        gh @uploadCmd
        if ($LASTEXITCODE -ne 0) {
            throw "gh release upload failed with exit code $LASTEXITCODE."
        }
    } else {
        gh @cmd
        if ($LASTEXITCODE -ne 0) {
            throw "gh release create failed with exit code $LASTEXITCODE."
        }
    }
}
finally {
    if ($tempNotesPathCleanup -and (Test-Path $tempNotesPathCleanup)) {
        Remove-Item -Path $tempNotesPathCleanup -Force -ErrorAction SilentlyContinue
    }
}

Write-Step "Done"
Write-Host "Release created successfully." -ForegroundColor Green
