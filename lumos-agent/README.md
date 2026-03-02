<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# Lumos Agent (Go)

![Lumos Agent Logo](../branding/lumos-logo-agent.svg)

Cross-platform Lumos agent for Windows/Linux with:
- Wake-on-LAN and local power control (`shutdown`, `reboot`, `sleep`)
- Password-protected control endpoints
- Pairing tokens (`X-Lumos-Token`) with rotate/revoke
- Agent-to-agent registration and relay forwarding
- HMAC + timestamp + nonce validation for peer-forwarded actions
- Built-in local web GUI at `/` for settings, peers, and commands
- Encrypted persistent state file for peers/settings/tokens
- Basic auth lockout (temporary block after repeated bad passwords)
- Optional Windows system tray launcher (no terminal window)
- Optional mDNS announce/discovery

Current UI posture:
- Web GUI is the active admin surface today.
- Dedicated desktop GUI is planned and tracked in `../docs/FUTURE.md`.

## 1. Build

Requirements:
- Go 1.26.0 (matches `go.mod`)

From repo root:

```powershell
go mod tidy
```

Build agent for current OS:

```powershell
go build -o lumos-agent ./cmd/agent
```

Inject explicit runtime version metadata (recommended for release builds):

```powershell
go build -ldflags "-X main.AgentVersion=v1.0.0" -o lumos-agent ./cmd/agent
```

Windows-specific builds:

```powershell
go build -o lumos-agent.exe ./cmd/agent
go build -ldflags "-H=windowsgui" -o lumos-tray.exe ./cmd/tray
```

Cross-compile examples:

```powershell
$env:GOOS="windows"; $env:GOARCH="amd64"; go build -o lumos-agent-windows-amd64.exe ./cmd/agent
$env:GOOS="linux";   $env:GOARCH="amd64"; go build -o lumos-agent-linux-amd64 ./cmd/agent
$env:GOOS="darwin";  $env:GOARCH="arm64"; go build -o lumos-agent-darwin-arm64 ./cmd/agent
Remove-Item Env:GOOS, Env:GOARCH
```

## 2. Run

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

PowerShell:

```powershell
# First run - generates config with random credentials
.\agent.exe

# Check the generated config file
Get-Content .\lumos-config.json

# Or set custom credentials via environment variables
$env:LUMOS_AGENT_PASSWORD="change-me"
$env:LUMOS_CLUSTER_KEY="cluster-secret-change-me"
$env:LUMOS_ADVERTISE_ADDR="192.168.1.20:8080"
$env:LUMOS_BOOTSTRAP_PEERS="192.168.1.21:8080,192.168.1.22:8080"
$env:LUMOS_DRY_RUN="true"
$env:LUMOS_STATE_FILE="lumos-agent-state.json"
go run ./cmd/agent
```

Linux/macOS:

```bash
# First run - generates config with random credentials
./agent

# Check the generated config file
cat ./lumos-config.json

# Or set custom credentials via environment variables
export LUMOS_AGENT_PASSWORD="change-me"
export LUMOS_CLUSTER_KEY="cluster-secret-change-me"
export LUMOS_ADVERTISE_ADDR="192.168.1.20:8080"
export LUMOS_BOOTSTRAP_PEERS="192.168.1.21:8080,192.168.1.22:8080"
export LUMOS_DRY_RUN="true"
export LUMOS_STATE_FILE="lumos-agent-state.json"
go run ./cmd/agent
```

`LUMOS_DRY_RUN=true` is the safe default. Set `false` only when ready for real shutdown/reboot/sleep.
Open `http://127.0.0.1:8080/` for the local GUI.

## 2.1 Windows Tray Mode (No Terminal)

Build binaries:

```powershell
go build -o lumos-agent.exe ./cmd/agent
go build -ldflags "-H=windowsgui" -o lumos-tray.exe ./cmd/tray
```

Run:

```powershell
$env:LUMOS_AGENT_PASSWORD="change-me"
$env:LUMOS_CLUSTER_KEY="cluster-secret-change-me"
.\lumos-tray.exe
```

The tray app starts `lumos-agent.exe` in the background, shows a tray icon, and gives:
- `Open Control Panel`
- `Restart Agent`
- `Quit`

Additional tray behavior:
- Auto-restarts the agent if it exits unexpectedly.
- Uses graceful shutdown endpoint before forced kill.
- Control URL is configurable with `LUMOS_CONTROL_URL`.
- Shows live tray status text (`running`, `restarting`, `failed`, `stopping`).

Optional env var:
- `LUMOS_AGENT_BIN` custom path to the agent executable if not next to `lumos-tray.exe`.

## 3. Endpoints

- `GET /v1/status`
- `POST /v1/command/wake`
- `POST /v1/command/power`
- `POST /v1/peer/register`
- `GET /v1/peer/list`
- `POST /v1/peer/forward`
- `POST /v1/peer/relay`
- `POST /v1/auth/pair`
- `GET /v1/auth/token/list`
- `POST /v1/auth/token/rotate`
- `POST /v1/auth/token/revoke`
- `GET /v1/policy/state`
- `POST /v1/policy/default-token`
- `POST /v1/policy/token/upsert`
- `POST /v1/policy/token/delete`
- `POST /v1/policy/relay-inbound/upsert`
- `POST /v1/policy/relay-inbound/delete`
- `POST /v1/policy/relay-outbound/upsert`
- `POST /v1/policy/relay-outbound/delete`
- `POST /v1/admin/shutdown`
- `GET /v1/ui/state`
- `POST /v1/ui/settings`
- `POST /v1/ui/peer/upsert` (with optional password verification)

`GET /v1/status` also returns:
- `version` (build-injected value; defaults to `dev`)
- `capabilities` feature flags for client compatibility gating

### Pair Token

Create token (password auth required):

```bash
curl -X POST http://127.0.0.1:8080/v1/auth/pair \
  -H "Content-Type: application/json" \
  -H "X-Lumos-Password: change-me" \
  -d '{"label":"my-phone","scope":"wake-only"}'
```

Token scopes:
- `power-admin` (default): full command access + policy read/write
- `wake-only`: can call wake only
- `read-only`: no command actions, policy read only

Use token for commands:

```bash
curl -X POST http://127.0.0.1:8080/v1/command/power \
  -H "Content-Type: application/json" \
  -H "X-Lumos-Token: <token-from-pair>" \
  -d '{"action":"shutdown"}'
```

### Wake

```bash
curl -X POST http://127.0.0.1:8080/v1/command/wake \
  -H "Content-Type: application/json" \
  -H "X-Lumos-Password: change-me" \
  -d '{"mac":"AA:BB:CC:DD:EE:FF"}'
```

### Power

```bash
curl -X POST http://127.0.0.1:8080/v1/command/power \
  -H "Content-Type: application/json" \
  -H "X-Lumos-Password: change-me" \
  -d '{"action":"shutdown"}'
```

Allowed actions: `shutdown`, `reboot`, `sleep`.

### Peer Register

```bash
curl -X POST http://127.0.0.1:8080/v1/peer/register \
  -H "Content-Type: application/json" \
  -H "X-Lumos-Cluster-Key: cluster-secret-change-me" \
  -d '{"agent_id":"desktop-02","address":"192.168.1.42:8080"}'
```

### Peer Forward Signature

For `POST /v1/peer/forward`, signature is:

`hex(hmac_sha256(cluster_key, "<unix_timestamp>.<nonce>.<raw_request_body>"))`

Headers required:
- `X-Lumos-Timestamp`
- `X-Lumos-Nonce`
- `X-Lumos-Signature`

Body example:

```json
{
  "source_agent_id": "desktop-01",
  "target_agent_id": "desktop-02",
  "action": "wake",
  "mac": "AA:BB:CC:DD:EE:FF",
  "timestamp_unix": 1760000000
}
```

### Peer Relay (agent -> peer)

Use this from the mobile app against any authenticated agent; it forwards signed commands to the target peer.

```bash
curl -X POST http://127.0.0.1:8080/v1/peer/relay \
  -H "Content-Type: application/json" \
  -H "X-Lumos-Password: change-me" \
  -d '{
    "target_agent_id":"desktop-02",
    "action":"wake",
    "mac":"AA:BB:CC:DD:EE:FF"
  }'
```

You can also pass `"address":"192.168.1.42:8080"` directly when peer registration is not available yet.

### Policy Management

Control per-device action allowances using the policy endpoints. See `API_REFERENCE.md` for full details:

- `GET /v1/policy/state` - View current policy configuration
- `POST /v1/policy/default-token` - Set default allowances for app tokens
- `POST /v1/policy/token/upsert` - Override allowances for specific tokens
- `POST /v1/policy/relay-inbound/upsert` - Control which agents can relay to this agent
- `POST /v1/policy/relay-outbound/upsert` - Control which agents this agent can relay to

Policies allow fine-grained control over `wake`, `shutdown`, `reboot`, and `sleep` actions per caller.

## 4. Environment Variables

- `LUMOS_BIND` default `:8080`
- `LUMOS_ADVERTISE_ADDR` default inferred from bind (set this explicitly in real LAN use)
- `LUMOS_AGENT_ID` default hostname
- `LUMOS_AGENT_PASSWORD` required
- `LUMOS_CLUSTER_KEY` required for peer APIs
- `LUMOS_BOOTSTRAP_PEERS` optional comma-separated peer addresses for periodic self-registration
- `LUMOS_ALLOW_WAKE_WITHOUT_PASSWORD` default `false`
- `LUMOS_DRY_RUN` default `true`
- `LUMOS_STATE_FILE` default `lumos-agent-state.json`
- `LUMOS_TLS_CERT_FILE` optional TLS certificate path
- `LUMOS_TLS_KEY_FILE` optional TLS key path
- `LUMOS_REQUIRE_TLS` default `false` (fail startup if TLS cert/key missing)
- `LUMOS_ALLOW_INSECURE_REMOTE_HTTP` default `false` (only loopback HTTP allowed without TLS)
- `LUMOS_UI_USER` default `lumos` (HTTP basic auth user for `/` and `/v1/ui/*`)
- `LUMOS_UI_PASSWORD` default same as `LUMOS_AGENT_PASSWORD`
- `LUMOS_STATE_ENCRYPTION_SALT` optional salt mixed into state encryption key derivation
- `LUMOS_MDNS_ENABLED` default `true`
- `LUMOS_MDNS_SERVICE` default `_lumos-agent._tcp`
- `LUMOS_PUBLIC_ADVERTISE_ADDR` optional public address metadata for peers
- `LUMOS_VPN_ADVERTISE_ADDR` optional VPN address metadata for peers
- `LUMOS_CONTROL_URL` used by tray launcher (default `http://127.0.0.1:8080/`)
- `LUMOS_SHUTDOWN_KEY` internal key used by tray for graceful local shutdown

## 5. Service Lifecycle

Linux systemd:

```bash
chmod +x scripts/install-systemd.sh scripts/uninstall-systemd.sh
sudo ./scripts/install-systemd.sh
sudo ./scripts/uninstall-systemd.sh
```

Windows service:

```powershell
.\scripts\install-windows-service.ps1
.\scripts\uninstall-windows-service.ps1
```

## 6. CI / Release

- CI workflow: `.github/workflows/ci.yml` (`go test`, multi-OS build checks)
- Tag release workflow: `.github/workflows/release.yml`
- GoReleaser config: `.goreleaser.yml`
- Signing/auto-update roadmap: `../docs/RELEASE_NOTES.md`

## 7. Security

Lumos Agent implements multiple security layers:

- **Auto-generated credentials**: On first run, the agent generates cryptographically secure random credentials and saves them to the config file:
  - `password` (24 hex chars): Main API authentication password
  - `cluster_key` (32 hex chars): Shared secret for peer mesh networking
  - `ui_password` (24 hex chars): Separate password for web UI access
  - `shutdown_key` (32 hex chars): Internal key for graceful shutdown
  - `state_encryption_salt` (32 hex chars): Salt for state file encryption
- **Authentication**: Password + token-based auth with rate limiting
- **Rate Limiting**: 5 failed attempts = 3 minute lockout
- **TLS Support**: Optional HTTPS with certificate/key
- **HMAC Signatures**: Peer-to-peer commands use HMAC-SHA256
- **Encrypted State**: Persistent state file is encrypted
- **Action Policies**: Per-device allowances for fine-grained control

### Security Documentation

- **[../docs/SECURITY.md](../docs/SECURITY.md)** - Security policy, vulnerability reporting, deployment best practices
- **[../docs/SECURITY_IMPROVEMENTS.md](../docs/SECURITY_IMPROVEMENTS.md)** - Security audit findings and recommended fixes
- **[../docs/CREDENTIAL_FLOW_ANALYSIS.md](../docs/CREDENTIAL_FLOW_ANALYSIS.md)** - Detailed analysis of how each auto-generated credential is used
- **[CONFIG_GUIDE.md](CONFIG_GUIDE.md)** - Security configuration options
- **[API_REFERENCE.md](API_REFERENCE.md)** - Authentication methods and security features

### Reporting Security Issues

**DO NOT** open public GitHub issues for security vulnerabilities. Instead:
- Use GitHub Security Advisories (Security tab → Report a vulnerability)
- See [../docs/SECURITY.md](../docs/SECURITY.md) for full reporting guidelines and response timeline

### Known Security Alerts

See [../docs/SECURITY_IMPROVEMENTS.md](../docs/SECURITY_IMPROVEMENTS.md) for current security alerts:

- **Critical (Alert #4)**: SSRF vulnerability in peer relay - needs URL validation to block private IPs
- **Warning (Alerts #1-3)**: Weak password hashing using SHA256 - should migrate to bcrypt/Argon2id

### Security Best Practices

1. **Use strong passwords** - At least 16 characters, random
2. **Enable TLS for WAN** - Never expose HTTP to the internet
3. **Keep dry_run=true** until tested thoroughly
4. **Protect config files** - Contains sensitive passwords
5. **Rotate credentials** - Change passwords and cluster keys periodically
6. **Use action policies** - Restrict destructive actions per device/token
7. **Monitor audit trail** - Review action logs in web UI

For detailed security configuration, see [CONFIG_GUIDE.md](CONFIG_GUIDE.md).

## 8. Notes

- GUI is intended for trusted local network use.
- For WAN exposure, put the agent behind VPN/TLS and add stronger auth/pairing.
- Tray app is currently Windows-only.

## 9. First-Run Checklist

1. **Run the agent once to generate secure credentials**:
   - The agent will create `lumos-config.json` with all security credentials:
     - `password` (24 hex chars): Main API authentication
     - `cluster_key` (32 hex chars): Peer mesh networking
     - `ui_password` (24 hex chars): Web UI access
     - `shutdown_key` (32 hex chars): Internal graceful shutdown
     - `state_encryption_salt` (32 hex chars): State file encryption
   - Check the startup log for the config file location
   - Open the config file and note your credentials
2. **For multi-agent setup**:
   - Each agent gets unique credentials (auto-generated)
   - Copy the `cluster_key` from the first agent to all other agents (must be the same for peer mesh)
   - Keep all other credentials unique per agent
3. For remote access, set TLS cert/key and keep `LUMOS_ALLOW_INSECURE_REMOTE_HTTP=false`.
4. Start the agent and open `/` with UI basic auth (`LUMOS_UI_USER` / `LUMOS_UI_PASSWORD`).
5. Create a pairing token via `/v1/auth/pair`, then store it in your mobile app.
6. Keep `LUMOS_DRY_RUN=true` until initial command tests pass.




