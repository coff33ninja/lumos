param(
    [string]$Repo = "",
    [string]$Environment = "release",
    [Parameter(Mandatory = $true)]
    [string]$KeystorePath,
    [Parameter(Mandatory = $true)]
    [string]$KeystorePassword,
    [Parameter(Mandatory = $true)]
    [string]$KeyAlias,
    [Parameter(Mandatory = $true)]
    [string]$KeyPassword
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

if (-not (Test-Path $KeystorePath)) {
    throw "Keystore file not found: $KeystorePath"
}

if ([string]::IsNullOrWhiteSpace($Repo)) {
    $Repo = Resolve-RepoFromRemote
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
