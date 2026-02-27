param(
    [string]$ExpectedTag = "",
    [string]$Channel = "",
    [string]$DocsVersionFile = "docs/docs-version.json"
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

function Test-SemVerTag {
    param([string]$Tag)
    return $Tag -match '^v?\d+\.\d+\.\d+([\-][0-9A-Za-z.-]+)?$'
}

if (-not (Test-Path $DocsVersionFile)) {
    throw "Docs version file not found: $DocsVersionFile"
}

$payload = Get-Content -Path $DocsVersionFile -Raw | ConvertFrom-Json
$actualTag = "$($payload.release_tag)".Trim()
if ([string]::IsNullOrWhiteSpace($actualTag)) {
    throw "docs-version.json is missing required field 'release_tag'."
}
if (-not (Test-SemVerTag -Tag $actualTag)) {
    throw "Invalid docs release_tag '$actualTag'. Expected semantic version tag like v1.0.0 or 1.0.0-beta.1."
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedTag)) {
    if (-not (Test-SemVerTag -Tag $ExpectedTag.Trim())) {
        throw "ExpectedTag '$ExpectedTag' is not a valid semantic version tag."
    }
    if ((Normalize-Tag -Tag $actualTag) -ne (Normalize-Tag -Tag $ExpectedTag)) {
        throw "Docs version mismatch. expected='$ExpectedTag' actual='$actualTag'"
    }
}

$normalizedChannel = "$Channel".Trim().ToLowerInvariant()
if (-not [string]::IsNullOrWhiteSpace($normalizedChannel)) {
    if ($normalizedChannel -eq "stable") {
        if (-not $actualTag.StartsWith("v")) {
            throw "Stable docs release_tag must start with 'v'. actual='$actualTag'"
        }
        if ($actualTag.Contains("-")) {
            throw "Stable docs release_tag cannot be prerelease. actual='$actualTag'"
        }
    } elseif ($normalizedChannel -in @("beta", "unreleased")) {
        if ($actualTag.StartsWith("v")) {
            throw "Pre-release docs release_tag must not start with 'v'. actual='$actualTag'"
        }
        if (-not $actualTag.Contains("-")) {
            throw "Pre-release docs release_tag must include a prerelease suffix. actual='$actualTag'"
        }
    }
}

Write-Host "Docs version validation passed for release_tag=$actualTag channel=$normalizedChannel" -ForegroundColor Green
