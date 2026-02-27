param(
    [string]$PolicyFile = "release-policy.json",
    [string]$PubspecPath = "lumos_app/pubspec.yaml",
    [string]$AgentVersion = "",
    [string]$Channel = ""
)

$ErrorActionPreference = "Stop"

function Get-PubspecSemVer {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Missing pubspec file: $Path"
    }
    $line = Select-String -Path $Path -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if (-not $line) {
        throw "Unable to parse version from $Path"
    }
    $raw = $line.Matches[0].Groups[1].Value.Trim()
    $semver = ($raw -split '\+')[0].Trim()
    if ($semver -eq "") {
        throw "Parsed empty app version from $Path"
    }
    return $semver
}

function Normalize-SemVerInput {
    param(
        [string]$Raw,
        [string]$FieldName
    )
    $trimmed = $Raw.Trim()
    if ($trimmed -eq "") {
        throw "$FieldName is required"
    }
    if ($trimmed.StartsWith("v")) {
        $trimmed = $trimmed.Substring(1)
    }
    if ($trimmed.Contains("+")) {
        $trimmed = ($trimmed -split '\+')[0]
    }
    return $trimmed.Trim()
}

function Parse-SemVer {
    param(
        [string]$Raw,
        [string]$FieldName
    )
    $normalized = Normalize-SemVerInput -Raw $Raw -FieldName $FieldName
    $match = [regex]::Match($normalized, '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:-(?<pre>[0-9A-Za-z.-]+))?$')
    if (-not $match.Success) {
        throw "$FieldName must be semantic version (example: 1.2.3 or v1.2.3-rc.1). actual='$Raw'"
    }
    return [pscustomobject]@{
        Raw        = $Raw
        Normalized = $normalized
        Major      = [int]$match.Groups["major"].Value
        Minor      = [int]$match.Groups["minor"].Value
        Patch      = [int]$match.Groups["patch"].Value
        PreRelease = $match.Groups["pre"].Value
    }
}

function Compare-SemVer {
    param($Left, $Right)
    if ($Left.Major -ne $Right.Major) { return [Math]::Sign($Left.Major - $Right.Major) }
    if ($Left.Minor -ne $Right.Minor) { return [Math]::Sign($Left.Minor - $Right.Minor) }
    if ($Left.Patch -ne $Right.Patch) { return [Math]::Sign($Left.Patch - $Right.Patch) }

    $leftPre = "$($Left.PreRelease)".Trim()
    $rightPre = "$($Right.PreRelease)".Trim()
    if ($leftPre -eq "" -and $rightPre -eq "") { return 0 }
    if ($leftPre -eq "") { return 1 }
    if ($rightPre -eq "") { return -1 }
    return [Math]::Sign([string]::CompareOrdinal($leftPre, $rightPre))
}

function Test-Comparator {
    param(
        $Version,
        [string]$Token,
        [string]$RangeField
    )
    $trimmed = $Token.Trim()
    if ($trimmed -eq "") {
        return $true
    }

    $op = ""
    $rhsRaw = ""
    $match = [regex]::Match($trimmed, '^(>=|<=|>|<|==|=)(.+)$')
    if ($match.Success) {
        $op = $match.Groups[1].Value
        $rhsRaw = $match.Groups[2].Value.Trim()
    } else {
        $op = "="
        $rhsRaw = $trimmed
    }
    $rhs = Parse-SemVer -Raw $rhsRaw -FieldName "$RangeField comparator '$trimmed'"
    $cmp = Compare-SemVer -Left $Version -Right $rhs

    switch ($op) {
        ">" { return $cmp -gt 0 }
        ">=" { return $cmp -ge 0 }
        "<" { return $cmp -lt 0 }
        "<=" { return $cmp -le 0 }
        "=" { return $cmp -eq 0 }
        "==" { return $cmp -eq 0 }
        default { throw "Unsupported comparator '$op' in $RangeField token '$trimmed'" }
    }
}

function Test-VersionInRange {
    param(
        $Version,
        [string]$Range,
        [string]$RangeField
    )
    $raw = $Range.Trim()
    if ($raw -eq "") {
        throw "Missing $RangeField value in release policy"
    }
    if ($raw -eq "*") {
        return $true
    }

    $tokens = $raw -split '\s+' | Where-Object { $_ -and $_.Trim() -ne "" }
    if ($tokens.Count -eq 0) {
        throw "Invalid empty comparator list in $RangeField"
    }
    foreach ($token in $tokens) {
        if (-not (Test-Comparator -Version $Version -Token $token -RangeField $RangeField)) {
            return $false
        }
    }
    return $true
}

if (-not (Test-Path $PolicyFile)) {
    throw "Missing policy file: $PolicyFile"
}

$policy = Get-Content -Path $PolicyFile -Raw | ConvertFrom-Json
$minAgentVersion = "$($policy.min_agent_version_for_power)".Trim()
if ($minAgentVersion -eq "") {
    throw "release-policy.json missing 'min_agent_version_for_power'"
}

$allowedChannels = @($policy.allowed_version_bump_channels | Where-Object { $_ -and "$_".Trim() -ne "" } | ForEach-Object { "$_".Trim() })
if ($allowedChannels.Count -eq 0) {
    throw "release-policy.json missing non-empty 'allowed_version_bump_channels'"
}

if ($Channel -ne "" -and $allowedChannels -notcontains $Channel) {
    $list = ($allowedChannels -join ", ")
    throw "Channel '$Channel' is not allowed by release policy. allowed=[$list]"
}

$appSemVerRaw = Get-PubspecSemVer -Path $PubspecPath
$agentSemVerRaw = if ($AgentVersion.Trim() -ne "") { $AgentVersion.Trim() } else { $minAgentVersion }

$appParsedVersion = Parse-SemVer -Raw $appSemVerRaw -FieldName "app version"
$agentParsedVersion = Parse-SemVer -Raw $agentSemVerRaw -FieldName "agent version"

$matrix = @($policy.compatibility_matrix)
if ($matrix.Count -eq 0) {
    throw "release-policy.json missing 'compatibility_matrix' entries"
}

$matchingRules = @()
foreach ($rule in $matrix) {
    $appRange = "$($rule.app_range)".Trim()
    $agentRange = "$($rule.agent_range)".Trim()
    if ($appRange -eq "" -or $agentRange -eq "") {
        continue
    }
    if ((Test-VersionInRange -Version $appParsedVersion -Range $appRange -RangeField "compatibility_matrix.app_range") -and
        (Test-VersionInRange -Version $agentParsedVersion -Range $agentRange -RangeField "compatibility_matrix.agent_range")) {
        $matchingRules += $rule
    }
}

if ($matchingRules.Count -eq 0) {
    $ruleHints = ($matrix | ForEach-Object { "app='$($_.app_range)' agent='$($_.agent_range)'" }) -join "; "
    throw "No compatibility rule matched app='$($appParsedVersion.Normalized)' with agent='$($agentParsedVersion.Normalized)'. rules=[$ruleHints]"
}

$selectedRule = $matchingRules[0]
$allowSkew = $true
if ($selectedRule.PSObject.Properties.Name -contains "allow_version_skew") {
    $allowSkew = [bool]$selectedRule.allow_version_skew
}
if (-not $allowSkew -and (Compare-SemVer -Left $appParsedVersion -Right $agentParsedVersion) -ne 0) {
    throw "Compatibility rule requires exact app/agent version match, but app='$($appParsedVersion.Normalized)' agent='$($agentParsedVersion.Normalized)'"
}

$channelText = if ($Channel -eq "") { "unspecified" } else { $Channel }
Write-Host ("Release compatibility validation passed: app={0} agent={1} channel={2}" -f $appParsedVersion.Normalized, $agentParsedVersion.Normalized, $channelText) -ForegroundColor Green
