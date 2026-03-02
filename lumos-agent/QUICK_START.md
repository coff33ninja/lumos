<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# Lumos Agent - Quick Start Guide

## What You Have

Two executables have been built:
- `lumos-agent.exe` - The main agent (runs in terminal)
- `lumos-tray.exe` - System tray launcher (no terminal window)

## First Run - Auto-Generated Credentials

**IMPORTANT: On first run, the agent automatically generates secure random credentials.**

When you run the agent for the first time without a config file, it will:
1. Generate cryptographically secure random credentials:
   - `password` (24 hex chars): Main API authentication password
   - `cluster_key` (32 hex chars): Shared secret for peer mesh networking
   - `ui_password` (24 hex chars): Separate password for web UI access
   - `shutdown_key` (32 hex chars): Internal key for graceful shutdown operations
   - `state_encryption_salt` (32 hex chars): Salt for state file encryption
2. Save them to `lumos-config.json` next to the executable
3. Display the config file location in the startup log

**You MUST retrieve these credentials from the generated config file before using the agent.**

Check the generated config:
```powershell
# Windows
Get-Content .\lumos-config.json

# Linux/macOS
cat ./lumos-config.json
```

## Quick Launch (Recommended)

### Option 1: System Tray (No Terminal)
Double-click: `start-lumos-tray.ps1` or `start-lumos-tray.bat`

The tray icon will appear in your system tray. Right-click it for:
- Open Control Panel
- Restart Agent
- Status
- Quit

### Option 2: Terminal Mode
```powershell
# First run - generates config with random credentials
.\lumos-agent.exe

# Check the generated config file
Get-Content .\lumos-config.json

# Or set custom credentials via environment variables
$env:LUMOS_AGENT_PASSWORD="test-password-123"
$env:LUMOS_CLUSTER_KEY="cluster-secret-test"
$env:LUMOS_DRY_RUN="true"
.\lumos-agent.exe
```

## Access the Web UI

Open your browser: http://127.0.0.1:8080/

Login credentials:
- Username: `lumos` (default)
- Password: Check `lumos-config.json` for the auto-generated password

## Test Commands

### Create a pairing token (for mobile app):
```powershell
# Replace YOUR_PASSWORD with the password from lumos-config.json
$headers = @{
    "X-Lumos-Password"="YOUR_PASSWORD"
    "Content-Type"="application/json"
}
$body = '{"label":"my-phone"}'
Invoke-WebRequest -Uri http://127.0.0.1:8080/v1/auth/pair -Method POST -Headers $headers -Body $body
```

### Send Wake-on-LAN (using token):
```powershell
$headers = @{
    "X-Lumos-Token"="YOUR_TOKEN_HERE"
    "Content-Type"="application/json"
}
$body = '{"mac":"AA:BB:CC:DD:EE:FF"}'
Invoke-WebRequest -Uri http://127.0.0.1:8080/v1/command/wake -Method POST -Headers $headers -Body $body
```

### Test shutdown command (dry-run mode):
```powershell
$headers = @{
    "X-Lumos-Token"="YOUR_TOKEN_HERE"
    "Content-Type"="application/json"
}
$body = '{"action":"shutdown"}'
Invoke-WebRequest -Uri http://127.0.0.1:8080/v1/command/power -Method POST -Headers $headers -Body $body
```

## Production Mode

To enable real shutdown/reboot/sleep commands:

Edit `start-lumos-tray.ps1` and change:
```powershell
$env:LUMOS_DRY_RUN = "false"  # Change from "true" to "false"
```

⚠️ **Warning**: Only do this when you're ready for actual power commands!

## Network Configuration

### For LAN Access
Set your local IP address:
```powershell
$env:LUMOS_ADVERTISE_ADDR = "192.168.1.100:8080"
```

### For Agent Mesh (Multiple Computers)
Add other agents as bootstrap peers:
```powershell
$env:LUMOS_BOOTSTRAP_PEERS = "192.168.1.101:8080,192.168.1.102:8080"
```

## Features

✅ Wake-on-LAN (magic packets)
✅ Remote shutdown/reboot/sleep
✅ Token-based authentication
✅ Agent-to-agent mesh networking
✅ Auto-discovery via mDNS
✅ Web-based control panel
✅ System tray integration
✅ Encrypted state persistence

## Next Steps

1. ✅ Agent is running
2. 📱 Build the Flutter mobile app
3. 🌐 Set up additional agents on other machines
4. 🔐 Configure TLS for WAN access
5. 🚀 Install as Windows service for auto-start

## Troubleshooting

**Tray icon not appearing?**
- Check Task Manager for `lumos-tray.exe` process
- Look in the system tray overflow area (hidden icons)

**Can't access web UI?**
- Verify agent is running: `curl http://127.0.0.1:8080/v1/status`
- Check firewall settings

**Wake-on-LAN not working?**
- Enable WOL in target computer's BIOS
- Ensure target computer's network card supports WOL
- Get correct MAC address: `ipconfig /all` or `ip link show`

## Environment Variables Reference

See `README.md` for complete list of configuration options.

Key variables:
- `LUMOS_AGENT_PASSWORD` - Required, main password
- `LUMOS_CLUSTER_KEY` - Required for peer mesh
- `LUMOS_DRY_RUN` - Set to "false" for production
- `LUMOS_ADVERTISE_ADDR` - Your IP:port for LAN
- `LUMOS_BOOTSTRAP_PEERS` - Comma-separated peer addresses




