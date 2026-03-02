param(
    [string]$Repo = "",
    [string[]]$Tags = @(),
    [switch]$AllReleases,
    [switch]$DryRun,
    [switch]$Force
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

function Get-AllReleaseTags {
    param([string]$Repository)
    
    $releases = gh release list --repo $Repository --limit 1000 --json tagName,isPrerelease | ConvertFrom-Json
    return $releases | ForEach-Object { $_.tagName }
}

function Get-PreviousTag {
    param(
        [string]$CurrentTag,
        [string[]]$AllTags
    )
    
    # Get all tags sorted by commit date (oldest first)
    $allTagsSorted = git tag --sort=creatordate
    
    # Find current tag position
    $currentIndex = -1
    for ($i = 0; $i -lt $allTagsSorted.Count; $i++) {
        if ($allTagsSorted[$i] -eq $CurrentTag) {
            $currentIndex = $i
            break
        }
    }
    
    if ($currentIndex -le 0) {
        # First tag or not found, use first commit
        return (git rev-list --max-parents=0 HEAD).Trim()
    }
    
    # Return the tag immediately before current
    return $allTagsSorted[$currentIndex - 1]
}

function Get-ReleaseNotes {
    param(
        [string]$Repository,
        [string]$Tag
    )
    
    $release = gh release view $Tag --repo $Repository --json body | ConvertFrom-Json
    return $release.body
}

function Test-HasAutomaticChangelog {
    param([string]$ReleaseBody)
    
    # Check if release already has automatic changelog section
    return $ReleaseBody -match "## Changes from .+ to .+"
}

function Update-ReleaseWithChangelog {
    param(
        [string]$Repository,
        [string]$Tag,
        [string]$PreviousTag,
        [string]$ExistingNotes,
        [bool]$IsDryRun
    )
    
    Write-Host "  Previous tag: $PreviousTag" -ForegroundColor Gray
    
    # Generate changelog
    $changelogScript = Join-Path $PSScriptRoot "generate-changelog.ps1"
    if (-not (Test-Path $changelogScript)) {
        throw "Changelog generator not found: $changelogScript"
    }
    
    $changelog = & $changelogScript -FromTag $PreviousTag -ToRef $Tag -MarkdownFormat -GroupByType
    
    if ([string]::IsNullOrWhiteSpace($changelog)) {
        Write-Warning "  No changelog generated for $Tag"
        return $false
    }
    
    # Check if existing notes already have a changelog
    if (Test-HasAutomaticChangelog -ReleaseBody $ExistingNotes) {
        Write-Warning "  Release $Tag already has automatic changelog section"
        return $false
    }
    
    # Append changelog to existing notes
    $updatedNotes = $ExistingNotes.TrimEnd()
    if (-not [string]::IsNullOrWhiteSpace($updatedNotes)) {
        $updatedNotes += "`r`n`r`n---`r`n`r`n"
    }
    $updatedNotes += $changelog
    
    if ($IsDryRun) {
        Write-Host "  [DRY RUN] Would update release $Tag" -ForegroundColor Yellow
        Write-Host "  Changelog preview:" -ForegroundColor Gray
        Write-Host $changelog -ForegroundColor DarkGray
        return $true
    }
    
    # Create temp file for notes
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -Path $tempFile -Value $updatedNotes -Encoding utf8
        
        # Update release
        gh release edit $Tag --repo $Repository --notes-file $tempFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Updated release $Tag" -ForegroundColor Green
            return $true
        } else {
            Write-Error "  ✗ Failed to update release $Tag"
            return $false
        }
    }
    finally {
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# Main execution
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

# Validate GitHub CLI
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is required. Install from: https://cli.github.com/"
}

Write-Step "Validating GitHub CLI authentication"
gh auth status | Out-Null

# Resolve repository
if ([string]::IsNullOrWhiteSpace($Repo)) {
    $Repo = Resolve-RepoFromRemote
}

Write-Host "Repository: $Repo" -ForegroundColor White

# Get tags to process
$tagsToProcess = @()

if ($AllReleases) {
    Write-Step "Fetching all release tags"
    $tagsToProcess = Get-AllReleaseTags -Repository $Repo
    Write-Host "Found $($tagsToProcess.Count) releases" -ForegroundColor White
} elseif ($Tags.Count -gt 0) {
    $tagsToProcess = $Tags
    Write-Host "Processing $($tagsToProcess.Count) specified tags" -ForegroundColor White
} else {
    throw "Specify either -Tags or -AllReleases"
}

if ($tagsToProcess.Count -eq 0) {
    Write-Warning "No releases to process"
    exit 0
}

# Confirm before proceeding
if (-not $DryRun -and -not $Force) {
    Write-Host ""
    Write-Host "This will update $($tagsToProcess.Count) releases with automatic changelogs." -ForegroundColor Yellow
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Cancelled" -ForegroundColor Red
        exit 0
    }
}

# Process each release
Write-Step "Processing releases"

$updated = 0
$skipped = 0
$failed = 0

foreach ($tag in $tagsToProcess) {
    Write-Host ""
    Write-Host "Processing: $tag" -ForegroundColor Cyan
    
    try {
        # Get existing release notes
        $existingNotes = Get-ReleaseNotes -Repository $Repo -Tag $tag
        
        # Find previous tag
        $previousTag = Get-PreviousTag -CurrentTag $tag -AllTags $tagsToProcess
        
        # Update release
        $result = Update-ReleaseWithChangelog `
            -Repository $Repo `
            -Tag $tag `
            -PreviousTag $previousTag `
            -ExistingNotes $existingNotes `
            -IsDryRun $DryRun
        
        if ($result) {
            $updated++
        } else {
            $skipped++
        }
    }
    catch {
        Write-Error "  ✗ Error processing $tag : $($_.Exception.Message)"
        $failed++
    }
}

# Summary
Write-Step "Summary"
Write-Host "Updated:  $updated" -ForegroundColor Green
Write-Host "Skipped:  $skipped" -ForegroundColor Yellow
Write-Host "Failed:   $failed" -ForegroundColor Red

if ($DryRun) {
    Write-Host ""
    Write-Host "This was a dry run. No releases were modified." -ForegroundColor Yellow
    Write-Host "Run without -DryRun to apply changes." -ForegroundColor Yellow
}
