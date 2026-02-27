param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedTag,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedCommit,
    [string]$NotesFile = "docs/RELEASE_NOTES.md"
)

$ErrorActionPreference = "Stop"

function Normalize-Tag {
    param([string]$Tag)
    $trimmed = "$Tag".Trim()
    if ($trimmed.StartsWith("v")) {
        return $trimmed.Substring(1)
    }
    return $trimmed
}

if (-not (Test-Path $NotesFile)) {
    throw "Release notes file not found: $NotesFile"
}

$raw = Get-Content -Path $NotesFile -Raw
if ($raw -match "<fill at release time>") {
    throw "Release notes contain '<fill at release time>' placeholder(s)."
}

$unchecked = Select-String -Path $NotesFile -Pattern "^- \[ \]" -SimpleMatch:$false
if ($unchecked) {
    throw "Release notes checklist has unchecked item(s)."
}

$tagMatch = [regex]::Match($raw, '(?m)^- Tag:\s*`([^`]+)`\s*$')
if (-not $tagMatch.Success) {
    throw "Unable to parse '- Tag: `...`' from $NotesFile."
}
$actualTag = $tagMatch.Groups[1].Value.Trim()
if ((Normalize-Tag -Tag $actualTag) -ne (Normalize-Tag -Tag $ExpectedTag)) {
    throw "Release notes tag mismatch. expected='$ExpectedTag' actual='$actualTag'"
}

$commitMatch = [regex]::Match($raw, '(?m)^- Commit:\s*`([^`]+)`\s*$')
if (-not $commitMatch.Success) {
    throw "Unable to parse '- Commit: `...`' from $NotesFile."
}
$actualCommit = $commitMatch.Groups[1].Value.Trim()
$actualCommitLower = $actualCommit.ToLowerInvariant()
$acceptedAutoValues = @("auto", "auto-from-tag")
$isAutoCommit = $acceptedAutoValues -contains $actualCommitLower
$expectedShort = $ExpectedCommit.Trim()
if ($expectedShort.Length -gt 7) {
    $expectedShort = $expectedShort.Substring(0, 7)
}
if (-not $isAutoCommit -and $actualCommit -ne $expectedShort) {
    throw "Release notes commit mismatch. expected='$expectedShort' actual='$actualCommit'"
}

if ($isAutoCommit) {
    Write-Host "Release metadata validation passed for tag=$ExpectedTag commit=auto" -ForegroundColor Green
} else {
    Write-Host "Release metadata validation passed for tag=$ExpectedTag commit=$expectedShort" -ForegroundColor Green
}
