param(
    [string]$PolicyFile = "release-policy.json",
    [string]$DeviceProviderPath = "lumos_app/lib/providers/device_provider.dart",
    [string]$DocsVersioningPath = "docs/VERSIONING.md",
    [string]$CompatibilityValidatorPath = "scripts/validate-release-compatibility.ps1"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $PolicyFile)) {
    throw "Missing policy file: $PolicyFile"
}
$policy = Get-Content -Path $PolicyFile -Raw | ConvertFrom-Json
$minVersion = "$($policy.min_agent_version_for_power)".Trim()
if ($minVersion -eq "") {
    throw "release-policy.json missing 'min_agent_version_for_power'"
}
if ($minVersion -notmatch "^v") {
    throw "min_agent_version_for_power must start with 'v'. actual='$minVersion'"
}

$allowedChannels = @($policy.allowed_version_bump_channels | Where-Object { $_ -and "$_".Trim() -ne "" } | ForEach-Object { "$_".Trim() })
if ($allowedChannels.Count -eq 0) {
    throw "release-policy.json missing non-empty 'allowed_version_bump_channels'"
}
$requiredChannels = @("stable", "beta", "unreleased")
foreach ($required in $requiredChannels) {
    if ($allowedChannels -notcontains $required) {
        throw "release-policy.json missing required upload channel rule '$required' in allowed_version_bump_channels"
    }
}

$matrix = @($policy.compatibility_matrix)
if ($matrix.Count -eq 0) {
    throw "release-policy.json missing non-empty 'compatibility_matrix'"
}
foreach ($rule in $matrix) {
    $appRange = "$($rule.app_range)".Trim()
    $agentRange = "$($rule.agent_range)".Trim()
    if ($appRange -eq "" -or $agentRange -eq "") {
        throw "Each compatibility_matrix entry must define non-empty app_range and agent_range"
    }
}

$certSha256 = "$($policy.android_signing.required_cert_sha256)".Trim()
if ($certSha256 -ne "") {
    $normalizedCertSha = $certSha256.ToUpperInvariant() -replace ":", ""
    if ($normalizedCertSha -notmatch "^[0-9A-F]{64}$") {
        throw "android_signing.required_cert_sha256 must be a SHA-256 fingerprint (64 hex chars, optional colons). actual='$certSha256'"
    }
}

if (-not (Test-Path $DeviceProviderPath)) {
    throw "Missing device provider: $DeviceProviderPath"
}
$providerRaw = Get-Content -Path $DeviceProviderPath -Raw
$match = [regex]::Match($providerRaw, "defaultValue:\s*'([^']+)'")
if (-not $match.Success) {
    throw "Unable to parse default min agent version from $DeviceProviderPath"
}
$providerDefault = $match.Groups[1].Value.Trim()
if ($providerDefault -ne $minVersion) {
    throw "Version policy mismatch: policy='$minVersion' device_provider_default='$providerDefault'"
}

if (-not (Test-Path $DocsVersioningPath)) {
    throw "Missing docs file: $DocsVersioningPath"
}
$docsRaw = Get-Content -Path $DocsVersioningPath -Raw
if ($docsRaw -notmatch [regex]::Escape($minVersion)) {
    throw "Version policy mismatch: docs/VERSIONING.md does not mention '$minVersion'"
}

$compatValidator = (Resolve-Path -Path $CompatibilityValidatorPath -ErrorAction Stop).Path
& $compatValidator -PolicyFile $PolicyFile

Write-Host "Version policy validation passed: $minVersion" -ForegroundColor Green
