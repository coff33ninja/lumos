param(
  [string]$ServiceName = "LumosAgent",
  [string]$DisplayName = "Lumos Agent",
  [string]$Description = "Lumos wake/shutdown agent",
  [string]$BinaryPath = (Join-Path $PSScriptRoot "..\\lumos-agent.exe")
)

$resolved = (Resolve-Path $BinaryPath).Path

if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
  Write-Host "Service already exists: $ServiceName"
  exit 1
}

New-Service -Name $ServiceName -BinaryPathName "`"$resolved`"" -DisplayName $DisplayName -StartupType Automatic
sc.exe description $ServiceName $Description | Out-Null
Start-Service -Name $ServiceName
Write-Host "Installed and started $ServiceName"
