<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Lumos Agent - Configuration Guide

## Configuration Methods

Lumos Agent supports two configuration methods (in order of priority):

1. **JSON Configuration File** (Recommended) - `lumos-config.json`
2. **Environment Variables** (Fallback)

The agent will first try to load settings from `lumos-config.json`. If a setting is not found in the file, it will fall back to environment variables, and finally to default values.

## Quick Start

### 1. First Run - Auto-Generated Credentials

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

### 2. Customize the Configuration File (Optional)

After the initial auto-generation, you can edit `lumos-config.json` to customize:

```json
{
  "password": "your-secure-password-here",
  "cluster_key": "your-cluster-secret-here",
  "dry_run": true,
  "agent_id": "my-computer",
  "bind": ":8080"
}
```

**For multi-agent setups:**
- Each agent should have a unique `password` (auto-generated per agent)
- All agents in the mesh must share the same `cluster_key` (copy from first agent)
- Other credentials (`ui_password`, `shutdown_key`, `state_encryption_salt`) should remain unique per agent

### 3. Launch Lumos

**Windows:**
- Double-click `start-lumos.bat` or `start-lumos-tray.ps1`
- Or run: `.\lumos-agent.exe`

**No environment variables needed!** Everything is in the config file (auto-generated on first run).

## Configuration Options

### Required Settings

| Setting | Description | Example |
|---------|-------------|---------|
| `password` | Main password for API access | `"my-secure-pass-123"` |

### Basic Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `bind` | `:8080` | Address and port to listen on |
| `agent_id` | hostname | Unique identifier for this agent |
| `advertise_addr` | auto-detected | Address other agents use to reach this one |
| `dry_run` | `true` | If true, power commands are simulated (safe mode) |

### Security Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `cluster_key` | `""` | Shared secret for agent-to-agent communication |
| `allow_wake_without_password` | `false` | Allow wake commands without authentication |
| `ui_user` | `"lumos"` | Username for web UI login |
| `ui_password` | same as `password` | Password for web UI (if different from main) |
| `tls_cert_file` | `""` | Path to TLS certificate for HTTPS |
| `tls_key_file` | `""` | Path to TLS private key |
| `require_tls` | `false` | Fail startup if TLS not configured |
| `allow_insecure_remote_http` | `false` | Allow non-localhost HTTP without TLS |

### Action Allowances (Policy)

Use these to restrict what paired app tokens and peer agents can do:

| Setting | Default | Description |
|---------|---------|-------------|
| `default_token_allowances` | all `true` | Baseline action policy for all app tokens |
| `token_allowances` | `{}` | Per-token override map (key = `token_id`) |
| `relay_inbound_allowances` | `{}` | Per-source-agent policy for forwarded relay actions |
| `relay_outbound_allowances` | `{}` | Per-target-agent policy for outgoing relay actions |

Supported actions inside each policy object:
- `wake`
- `shutdown`
- `reboot`
- `sleep`
- `relay`

### Network Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `bootstrap_peers` | `[]` | List of peer addresses for auto-registration |
| `mdns_enabled` | `true` | Enable mDNS auto-discovery |
| `mdns_service` | `"_lumos-agent._tcp"` | mDNS service name |
| `public_advertise_addr` | `""` | Public IP address (for WAN access) |
| `vpn_advertise_addr` | `""` | VPN IP address |

### Storage Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `state_file` | `"lumos-agent-state.json"` | Path to persistent state file |
| `state_encryption_salt` | `""` | Salt for state file encryption |

### Advanced Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `shutdown_key` | auto-generated | Internal key for tray app shutdown |

## Configuration Examples

### Example 1: Basic Single Computer

```json
{
  "password": "my-password",
  "dry_run": true,
  "agent_id": "my-desktop"
}
```

### Example 2: LAN with Multiple Agents

```json
{
  "password": "shared-password",
  "cluster_key": "shared-cluster-secret",
  "advertise_addr": "192.168.1.100:8080",
  "bootstrap_peers": [
    "192.168.1.101:8080",
    "192.168.1.102:8080"
  ],
  "dry_run": false,
  "agent_id": "desktop-01"
}
```

### Example 3: Production with TLS

```json
{
  "password": "strong-password-here",
  "cluster_key": "cluster-secret",
  "tls_cert_file": "cert.pem",
  "tls_key_file": "key.pem",
  "require_tls": true,
  "dry_run": false,
  "agent_id": "server-01"
}
```

### Example 4: Public Internet Access

```json
{
  "password": "very-strong-password",
  "cluster_key": "very-strong-cluster-key",
  "tls_cert_file": "fullchain.pem",
  "tls_key_file": "privkey.pem",
  "require_tls": true,
  "public_advertise_addr": "myserver.example.com:8080",
  "dry_run": false
}
```

## Credential Rotation

### Manual Rotation (Current Method)

To rotate credentials manually:

1. Stop the agent
2. Edit `lumos-config.json` and update the credential(s):
   - `password` - Main API authentication password
   - `cluster_key` - Shared secret for peer mesh (must update on all agents)
   - `ui_password` - Web UI password
   - `shutdown_key` - Internal shutdown key (update tray launcher if needed)
   - `state_encryption_salt` - State file encryption salt (will re-encrypt state)
3. Restart the agent
4. Re-pair mobile apps (if password changed)
5. Update peer agents (if cluster_key changed)

**Note**: Credential rotation API endpoints are planned for future releases (see ../docs/CREDENTIAL_VALIDATION_SUMMARY.md).

### Recommended Rotation Schedule

- `password`: Every 90 days or after suspected compromise
- `cluster_key`: Every 180 days or when removing agents from mesh
- `ui_password`: Every 90 days
- `shutdown_key`: Only if compromised
- `state_encryption_salt`: Only if compromised (requires state re-encryption)

## Updating Configuration

### Method 1: Edit the File Directly

1. Stop the agent
2. Edit `lumos-config.json`
3. Restart the agent

### Method 2: Via Web UI (Coming Soon)

The web UI will have a configuration editor that saves changes to the JSON file.

### Method 3: Via API

```powershell
# Load current config
$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("lumos:your-password"))
$config = Invoke-RestMethod -Uri http://127.0.0.1:8080/v1/ui/config/load -Headers @{"Authorization"="Basic $cred"}

# Modify and save
$config.config.dry_run = $false
$body = $config.config | ConvertTo-Json
Invoke-RestMethod -Uri http://127.0.0.1:8080/v1/ui/config/save -Method POST -Headers @{"Authorization"="Basic $cred"; "Content-Type"="application/json"} -Body $body
```

## Environment Variable Override

You can still use environment variables to override config file settings:

```powershell
$env:LUMOS_AGENT_PASSWORD = "override-password"
$env:LUMOS_DRY_RUN = "false"
.\lumos-agent.exe
```

Priority: Environment Variables > Config File > Defaults

## Custom Config File Location

Set a custom config file path:

```powershell
$env:LUMOS_CONFIG_FILE = "C:\path\to\my-config.json"
.\lumos-agent.exe
```

## Security Best Practices

1. **Use strong passwords** - At least 16 characters, random
2. **Enable TLS for WAN** - Never expose HTTP to the internet
3. **Keep dry_run=true** until you've tested thoroughly
4. **Protect the config file** - Contains sensitive passwords
5. **Use different passwords** - Don't reuse passwords across agents
6. **Rotate cluster keys** - Change periodically for security
7. **Use action policies** - Restrict destructive actions per device/token
8. **Monitor audit trail** - Review action logs in web UI regularly

### Security Documentation

- **[../docs/CREDENTIAL_VALIDATION_SUMMARY.md](../docs/CREDENTIAL_VALIDATION_SUMMARY.md)** - Complete credential flow validation and security analysis
- **[../docs/SECURITY.md](../docs/SECURITY.md)** - Security policy, vulnerability reporting, deployment best practices
- **[../docs/SECURITY_IMPROVEMENTS.md](../docs/SECURITY_IMPROVEMENTS.md)** - Security audit findings and recommended fixes
- **[API_REFERENCE.md](API_REFERENCE.md)** - Authentication methods and security features

### Reporting Security Issues

**DO NOT** open public GitHub issues for security vulnerabilities. See [../docs/SECURITY.md](../docs/SECURITY.md) for responsible disclosure guidelines.

### Known Security Alerts

See [../docs/CREDENTIAL_VALIDATION_SUMMARY.md](../docs/CREDENTIAL_VALIDATION_SUMMARY.md) for complete credential validation results:

**All 5 auto-generated credentials are functional:**
- ✅ Password (bootstrap auth) - Working, but uses SHA256 (should use bcrypt)
- ✅ Cluster Key (peer mesh) - Working correctly
- ✅ UI Password (web UI) - Working, but uses SHA256 (should use bcrypt)
- ✅ Shutdown Key (graceful shutdown) - Working correctly
- ✅ State Encryption Salt - Working correctly

**Security Issues:**
- **Medium Priority**: Weak password hashing with SHA256 - should migrate to bcrypt/Argon2id
  - Mitigation: Password is bootstrap only; tokens are used for day-to-day operations
  - Files affected: `config.go:218`, `config.go:226`, `auth.go:128`
- **Low Priority**: No credential rotation API - manual rotation required
  - Planned endpoints: `/v1/auth/rotate-password`, `/v1/auth/rotate-cluster-key`, `/v1/auth/rotate-ui-password`

See [../docs/SECURITY_IMPROVEMENTS.md](../docs/SECURITY_IMPROVEMENTS.md) for additional security alerts:
- **Critical (Alert #4)**: SSRF vulnerability in peer relay endpoint - needs URL validation to block private IPs

## Troubleshooting

### Peer Management

When adding peers manually through the web UI:
- **Peer Password**: Optional field for peer verification during registration
- If provided, the agent will verify the peer is reachable and the password is correct before adding
- This prevents adding unreachable or misconfigured peers to your network
- Leave blank to skip verification (peer will be added without validation)

### Fast Decision Tree (UI + App Discovery)

Use this sequence to quickly isolate most issues.

1. If app cannot discover agent:
   - Verify agent bind port in `lumos-config.json` (for example `"bind": ":8080"`).
   - Verify app scan ports include that port (for example `8080`).
   - Try explicit CIDR in app scan (`192.168.0.0/24`) instead of auto.

2. If phone/app can hit `/v1/status` but scan still shows nothing:
   - Confirm `allow_insecure_remote_http` vs TLS mode:
     - If `tls_cert_file` and `tls_key_file` are empty, set `"allow_insecure_remote_http": true` for LAN HTTP access.
     - If using TLS, set cert/key and keep `allow_insecure_remote_http` false.
   - Restart agent after config changes.

3. If UI opens locally but remote app gets access denied:
   - Check this combination:
     - `require_tls=true` with missing cert/key => startup/error path.
     - `allow_insecure_remote_http=false` + no TLS => remote HTTP blocked by design.
   - Either enable TLS properly or allow insecure remote HTTP on trusted LAN.

4. If commands fail after discovery:
   - Ensure agent password entered during add/pairing is correct.
   - If wake fails, ensure device MAC exists in app device interfaces.
   - Keep `dry_run=true` while validating flow; set `false` only for real power actions.

### Known Good LAN Baseline (No TLS)

For trusted home LAN testing, this baseline avoids most first-run blocks:

```json
{
  "bind": ":8080",
  "allow_insecure_remote_http": true,
  "require_tls": false,
  "dry_run": true
}
```

### Example 5: Restrict Destructive Actions by Token/Peer

```json
{
  "default_token_allowances": {
    "wake": true,
    "shutdown": false,
    "reboot": false,
    "sleep": false,
    "relay": true
  },
  "token_allowances": {
    "admin-token-id": {
      "wake": true,
      "shutdown": true,
      "reboot": true,
      "sleep": true,
      "relay": true
    }
  },
  "relay_outbound_allowances": {
    "agent-livingroom": {
      "wake": true,
      "shutdown": false,
      "reboot": false,
      "sleep": false,
      "relay": true
    }
  }
}
```

Then in app:
- Scan ports include `8080`
- Scan network is explicit (`192.168.0.0/24`) during initial bring-up

**Agent won't start:**
- Check `lumos-config.json` syntax (valid JSON)
- Ensure `password` is set
- Check file permissions

**Can't connect to web UI:**
- Verify agent is running: `curl http://127.0.0.1:8080/v1/status`
- Check firewall settings
- Verify bind address in config

**Peers not connecting:**
- Ensure `cluster_key` matches on all agents
- Check `bootstrap_peers` addresses are correct
- Verify network connectivity between agents

**Config changes not applying:**
- Restart the agent after editing config file
- Check for JSON syntax errors
- Verify no environment variables are overriding settings

## Next Steps

- See `QUICK_START.md` for basic usage
- See `README.md` for complete API documentation
- Build the Flutter mobile app for remote control



