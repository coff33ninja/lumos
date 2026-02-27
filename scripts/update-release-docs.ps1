param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [ValidateSet("stable", "beta", "unreleased")]
    [string]$Channel = "stable",
    [string]$Commit = "auto",
    [string]$DateUtc = "",
    [string]$DocsVersionFile = "docs/docs-version.json",
    [switch]$SkipGlobalDocStamp
)

$ErrorActionPreference = "Stop"

function Normalize-ReleaseTagByChannel {
    param(
        [string]$InputTag,
        [string]$RelChannel
    )

    $tag = "$InputTag".Trim()
    if ([string]::IsNullOrWhiteSpace($tag)) {
        throw "Tag is required."
    }

    $channel = "$RelChannel".Trim().ToLowerInvariant()
    if ($channel -eq "stable") {
        if (-not $tag.StartsWith("v")) {
            $tag = "v$tag"
        }
    } else {
        if ($tag.StartsWith("v")) {
            $tag = $tag.Substring(1)
        }
    }

    return $tag
}

function Get-TagWithoutPrefix {
    param([string]$InputTag)
    $tag = "$InputTag".Trim()
    if ($tag.StartsWith("v")) {
        return $tag.Substring(1)
    }
    return $tag
}

function Parse-MajorMinor {
    param([string]$TagWithoutPrefix)
    $match = [regex]::Match($TagWithoutPrefix, '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:-(?<pre>[0-9A-Za-z.-]+))?$')
    if (-not $match.Success) {
        throw "Tag '$TagWithoutPrefix' is not a valid semantic version."
    }
    return [pscustomobject]@{
        Major = [int]$match.Groups["major"].Value
        Minor = [int]$match.Groups["minor"].Value
        Patch = [int]$match.Groups["patch"].Value
        Pre   = "$($match.Groups["pre"].Value)"
    }
}

function Set-Or-InsertLine {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Pattern,
        [string]$NewLine,
        [string]$AnchorPattern = ""
    )

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $Pattern) {
            $Lines[$i] = $NewLine
            return
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($AnchorPattern)) {
        for ($i = 0; $i -lt $Lines.Count; $i++) {
            if ($Lines[$i] -match $AnchorPattern) {
                $Lines.Insert($i + 1, $NewLine)
                return
            }
        }
    }

    $Lines.Add("")
    $Lines.Add($NewLine)
}

function Save-Lines {
    param(
        [string]$Path,
        [System.Collections.Generic.List[string]]$Lines
    )
    Set-Content -Path $Path -Value $Lines -Encoding utf8
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$normalizedTag = Normalize-ReleaseTagByChannel -InputTag $Tag -RelChannel $Channel
$tagNoPrefix = Get-TagWithoutPrefix -InputTag $normalizedTag
$parsed = Parse-MajorMinor -TagWithoutPrefix $tagNoPrefix

if ([string]::IsNullOrWhiteSpace($DateUtc)) {
    $DateUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
}

# 1) docs/docs-version.json
$docsVersionPath = Join-Path $repoRoot $DocsVersionFile
if (-not (Test-Path $docsVersionPath)) {
    throw "Docs version file not found: $docsVersionPath"
}
$docsVersion = Get-Content -Path $docsVersionPath -Raw | ConvertFrom-Json
$docsVersion.release_tag = $normalizedTag
$docsVersion.updated_utc = $DateUtc
$docsVersionJson = $docsVersion | ConvertTo-Json -Depth 8
Set-Content -Path $docsVersionPath -Value $docsVersionJson -Encoding utf8

# 2) docs/RELEASE_NOTES.md metadata
$releaseNotesPath = Join-Path $repoRoot "docs/RELEASE_NOTES.md"
if (Test-Path $releaseNotesPath) {
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content -Path $releaseNotesPath)) {
        $null = $lines.Add([string]$line)
    }

    Set-Or-InsertLine -Lines $lines -Pattern '^- Channel:\s*`[^`]+`\s*$' -NewLine ('- Channel: `{0}`' -f $Channel)
    Set-Or-InsertLine -Lines $lines -Pattern '^- Tag:\s*`[^`]+`\s*$' -NewLine ('- Tag: `{0}`' -f $normalizedTag)
    Set-Or-InsertLine -Lines $lines -Pattern '^- Commit:\s*`[^`]+`\s*$' -NewLine ('- Commit: `{0}`' -f $Commit)
    Set-Or-InsertLine -Lines $lines -Pattern '^- Date \(UTC\):\s*`[^`]+`\s*$' -NewLine ('- Date (UTC): `{0}`' -f $DateUtc)
    Set-Or-InsertLine -Lines $lines -Pattern '^  - app:\s*`[^`]+`.*$' -NewLine ('  - app: `v{0}.{1}.x` patch line supported' -f $parsed.Major, $parsed.Minor)
    Set-Or-InsertLine -Lines $lines -Pattern '^  - agent:\s*`[^`]+`.*$' -NewLine ('  - agent: `v{0}.{1}.x` patch line supported' -f $parsed.Major, $parsed.Minor)

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^###\s+v?\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?\s+Patch Highlights\s*$') {
            $lines[$i] = "### $normalizedTag Patch Highlights"
            break
        }
    }

    Save-Lines -Path $releaseNotesPath -Lines $lines
}

# 3) docs/wiki/Releases-and-Versioning.md stable target
$wikiReleasePath = Join-Path $repoRoot "docs/wiki/Releases-and-Versioning.md"
if ((Test-Path $wikiReleasePath) -and $Channel -eq "stable" -and -not $tagNoPrefix.Contains("-")) {
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content -Path $wikiReleasePath)) {
        $null = $lines.Add([string]$line)
    }
    Set-Or-InsertLine -Lines $lines -Pattern '^Current stable target:\s*`[^`]+`\.\s*$' -NewLine ('Current stable target: `{0}`.' -f $tagNoPrefix)
    Save-Lines -Path $wikiReleasePath -Lines $lines
}

# 4) README stable version reference line
$rootReadmePath = Join-Path $repoRoot "README.md"
if ((Test-Path $rootReadmePath) -and $Channel -eq "stable" -and -not $tagNoPrefix.Contains("-")) {
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content -Path $rootReadmePath)) {
        $null = $lines.Add([string]$line)
    }
    Set-Or-InsertLine `
        -Lines $lines `
        -Pattern '^- Current stable release tag reference:\s*`[^`]+`\s*\(auto-updated by release tooling\)\.\s*$' `
        -NewLine ('- Current stable release tag reference: `{0}` (auto-updated by release tooling).' -f $normalizedTag) `
        -AnchorPattern '^Release version tracking:\s*$'
    Save-Lines -Path $rootReadmePath -Lines $lines
}

# 5) Stamp all markdown docs with release marker (unless skipped)
if (-not $SkipGlobalDocStamp) {
    $stamp = "<!-- lumos-docs-release: tag=$normalizedTag; updated_utc=$DateUtc -->"
    $allMarkdown = Get-ChildItem -Path $repoRoot -Recurse -File -Filter "*.md" |
        Where-Object { $_.FullName -notmatch '\\.git\\' }

    # Exclude GitHub issue/PR templates to avoid breaking YAML front matter parsing.
    $excluded = $allMarkdown | Where-Object { $_.FullName -match '\\\.github\\' }
    foreach ($file in $excluded) {
        $raw = Get-Content -Path $file.FullName -Raw
        if ($raw -match '^(<!--\s*lumos-docs-release:[^\r\n]*-->\r?\n\r?\n?)') {
            $clean = [regex]::Replace($raw, '^(<!--\s*lumos-docs-release:[^\r\n]*-->\r?\n\r?\n?)', '', 1)
            Set-Content -Path $file.FullName -Value $clean -Encoding utf8
        }
    }

    $docsFiles = $allMarkdown | Where-Object { $_.FullName -notmatch '\\\.github\\' }

    foreach ($file in $docsFiles) {
        $raw = Get-Content -Path $file.FullName -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            Set-Content -Path $file.FullName -Value "$stamp`r`n" -Encoding utf8
            continue
        }

        if ($raw -match '^(<!--\s*lumos-docs-release:[^\r\n]*-->)') {
            $updated = [regex]::Replace($raw, '^(<!--\s*lumos-docs-release:[^\r\n]*-->)', $stamp, 1)
            Set-Content -Path $file.FullName -Value $updated -Encoding utf8
        } else {
            $prefixed = "$stamp`r`n`r`n$raw"
            Set-Content -Path $file.FullName -Value $prefixed -Encoding utf8
        }
    }
}

Write-Host "Release docs update completed: tag=$normalizedTag channel=$Channel date=$DateUtc" -ForegroundColor Green
