param(
    [string]$Repo = "",
    [string]$WikiSourceDir = "docs/wiki",
    [string]$DocsSourceDir = "docs"
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
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

Require-Command "git"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

if ([string]::IsNullOrWhiteSpace($Repo)) {
    if ($env:GITHUB_REPOSITORY) {
        $Repo = $env:GITHUB_REPOSITORY
    } else {
        $Repo = Resolve-RepoFromRemote
    }
}

$sourcePath = Join-Path $repoRoot $WikiSourceDir
if (-not (Test-Path $sourcePath)) {
    throw "Wiki source directory not found: $sourcePath"
}
$docsPath = Join-Path $repoRoot $DocsSourceDir
if (-not (Test-Path $docsPath)) {
    throw "Docs source directory not found: $docsPath"
}

$ownerRepo = $Repo.Trim()
$wikiUrl = "https://github.com/$ownerRepo.wiki.git"

$token = $env:GH_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
    $token = $env:GITHUB_TOKEN
}
if ([string]::IsNullOrWhiteSpace($token)) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "GitHub token not found in GH_TOKEN/GITHUB_TOKEN and gh CLI is unavailable."
    }
    $token = gh auth token
}
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Unable to resolve GitHub token (GH_TOKEN, GITHUB_TOKEN, or gh auth token)."
}

$authWikiUrl = "https://x-access-token:$token@github.com/$ownerRepo.wiki.git"
$tempDir = Join-Path $env:TEMP ("lumos-wiki-sync-" + [DateTime]::UtcNow.ToString("yyyyMMddHHmmss"))

Write-Host "==> Cloning wiki repository" -ForegroundColor Cyan
git clone $authWikiUrl $tempDir
if ($LASTEXITCODE -ne 0) {
    throw @"
Failed to clone wiki repo at $wikiUrl.

If this is first-time setup, open:
  https://github.com/$ownerRepo/wiki
Create a starter page in the UI once, then rerun this script.
"@
}

try {
    Set-Location $tempDir
    Get-ChildItem -Path . -File -Filter *.md | Remove-Item -Force -ErrorAction SilentlyContinue
    Copy-Item -Path (Join-Path $sourcePath "*.md") -Destination $tempDir -Force
    Get-ChildItem -Path $docsPath -File -Filter *.md | ForEach-Object {
        $name = $_.BaseName
        $destName = "Docs-$name.md"
        Copy-Item -Path $_.FullName -Destination (Join-Path $tempDir $destName) -Force
    }

    if (Test-Path (Join-Path $tempDir "Home.md")) {
        Write-Host "Home.md found." -ForegroundColor Green
    } else {
        throw "Home.md is required in $WikiSourceDir."
    }

    git add .
    $hasChanges = (git status --porcelain)
    if (-not $hasChanges) {
        Write-Host "No wiki changes to publish." -ForegroundColor Yellow
        return
    }

    git commit -m "docs(wiki): sync from $WikiSourceDir"
    git push origin master
    Write-Host "Wiki updated: https://github.com/$ownerRepo/wiki" -ForegroundColor Green
}
finally {
    Set-Location $repoRoot
}
