# Lumos Status Checker

Write-Host "=== Lumos Agent Status ===" -ForegroundColor Cyan
Write-Host ""

# Check if processes are running
$trayProcess = Get-Process -Name "lumos-tray" -ErrorAction SilentlyContinue
$agentProcess = Get-Process -Name "lumos-agent" -ErrorAction SilentlyContinue

if ($trayProcess) {
    Write-Host "✓ Tray App: Running (PID: $($trayProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "✗ Tray App: Not running" -ForegroundColor Red
}

if ($agentProcess) {
    Write-Host "✓ Agent: Running (PID: $($agentProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "✗ Agent: Not running" -ForegroundColor Red
}

Write-Host ""

# Try to connect to the agent
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:8080/v1/status" -TimeoutSec 2 -ErrorAction Stop
    $status = $response.Content | ConvertFrom-Json
    
    Write-Host "✓ Agent API: Responding" -ForegroundColor Green
    Write-Host "  Agent ID: $($status.agent_id)" -ForegroundColor Gray
    Write-Host "  OS: $($status.os)/$($status.arch)" -ForegroundColor Gray
    Write-Host "  Dry Run: $($status.dry_run)" -ForegroundColor Gray
    Write-Host "  Time: $($status.now)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Agent API: Not responding" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Control Panel: http://127.0.0.1:8080/" -ForegroundColor Cyan
Write-Host "Credentials: lumos / change-me-secure-password" -ForegroundColor Yellow
