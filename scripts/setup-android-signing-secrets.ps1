param(
    [string]$Repo = "",
    [string]$Environment = "release",
    [string]$KeystorePath = "",
    [string]$KeystorePassword = "",
    [string]$KeyAlias = "",
    [string]$KeyPassword = "",
    [switch]$GenerateNewKeystore,
    [string]$GeneratedKeystoreDir = "",
    [string]$CredentialOutputPath = ""
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-Command {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "Required command not found: $Name"
    }
}

function New-RandomSecret {
    param([int]$Length = 32)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    $bytes = New-Object byte[] ($Length)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    $builder = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $Length; $i++) {
        [void]$builder.Append($chars[$bytes[$i] % $chars.Length])
    }
    return $builder.ToString()
}

function Resolve-RepoFromRemote {
    $url = (git remote get-url origin).Trim()
    if ($url -match "github\.com[:/](.+?)(?:\.git)?$") {
        return $Matches[1]
    }
    throw "Unable to parse GitHub repository from origin URL: $url"
}

function Set-GitHubEnvironmentSecret {
    param(
        [string]$SecretName,
        [string]$Value,
        [string]$Repository,
        [string]$EnvironmentName
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Secret '$SecretName' value is empty."
    }

    $Value | gh secret set $SecretName --repo $Repository --env $EnvironmentName | Out-Null
}

Require-Command "gh"
Require-Command "git"

if ([string]::IsNullOrWhiteSpace($Repo)) {
    $Repo = Resolve-RepoFromRemote
}

if ($GenerateNewKeystore) {
    Require-Command "keytool"

    if ([string]::IsNullOrWhiteSpace($GeneratedKeystoreDir)) {
        $GeneratedKeystoreDir = Join-Path $env:USERPROFILE ".lumos\signing"
    }
    New-Item -Path $GeneratedKeystoreDir -ItemType Directory -Force | Out-Null

    if ([string]::IsNullOrWhiteSpace($KeyAlias)) {
        $KeyAlias = "lumos-release"
    }
    if ([string]::IsNullOrWhiteSpace($KeystorePassword)) {
        $KeystorePassword = New-RandomSecret -Length 32
    }
    if ([string]::IsNullOrWhiteSpace($KeyPassword)) {
        $KeyPassword = New-RandomSecret -Length 32
    }

    if ([string]::IsNullOrWhiteSpace($KeystorePath)) {
        $KeystorePath = Join-Path $GeneratedKeystoreDir "lumos-release.jks"
    }

    if (Test-Path $KeystorePath) {
        $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss")
        $KeystorePath = Join-Path $GeneratedKeystoreDir "lumos-release-$stamp.jks"
    }

    Write-Step "Generating Android release keystore"
    & keytool `
        -genkeypair `
        -v `
        -keystore $KeystorePath `
        -storetype JKS `
        -storepass $KeystorePassword `
        -keypass $KeyPassword `
        -alias $KeyAlias `
        -keyalg RSA `
        -keysize 4096 `
        -validity 10000 `
        -dname "CN=Lumos Release, OU=Lumos, O=Lumos, L=NA, ST=NA, C=US" | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "keytool failed with exit code $LASTEXITCODE."
    }

    if ([string]::IsNullOrWhiteSpace($CredentialOutputPath)) {
        $CredentialOutputPath = Join-Path $GeneratedKeystoreDir "lumos-android-signing.txt"
    }

    @(
        "keystore_path=$KeystorePath",
        "key_alias=$KeyAlias",
        "keystore_password=$KeystorePassword",
        "key_password=$KeyPassword"
    ) | Set-Content -Path $CredentialOutputPath -Encoding utf8

    Write-Host "Generated keystore: $KeystorePath" -ForegroundColor Green
    Write-Host "Credential record: $CredentialOutputPath" -ForegroundColor Yellow
}

if ([string]::IsNullOrWhiteSpace($KeystorePath)) {
    throw "KeystorePath is required. Provide -KeystorePath or use -GenerateNewKeystore."
}
if ([string]::IsNullOrWhiteSpace($KeystorePassword)) {
    throw "KeystorePassword is required. Provide -KeystorePassword or use -GenerateNewKeystore."
}
if ([string]::IsNullOrWhiteSpace($KeyAlias)) {
    throw "KeyAlias is required. Provide -KeyAlias or use -GenerateNewKeystore."
}
if ([string]::IsNullOrWhiteSpace($KeyPassword)) {
    throw "KeyPassword is required. Provide -KeyPassword or use -GenerateNewKeystore."
}
if (-not (Test-Path $KeystorePath)) {
    throw "Keystore file not found: $KeystorePath"
}

$resolvedKeystore = (Resolve-Path $KeystorePath).Path

Write-Step "Validating GitHub CLI authentication"
gh auth status | Out-Null

Write-Step "Encoding Android keystore"
$keystoreBase64 = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($resolvedKeystore))

Write-Step "Setting environment secrets in '$Environment' for '$Repo'"
Set-GitHubEnvironmentSecret -SecretName "ANDROID_KEYSTORE_BASE64" -Value $keystoreBase64 -Repository $Repo -EnvironmentName $Environment
Set-GitHubEnvironmentSecret -SecretName "ANDROID_KEYSTORE_PASSWORD" -Value $KeystorePassword -Repository $Repo -EnvironmentName $Environment
Set-GitHubEnvironmentSecret -SecretName "ANDROID_KEY_ALIAS" -Value $KeyAlias -Repository $Repo -EnvironmentName $Environment
Set-GitHubEnvironmentSecret -SecretName "ANDROID_KEY_PASSWORD" -Value $KeyPassword -Repository $Repo -EnvironmentName $Environment

Write-Step "Done"
Write-Host "Configured Android signing secrets for environment '$Environment' in '$Repo'." -ForegroundColor Green
