param(
    [switch]$SkipAgent,
    [switch]$SkipLinuxAgent,
    [switch]$SkipApp,
    [switch]$InstallApk,
    [string]$FlutterExe = "",
    [string]$AgentOutput = "agent.exe"
)

$ErrorActionPreference = "Stop"
$isGitHubActions = "$env:GITHUB_ACTIONS".Trim().ToLowerInvariant() -eq "true"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Resolve-FlutterExe {
    param([string]$Provided)

    if ($Provided -and (Test-Path $Provided)) {
        return (Resolve-Path $Provided).Path
    }

    if ($env:FLUTTER_HOME) {
        $candidate = Join-Path $env:FLUTTER_HOME "bin\flutter.bat"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $known = @(
        "E:\FLUTTER\flutter\bin\flutter.bat",
        "C:\src\flutter\bin\flutter.bat"
    )
    foreach ($candidate in $known) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $cmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    throw "Flutter executable not found. Pass -FlutterExe 'E:\FLUTTER\flutter\bin\flutter.bat' or add flutter to PATH."
}

function Test-EnvFlagTrue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $normalized = $Value.Trim().ToLowerInvariant()
    return @("1", "true", "yes", "on") -contains $normalized
}

function Resolve-JavaExe {
    $java = Get-Command java -ErrorAction SilentlyContinue
    if ($java) {
        return $java.Source
    }

    if ($env:JAVA_HOME) {
        $candidate = Join-Path $env:JAVA_HOME "bin\java.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "Java runtime was not found. Install JDK or set JAVA_HOME."
}

function Ensure-UberApkSignerJar {
    param(
        [string]$RepoRoot,
        [string]$Version
    )

    $resolvedVersion = "$Version".Trim()
    if ([string]::IsNullOrWhiteSpace($resolvedVersion)) {
        $resolvedVersion = "1.3.0"
    }

    $toolsDir = Join-Path $RepoRoot "build\tools"
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null

    $jarName = "uber-apk-signer-$resolvedVersion.jar"
    $jarPath = Join-Path $toolsDir $jarName
    $checksumPath = Join-Path $toolsDir "uber-apk-signer-$resolvedVersion-checksum.txt"
    $baseUri = "https://github.com/patrickfav/uber-apk-signer/releases/download/v$resolvedVersion"
    $jarUri = "$baseUri/$jarName"
    $checksumUri = "$baseUri/checksum-sha256.txt"

    if (-not (Test-Path $jarPath)) {
        Write-Host "Downloading $jarName" -ForegroundColor Yellow
        Invoke-WebRequest -Uri $jarUri -OutFile $jarPath
    }

    Invoke-WebRequest -Uri $checksumUri -OutFile $checksumPath
    $checksumLine = Select-String -Path $checksumPath -Pattern ([regex]::Escape($jarName)) | Select-Object -First 1
    if (-not $checksumLine) {
        throw "Unable to find checksum entry for $jarName in $checksumUri."
    }

    $expectedSha256 = (($checksumLine.Line -split '\s+')[0]).Trim().ToUpperInvariant()
    $actualSha256 = (Get-FileHash -Path $jarPath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($expectedSha256 -ne $actualSha256) {
        throw "uber-apk-signer checksum mismatch. expected=$expectedSha256 actual=$actualSha256"
    }

    return $jarPath
}

function Invoke-UberApkSigner {
    param(
        [string]$RepoRoot,
        [string]$ApkPath
    )

    if (-not (Test-Path $ApkPath)) {
        throw "APK not found for uber-apk-signer: $ApkPath"
    }

    $required = @(
        "LUMOS_ANDROID_STORE_FILE",
        "LUMOS_ANDROID_STORE_PASSWORD",
        "LUMOS_ANDROID_KEY_ALIAS",
        "LUMOS_ANDROID_KEY_PASSWORD"
    )

    $missing = @()
    foreach ($name in $required) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if ([string]::IsNullOrWhiteSpace($value)) {
            $missing += $name
        }
    }

    if ($missing.Count -gt 0) {
        throw ("uber-apk-signer requested but signing env vars are missing: {0}" -f ($missing -join ", "))
    }

    $toolVersion = "$env:LUMOS_UBER_APK_SIGNER_VERSION".Trim()
    if ([string]::IsNullOrWhiteSpace($toolVersion)) {
        $toolVersion = "1.3.0"
    }

    $jarPath = Ensure-UberApkSignerJar -RepoRoot $RepoRoot -Version $toolVersion
    $javaExe = Resolve-JavaExe

    Write-Step "Re-signing APK with uber-apk-signer v$toolVersion"
    & $javaExe `
        -jar $jarPath `
        --apks $ApkPath `
        --allowResign `
        --overwrite `
        --ks $env:LUMOS_ANDROID_STORE_FILE `
        --ksPass $env:LUMOS_ANDROID_STORE_PASSWORD `
        --ksAlias $env:LUMOS_ANDROID_KEY_ALIAS `
        --ksKeyPass $env:LUMOS_ANDROID_KEY_PASSWORD

    if ($LASTEXITCODE -ne 0) {
        throw "uber-apk-signer failed with exit code $LASTEXITCODE."
    }

    Write-Host "uber-apk-signer completed for: $ApkPath" -ForegroundColor Green
}

function Normalize-ComparatorRange {
    param([string]$RangeRaw)

    if ([string]::IsNullOrWhiteSpace($RangeRaw)) {
        return ""
    }

    $tokens = ($RangeRaw -replace ',', ' ') -split '\s+' |
        Where-Object { $_ -and $_.Trim() -ne "" } |
        ForEach-Object { $_.Trim() }
    if ($tokens.Count -eq 0) {
        return ""
    }
    return ($tokens -join ",")
}

$repoRoot = $PSScriptRoot
$agentDir = Join-Path $repoRoot "lumos-agent"
$appDir = Join-Path $repoRoot "lumos_app"
$buildRoot = Join-Path $repoRoot "build"
$buildWindowsDir = Join-Path $buildRoot "windows"
$buildLinuxDir = Join-Path $buildRoot "linux"
$buildAndroidDir = Join-Path $buildRoot "android"
$agentConfigPath = Join-Path $agentDir "lumos-config.json"
$releasePolicyPath = Join-Path $repoRoot "release-policy.json"
$minAgentVersionForPower = ""
$compatibleAppRangeForAgent = ""
$flutterDartDefines = @()
$agentVersion = ((git -C $repoRoot describe --tags --always 2>$null) | Select-Object -First 1)
if (-not $agentVersion -or [string]::IsNullOrWhiteSpace($agentVersion)) {
    $agentVersion = ((git -C $repoRoot rev-parse --short HEAD 2>$null) | Select-Object -First 1)
}
if (-not $agentVersion -or [string]::IsNullOrWhiteSpace($agentVersion)) {
    $agentVersion = "dev"
}

if (Test-Path $releasePolicyPath) {
    try {
        $releasePolicy = Get-Content -Path $releasePolicyPath -Raw | ConvertFrom-Json
        $minAgentVersionForPower = "$($releasePolicy.min_agent_version_for_power)".Trim()
        if (-not [string]::IsNullOrWhiteSpace($minAgentVersionForPower)) {
            $flutterDartDefines += "--dart-define=LUMOS_MIN_AGENT_VERSION=$minAgentVersionForPower"
        }
        foreach ($rule in @($releasePolicy.compatibility_matrix)) {
            $candidate = "$($rule.app_range)".Trim()
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                $compatibleAppRangeForAgent = Normalize-ComparatorRange -RangeRaw $candidate
                break
            }
        }
    }
    catch {
        Write-Warning "Failed to parse release-policy.json: $($_.Exception.Message)"
    }
}

$agentLdflagsParts = @("-X main.AgentVersion=$agentVersion")
if (-not [string]::IsNullOrWhiteSpace($compatibleAppRangeForAgent)) {
    $agentLdflagsParts += "-X main.CompatibleAppRange=$compatibleAppRangeForAgent"
}
$agentLdflags = $agentLdflagsParts -join " "

if (-not (Test-Path $agentDir)) {
    throw "Agent directory not found: $agentDir"
}
if (-not (Test-Path $appDir)) {
    throw "App directory not found: $appDir"
}
if (-not $SkipApp -and -not $isGitHubActions) {
    throw "Building signed release APKs is restricted to GitHub Actions. Run with -SkipApp locally or use the release-publish workflow."
}

New-Item -ItemType Directory -Force -Path $buildWindowsDir | Out-Null
New-Item -ItemType Directory -Force -Path $buildLinuxDir | Out-Null
New-Item -ItemType Directory -Force -Path $buildAndroidDir | Out-Null

# Clean up old state files (they should be machine-specific, not distributed)
Remove-Item -Path (Join-Path $buildWindowsDir "lumos-agent-state.json") -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $buildLinuxDir "lumos-agent-state.json") -Force -ErrorAction SilentlyContinue

if (-not $SkipAgent) {
    Write-Step "Building lumos-agent"
    Push-Location $agentDir
    try {
        go test ./cmd/agent

        Write-Step "Building lumos-agent for Windows (amd64)"
        $env:CGO_ENABLED = "0"
        $env:GOOS = "windows"
        $env:GOARCH = "amd64"
        go build -ldflags $agentLdflags -o $AgentOutput ./cmd/agent
        $agentBuiltPath = Join-Path $agentDir $AgentOutput
        Write-Host "Agent build complete: $agentBuiltPath" -ForegroundColor Green

        $windowsTarget = Join-Path $buildWindowsDir "agent.exe"
        Copy-Item -Path $agentBuiltPath -Destination $windowsTarget -Force
        Write-Host "Packaged Windows agent: $windowsTarget" -ForegroundColor Green
        if (Test-Path $agentConfigPath) {
            $windowsConfigTarget = Join-Path $buildWindowsDir "lumos-config.json"
            Copy-Item -Path $agentConfigPath -Destination $windowsConfigTarget -Force
            Write-Host "Packaged Windows config: $windowsConfigTarget" -ForegroundColor Green
        }

        if (-not $SkipLinuxAgent) {
            Write-Step "Building lumos-agent for Linux (amd64)"
            $linuxOutput = "agent-linux-amd64"
            $env:GOOS = "linux"
            $env:GOARCH = "amd64"
            go build -ldflags $agentLdflags -o $linuxOutput ./cmd/agent

            $linuxBuiltPath = Join-Path $agentDir $linuxOutput
            $linuxTarget = Join-Path $buildLinuxDir $linuxOutput
            Copy-Item -Path $linuxBuiltPath -Destination $linuxTarget -Force
            Write-Host "Packaged Linux agent: $linuxTarget" -ForegroundColor Green
            if (Test-Path $agentConfigPath) {
                $linuxConfigTarget = Join-Path $buildLinuxDir "lumos-config.json"
                Copy-Item -Path $agentConfigPath -Destination $linuxConfigTarget -Force
                Write-Host "Packaged Linux config: $linuxConfigTarget" -ForegroundColor Green
            }

            Remove-Item -Path $linuxBuiltPath -Force -ErrorAction SilentlyContinue
        }

        Remove-Item Env:CGO_ENABLED -ErrorAction SilentlyContinue
        Remove-Item Env:GOOS -ErrorAction SilentlyContinue
        Remove-Item Env:GOARCH -ErrorAction SilentlyContinue
    }
    finally {
        Pop-Location
    }
}

if (-not $SkipApp) {
    $useUberApkSigner = Test-EnvFlagTrue -Value "$env:LUMOS_USE_UBER_APK_SIGNER"
    $flutter = Resolve-FlutterExe -Provided $FlutterExe
    Write-Step "Building lumos_app (Flutter)"
    Push-Location $appDir
    try {
        & $flutter pub get
        & $flutter analyze
        if ($flutterDartDefines.Count -gt 0) {
            & $flutter build apk --release @flutterDartDefines
        } else {
            & $flutter build apk --release
        }

        $apk = Join-Path $appDir "build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $apk) {
            $sizeMB = [Math]::Round((Get-Item $apk).Length / 1MB, 2)
            Write-Host "APK build complete: $apk ($sizeMB MB)" -ForegroundColor Green

            $apkTarget = Join-Path $buildAndroidDir "app-release.apk"
            Copy-Item -Path $apk -Destination $apkTarget -Force
            if ($useUberApkSigner) {
                Invoke-UberApkSigner -RepoRoot $repoRoot -ApkPath $apkTarget
            }
            Write-Host "Packaged Android APK: $apkTarget" -ForegroundColor Green
        } else {
            Write-Warning "Build finished but APK was not found at expected path: $apk"
        }

        if ($InstallApk) {
            Write-Step "Installing APK to connected device/emulator"
            & $flutter install
        }
    }
    finally {
        Pop-Location
    }
}

Write-Step "Done"
Write-Host "Build artifacts folder: $buildRoot" -ForegroundColor Cyan
Write-Host "Rebuild flow completed successfully." -ForegroundColor Green
