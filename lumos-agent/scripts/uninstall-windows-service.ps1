param(
  [string]$ServiceName = "LumosAgent"
)

$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if (-not $svc) {
  Write-Host "Service not found: $ServiceName"
  exit 0
}

if ($svc.Status -ne "Stopped") {
  Stop-Service -Name $ServiceName -Force
}

sc.exe delete $ServiceName | Out-Null
Write-Host "Removed service $ServiceName"
