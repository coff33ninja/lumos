param(
    [Parameter(Mandatory = $true)]
    [string]$RevertedTag,
    [Parameter(Mandatory = $true)]
    [string]$RollbackToTag,
    [string]$Repo = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Resolve-RepoFromRemote {
    $url = (git remote get-url origin).Trim()
    if ($url -match "github\.com[:/](.+?)(?:\.git)?$") {
        return $Matches[1]
    }
    throw "Unable to parse GitHub repository from origin URL: $url"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

if ([string]::IsNullOrWhiteSpace($Repo)) {
    $Repo = Resolve-RepoFromRemote
}

Write-Step "Release Revert Handler"
Write-Host "Repository: $Repo" -ForegroundColor White
Write-Host "Reverted release: $RevertedTag" -ForegroundColor Yellow
Write-Host "Rolling back to: $RollbackToTag" -ForegroundColor Green

# Validate tags exist
$revertedExists = git tag -l $RevertedTag
$rollbackExists = git tag -l $RollbackToTag

if ([string]::IsNullOrWhiteSpace($revertedExists)) {
    throw "Reverted tag '$RevertedTag' does not exist"
}

if ([string]::IsNullOrWhiteSpace($rollbackExists)) {
    throw "Rollback tag '$RollbackToTag' does not exist"
}

Write-Step "Actions to perform"
Write-Host "1. Delete GitHub release for $RevertedTag" -ForegroundColor Yellow
Write-Host "2. Delete git tag $RevertedTag" -ForegroundColor Yellow
Write-Host "3. Verify $RollbackToTag release has correct changelog" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host ""
    Write-Host "[DRY RUN] No changes will be made" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
$confirm = Read-Host "Proceed with revert? (yes/NO)"
if ($confirm -ne "yes") {
    Write-Host "Cancelled" -ForegroundColor Red
    exit 0
}

# Delete GitHub release
Write-Step "Deleting GitHub release $RevertedTag"
gh release delete $RevertedTag --repo $Repo --yes
if ($LASTEXITCODE -ne 0) {
    throw "Failed to delete GitHub release"
}
Write-Host "✓ Release deleted" -ForegroundColor Green

# Delete local and remote tag
Write-Step "Deleting git tag $RevertedTag"
git tag -d $RevertedTag
git push origin ":refs/tags/$RevertedTag"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to delete remote tag (may not exist)"
}
Write-Host "✓ Tag deleted" -ForegroundColor Green

# Verify rollback release
Write-Step "Verifying $RollbackToTag release"
$release = gh release view $RollbackToTag --repo $Repo --json body | ConvertFrom-Json

if ($release.body -match "## Changes from .+ to .+") {
    Write-Host "✓ Rollback release has automatic changelog" -ForegroundColor Green
} else {
    Write-Warning "Rollback release does not have automatic changelog"
    Write-Host ""
    Write-Host "Run this to add changelog:" -ForegroundColor Yellow
    Write-Host "  ./scripts/update-existing-releases.ps1 -Tags $RollbackToTag" -ForegroundColor White
}

Write-Step "Revert complete"
Write-Host "Current stable release: $RollbackToTag" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Update docs/docs-version.json to reference $RollbackToTag" -ForegroundColor White
Write-Host "2. Update docs/RELEASE_NOTES.md metadata" -ForegroundColor White
Write-Host "3. Commit and push documentation updates" -ForegroundColor White
