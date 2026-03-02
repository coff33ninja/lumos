param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [Parameter(Mandatory = $true)]
    [string]$Channel,
    [string]$Repo = "",
    [switch]$SkipCommit,
    [switch]$SkipWikiSync
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

Write-Step "Post-Release Automation for $Tag"
Write-Host "Repository: $Repo" -ForegroundColor White
Write-Host "Channel: $Channel" -ForegroundColor White

# 1. Verify release exists
Write-Step "Verifying release exists"
$releaseExists = $false
try {
    gh release view $Tag --repo $Repo --json tagName 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $releaseExists = $true
        Write-Host "✓ Release $Tag exists" -ForegroundColor Green
    }
}
catch {
    throw "Release $Tag does not exist on GitHub"
}

if (-not $releaseExists) {
    throw "Release $Tag not found"
}

# 2. Update docs metadata (already done during release, but verify)
Write-Step "Verifying docs metadata"
$docsVersion = Get-Content -Path "docs/docs-version.json" -Raw | ConvertFrom-Json
if ($docsVersion.release_tag -eq $Tag) {
    Write-Host "✓ Docs metadata is current" -ForegroundColor Green
} else {
    Write-Warning "Docs metadata shows $($docsVersion.release_tag), expected $Tag"
    Write-Host "Updating docs metadata..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "update-release-docs.ps1") -Tag $Tag -Channel $Channel
}

# 3. Commit docs changes if any
if (-not $SkipCommit) {
    Write-Step "Committing docs updates"
    
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    
    $hasChanges = git status --porcelain
    if ($hasChanges) {
        git add docs/ README.md
        git commit -m "docs(release): auto-update metadata for $Tag [skip ci]"
        
        $pushAttempts = 0
        $maxAttempts = 3
        $pushed = $false
        
        while ($pushAttempts -lt $maxAttempts -and -not $pushed) {
            try {
                git push origin HEAD:main
                $pushed = $true
                Write-Host "✓ Docs committed and pushed" -ForegroundColor Green
            }
            catch {
                $pushAttempts++
                if ($pushAttempts -lt $maxAttempts) {
                    Write-Warning "Push failed, retrying ($pushAttempts/$maxAttempts)..."
                    Start-Sleep -Seconds 2
                    git pull --rebase origin main
                } else {
                    throw "Failed to push docs after $maxAttempts attempts"
                }
            }
        }
    } else {
        Write-Host "No docs changes to commit" -ForegroundColor Yellow
    }
}

# 4. Trigger wiki sync
if (-not $SkipWikiSync) {
    Write-Step "Triggering wiki sync"
    
    try {
        gh workflow run wiki-sync.yml --repo $Repo
        Write-Host "✓ Wiki sync workflow triggered" -ForegroundColor Green
        Write-Host "  Check status: gh run list --workflow=wiki-sync.yml --limit 1" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Failed to trigger wiki sync: $($_.Exception.Message)"
        Write-Host "  You can manually trigger it from GitHub Actions" -ForegroundColor Yellow
    }
}

# 5. Summary
Write-Step "Post-Release Automation Complete"
Write-Host "Release: $Tag" -ForegroundColor Green
Write-Host "Docs: Updated and committed" -ForegroundColor Green
Write-Host "Wiki: Sync triggered" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Verify wiki sync completed: https://github.com/$Repo/wiki" -ForegroundColor White
Write-Host "2. Check release page: https://github.com/$Repo/releases/tag/$Tag" -ForegroundColor White
Write-Host "3. Announce release to users" -ForegroundColor White
