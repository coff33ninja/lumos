# Lumos Tray Launcher
# Configuration is loaded from lumos-config.json

Write-Host "=== Lumos Agent Launcher ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration: lumos-config.json" -ForegroundColor Green
Write-Host "Edit the config file to change settings." -ForegroundColor Gray
Write-Host ""
Write-Host "Web UI: http://127.0.0.1:8080/" -ForegroundColor Cyan
Write-Host "Default credentials: lumos / change-me-secure-password" -ForegroundColor Yellow
Write-Host ""
Write-Host "Starting tray application..." -ForegroundColor Green

$trayPath = Join-Path $PSScriptRoot "lumos-tray.exe"
Start-Process -FilePath $trayPath -WorkingDirectory $PSScriptRoot

Write-Host ""
Write-Host "✓ Lumos tray started!" -ForegroundColor Green
Write-Host "Look for the tray icon in your system tray." -ForegroundColor Gray

