param(
    [string]$ApkPath = "build/android/app-release.apk",
    [string]$ExpectedSha256 = ""
)

$ErrorActionPreference = "Stop"

function Resolve-Keytool {
    $keytool = Get-Command keytool -ErrorAction SilentlyContinue
    if ($keytool) {
        return $keytool.Source
    }
    if ($env:JAVA_HOME) {
        $candidate = Join-Path $env:JAVA_HOME "bin\keytool.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
    }
    throw "keytool was not found. Install JDK or set JAVA_HOME."
}

function Resolve-ApkSigner {
    $cmd = Get-Command apksigner -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $roots = @()
    if ($env:ANDROID_SDK_ROOT) { $roots += $env:ANDROID_SDK_ROOT }
    if ($env:ANDROID_HOME) { $roots += $env:ANDROID_HOME }
    if ($env:LOCALAPPDATA) { $roots += (Join-Path $env:LOCALAPPDATA "Android\Sdk") }

    foreach ($root in ($roots | Select-Object -Unique)) {
        if (-not (Test-Path $root)) { continue }
        $buildTools = Join-Path $root "build-tools"
        if (-not (Test-Path $buildTools)) { continue }
        $candidates = Get-ChildItem -Path $buildTools -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending
        foreach ($dir in $candidates) {
            foreach ($name in @("apksigner.bat", "apksigner")) {
                $candidate = Join-Path $dir.FullName $name
                if (Test-Path $candidate) {
                    return $candidate
                }
            }
        }
    }
    throw "apksigner was not found. Install Android build-tools or set ANDROID_SDK_ROOT/ANDROID_HOME."
}

if (-not (Test-Path $ApkPath)) {
    throw "APK not found: $ApkPath"
}

$owner = ""
$sha256 = ""

$keytoolExe = $null
try {
    $keytoolExe = Resolve-Keytool
} catch {}

if ($keytoolExe) {
    $raw = & $keytoolExe -printcert -jarfile $ApkPath 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ownerLine = (($raw | Where-Object { "$_".TrimStart().StartsWith("Owner:") }) | Select-Object -First 1)
        $shaLine = (($raw | Where-Object { "$_".TrimStart().StartsWith("SHA256:") }) | Select-Object -First 1)
        if ($ownerLine -and $shaLine) {
            $owner = ("$ownerLine" -replace "^\s*Owner:\s*", "").Trim()
            $sha256 = ("$shaLine" -replace "^\s*SHA256:\s*", "").Trim().ToUpperInvariant()
        }
    }
}

if ([string]::IsNullOrWhiteSpace($owner) -or [string]::IsNullOrWhiteSpace($sha256)) {
    $apkSignerExe = Resolve-ApkSigner
    $raw = & $apkSignerExe verify --print-certs $ApkPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read APK signing certificate for '$ApkPath' via apksigner: $raw"
    }
    $ownerLine = (($raw | Where-Object { "$_".TrimStart().StartsWith("Signer #1 certificate DN:") }) | Select-Object -First 1)
    $shaLine = (($raw | Where-Object { "$_".TrimStart().StartsWith("Signer #1 certificate SHA-256 digest:") }) | Select-Object -First 1)
    if (-not $ownerLine -or -not $shaLine) {
        throw "Unable to parse certificate owner/SHA-256 from apksigner output for '$ApkPath'."
    }
    $owner = ("$ownerLine" -replace "^\s*Signer #1 certificate DN:\s*", "").Trim()
    $sha256 = ("$shaLine" -replace "^\s*Signer #1 certificate SHA-256 digest:\s*", "").Trim().ToUpperInvariant()
}

$normalizedSha = ($sha256 -replace ":", "")

if ($owner -match "CN=Android Debug" -or $owner -match "Android Debug") {
    throw "APK is signed with Android Debug certificate. Release updates require a stable release keystore signature."
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedSha256)) {
    $expectedNormalized = ($ExpectedSha256.Trim().ToUpperInvariant() -replace ":", "")
    if ($normalizedSha -ne $expectedNormalized) {
        throw "APK signer mismatch. expected=$expectedNormalized actual=$normalizedSha"
    }
}

Write-Host "APK signing validation passed." -ForegroundColor Green
Write-Host "Signer owner: $owner" -ForegroundColor Green
Write-Host "Signer SHA256: $sha256" -ForegroundColor Green
