<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Lumos Agent API Reference

Complete API documentation for all endpoints in the Lumos Agent project.

## Table of Contents

- [Authentication](#authentication)
- [Web UI](#web-ui)
- [Status & Information](#status--information)
- [Local Commands](#local-commands)
- [Peer Management](#peer-management)
- [Peer Communication](#peer-communication)
- [Authentication & Tokens](#authentication--tokens)
- [Policy Management](#policy-management)
- [UI Management](#ui-management)
- [Network Scanner](#network-scanner)
- [Configuration](#configuration)
- [Admin](#admin)

---

## Authentication

Lumos Agent supports multiple authentication methods:

### 1. UI Basic Auth
- **Used for**: Web UI and `/v1/ui/*` endpoints
- **Method**: HTTP Basic Authentication
- **Credentials**: 
  - Username: `ui_user` (default: "lumos")
  - Password: `ui_password` (defaults to main password)

### 2. Password Header
- **Used for**: API endpoints requiring password
- **Header**: `X-Lumos-Password: <password>`

### 3. Token Header
- **Used for**: Mobile/app authentication
- **Header**: `X-Lumos-Token: <token>`

### 4. Cluster Key
- **Used for**: Peer-to-peer communication
- **Header**: `X-Lumos-Cluster-Key: <cluster_key>`

### 5. HMAC Signature
- **Used for**: Peer forwarding/relay
- **Headers**:
  - `X-Lumos-Timestamp: <unix_timestamp>`
  - `X-Lumos-Nonce: <random_hex>`
  - `X-Lumos-Signature: <hmac_sha256>`

---

## Web UI

### GET `/`
Serves the web-based control panel.

**Authentication**: UI Basic Auth

**Response**: HTML page

---

## Status & Information

### GET `/v1/status`
Get agent status and network interfaces.

**Authentication**: None (public endpoint)

**Response**:
```json
{
  "ok": true,
  "agent_id": "WORKSHOP",
  "os": "windows",
  "arch": "amd64",
  "now": "2026-02-23T13:40:33Z",
  "dry_run": true,
  "version": "v2026.02.27-0207-beta",
  "capabilities": {
    "auth_pair": true,
    "auth_token_list": true,
    "auth_token_rotate": true,
    "auth_token_revoke": true,
    "auth_token_scope": true,
    "policy_crud": true,
    "events_ws": true
  },
  "interfaces": [
    {
      "name": "Ethernet",
      "mac": "04:D9:F5:39:13:46",
      "ips": ["10.0.0.101"]
    }
  ]
}
```

---

## Local Commands

### POST `/v1/command/wake`
Send Wake-on-LAN magic packet to a MAC address.

**Authentication**: Password or Token (optional if `allow_wake_without_password` is true)

**Request**:
```json
{
  "mac": "04:D9:F5:39:13:46"
}
```

**Response**:
```json
{
  "ok": true,
  "message": "magic packet sent"
}
```

### POST `/v1/command/power`
Execute power action on local machine.

**Authentication**: Password or Token (required)

**Request**:
```json
{
  "action": "shutdown"
}
```

**Actions**: `shutdown`, `reboot`, `sleep`

**Response**:
```json
{
  "ok": true,
  "message": "shutdown command sent"
}
```

---

## Peer Management

### POST `/v1/peer/register`
Register this agent with another peer (used by peer sync).

**Authentication**: Cluster Key

**Request**:
```json
{
  "agent_id": "WORKSHOP",
  "address": "192.168.1.100:8080",
  "public_address": "",
  "vpn_address": ""
}
```

**Response**:
```json
{
  "ok": true,
  "message": "peer registered"
}
```

### GET `/v1/peer/list`
List all known peers.

**Authentication**: Cluster Key

**Response**:
```json
{
  "ok": true,
  "peers": [
    {
      "agent_id": "LAPTOP",
      "address": "192.168.1.101:8080",
      "public_address": "",
      "vpn_address": "",
      "last_seen_at": "2026-02-23T13:40:00Z",
      "interfaces": []
    }
  ]
}
```

---

## Peer Communication

### POST `/v1/peer/relay`
Relay a command to another agent.

**Authentication**: Password or Token

**Request**:
```json
{
  "target_agent_id": "LAPTOP",
  "address": "192.168.1.101:8080",
  "action": "wake",
  "mac": "04:D9:F5:39:13:46"
}
```

**Actions**: `wake`, `shutdown`, `reboot`, `sleep`

**Response**:
```json
{
  "ok": true,
  "message": "relay sent to 192.168.1.101:8080"
}
```

### POST `/v1/peer/forward`
Receive forwarded command from another agent (internal use).

**Authentication**: HMAC Signature

**Request**:
```json
{
  "source_agent_id": "DESKTOP",
  "target_agent_id": "LAPTOP",
  "action": "wake",
  "mac": "04:D9:F5:39:13:46",
  "timestamp_unix": 1708697400
}
```

**Response**:
```json
{
  "ok": true,
  "message": "peer wake sent"
}
```

---

## Authentication & Tokens

### POST `/v1/auth/pair`
Create a new authentication token for mobile apps.

**Authentication**: Password only (not token)

**Request**:
```json
{
  "label": "My Phone",
  "scope": "wake-only"
}
```

`capabilities` is intended for app-side compatibility gating. If a capability is absent or false, clients should hide/disable dependent UI actions.

**Supported scopes**:
- `power-admin` (default): full command access (`wake`, `shutdown`, `reboot`, `sleep`) and policy read/write
- `wake-only`: only `wake`
- `read-only`: no command actions, policy read only

**Response**:
```json
{
  "ok": true,
  "token_id": "a1b2c3d4e5f6g7h8",
  "token": "1234567890abcdef...",
  "message": "store this token securely; it is shown once"
}
```

### GET `/v1/auth/token/list`
List all authentication tokens (without token values).

**Authentication**: Password only

**Response**:
```json
{
  "ok": true,
  "tokens": [
    {
      "id": "a1b2c3d4e5f6g7h8",
      "label": "My Phone",
      "scope": "wake-only",
      "created_at": "2026-02-23T13:00:00Z",
      "last_used_at": "2026-02-23T13:40:00Z",
      "revoked_at": null
    }
  ]
}
```

### POST `/v1/auth/token/revoke`
Revoke an authentication token.

**Authentication**: Password only

**Request**:
```json
{
  "token_id": "a1b2c3d4e5f6g7h8"
}
```

**Response**:
```json
{
  "ok": true,
  "message": "token revoked"
}
```

### POST `/v1/auth/token/rotate`
Rotate a token (revoke old, create new).

**Authentication**: Password only

**Request**:
```json
{
  "token_id": "a1b2c3d4e5f6g7h8"
}
```

**Response**:
```json
{
  "ok": true,
  "token_id": "x9y8z7w6v5u4t3s2",
  "token": "fedcba0987654321...",
  "message": "token rotated"
}
```

---

## Policy Management

### GET `/v1/policy/state`
Get current default/per-token and relay inbound/outbound allowance policy state.

**Authentication**: Password or token with scope `power-admin` or `read-only`

### POST `/v1/policy/default-token`
Update default app-token allowances.

**Authentication**: Password or token with scope `power-admin`

### POST `/v1/policy/token/upsert`
Upsert a token-specific allowance override.

**Authentication**: Password or token with scope `power-admin`

### POST `/v1/policy/token/delete`
Delete a token-specific allowance override.

**Authentication**: Password or token with scope `power-admin`

### POST `/v1/policy/relay-inbound/upsert`
Upsert inbound relay allowances for a source agent id.

**Authentication**: Password or token with scope `power-admin`

### POST `/v1/policy/relay-inbound/delete`
Delete inbound relay allowances for a source agent id.

**Authentication**: Password or token with scope `power-admin`

### POST `/v1/policy/relay-outbound/upsert`
Upsert outbound relay allowances for a target agent id.

**Authentication**: Password or token with scope `power-admin`

### POST `/v1/policy/relay-outbound/delete`
Delete outbound relay allowances for a target agent id.

**Authentication**: Password or token with scope `power-admin`

---

## UI Management

### GET `/v1/ui/state`
Get UI state including peers and settings.

**Authentication**: UI Basic Auth

**Response**:
```json
{
  "ok": true,
  "agent_id": "WORKSHOP",
  "os": "windows",
  "dry_run": true,
  "allow_wake_without_password": false,
  "advertise_addr": "127.0.0.1:8080",
  "bootstrap_peers": [],
  "peers": [],
  "now": "2026-02-23T13:44:22Z"
}
```

### POST `/v1/ui/settings`
Update agent settings.

**Authentication**: UI Basic Auth + Password

**Request**:
```json
{
  "advertise_addr": "192.168.1.100:8080",
  "bootstrap_peers": "192.168.1.1:8080,192.168.1.2:8080",
  "allow_wake_without_password": false,
  "dry_run": true
}
```

**Response**:
```json
{
  "ok": true,
  "message": "settings updated"
}
```

### POST `/v1/ui/peer/upsert`
Add or update a peer manually with optional password verification.

**Authentication**: UI Basic Auth

**Request**:
```json
{
  "agent_id": "LAPTOP",
  "address": "192.168.1.101:8080",
  "password": "peer-password-here"
}
```

**Fields**:
- `agent_id` (required): Unique identifier for the peer agent
- `address` (required): Network address of the peer (host:port)
- `password` (optional): If provided, verifies peer is reachable and password is correct before adding

**Response**:
```json
{
  "ok": true,
  "message": "peer upserted"
}
```

**Error Response** (if password verification fails):
```json
{
  "ok": false,
  "message": "peer verification failed: <error details>"
}
```

### POST `/v1/ui/peer/delete`
Remove a registered peer.

**Authentication**: UI Basic Auth

**Request**:
```json
{
  "agent_id": "LAPTOP"
}
```

**Fields**:
- `agent_id` (required): Unique identifier of the peer to remove

**Response**:
```json
{
  "ok": true,
  "message": "peer deleted"
}
```

**Error Response**:
```json
{
  "ok": false,
  "message": "peer not found"
}
```

---

## Network Scanner

### POST `/v1/ui/scan`
Scan network for Lumos agents.

**Authentication**: UI Basic Auth

**Request**:
```json
{
  "network": "192.168.1.0/24",
  "port": 8080,
  "timeout": 2
}
```

**Response**:
```json
{
  "ok": true,
  "scanned": "192.168.1.0/24",
  "results": [
    {
      "address": "192.168.1.101:8080",
      "agent_id": "LAPTOP",
      "reachable": true,
      "os": "linux"
    }
  ]
}
```

---

## Configuration

### GET `/v1/ui/config/load`
Load configuration file.

**Authentication**: UI Basic Auth

**Response**:
```json
{
  "ok": true,
  "config": {
    "bind": ":8080",
    "advertise_addr": "",
    "agent_id": "WORKSHOP",
    "password": "***",
    "cluster_key": "***",
    "bootstrap_peers": [],
    "allow_wake_without_password": false,
    "dry_run": true,
    "state_file": "lumos-agent-state.json",
    "tls_cert_file": "",
    "tls_key_file": "",
    "require_tls": false,
    "allow_insecure_remote_http": false,
    "ui_user": "lumos",
    "ui_password": "",
    "state_encryption_salt": "",
    "shutdown_key": "",
    "mdns_enabled": true,
    "mdns_service": "_lumos-agent._tcp",
    "public_advertise_addr": "",
    "vpn_advertise_addr": ""
  }
}
```

### POST `/v1/ui/config/save`
Save configuration to file.

**Authentication**: UI Basic Auth + Password

**Request**: Same structure as config object above

**Response**:
```json
{
  "ok": true,
  "message": "config saved; restart agent to apply changes"
}
```

---

## Admin

### POST `/v1/admin/shutdown`
Gracefully shutdown the agent.

**Authentication**: Shutdown Key (local only)

**Headers**:
- `X-Lumos-Shutdown-Key: <shutdown_key>`

**Response**:
```json
{
  "ok": true,
  "message": "shutting down"
}
```

**Note**: Only accessible from localhost (127.0.0.1)

---

## Error Responses

All endpoints return errors in this format:

```json
{
  "ok": false,
  "message": "error description"
}
```

### Common HTTP Status Codes

- `200 OK` - Success
- `400 Bad Request` - Invalid request data
- `401 Unauthorized` - Authentication failed
- `403 Forbidden` - Access denied (includes policy denies with `reason: "policy_denied"`)
- `405 Method Not Allowed` - Wrong HTTP method
- `429 Too Many Requests` - Rate limited (after 5 failed auth attempts)
- `500 Internal Server Error` - Server error
- `502 Bad Gateway` - Peer relay failed

---

## Rate Limiting

Failed authentication attempts are rate limited:
- **Max failures**: 5 attempts
- **Lock duration**: 3 minutes
- **Applies to**: Password and token authentication

---

## Security Features

1. **HMAC Signatures**: Peer-to-peer commands use HMAC-SHA256 signatures
2. **Nonce Protection**: Prevents replay attacks (30-second window)
3. **Rate Limiting**: Protects against brute force attacks (5 failures = 3 min lockout)
4. **TLS Support**: Optional HTTPS with certificate/key
5. **Remote HTTP Control**: Can disable remote HTTP access without TLS
6. **Token Revocation**: Tokens can be revoked at any time
7. **Dry Run Mode**: Test commands without executing them
8. **Action Policies**: Per-device allowances for fine-grained control
9. **Encrypted State**: Persistent state file is encrypted

### Security Documentation

- **[../docs/SECURITY.md](../docs/SECURITY.md)** - Security policy, vulnerability reporting, deployment best practices
- **[../docs/SECURITY_IMPROVEMENTS.md](../docs/SECURITY_IMPROVEMENTS.md)** - Security audit findings and recommended fixes
- **[../docs/CREDENTIAL_FLOW_ANALYSIS.md](../docs/CREDENTIAL_FLOW_ANALYSIS.md)** - Detailed analysis of how each auto-generated credential is used
- **[CONFIG_GUIDE.md](CONFIG_GUIDE.md)** - Security configuration options

### Reporting Security Issues

**DO NOT** open public GitHub issues for security vulnerabilities. See [../docs/SECURITY.md](../docs/SECURITY.md) for responsible disclosure guidelines.

### Known Security Alerts

See [../docs/SECURITY_IMPROVEMENTS.md](../docs/SECURITY_IMPROVEMENTS.md) for detailed security audit findings:

- **Critical (Alert #4)**: SSRF vulnerability in `/v1/peer/relay` - user-provided URLs need validation to block private IPs
- **Warning (Alerts #1-3)**: Weak password hashing using SHA256 - should migrate to bcrypt or Argon2id

### Security Recommendations

1. Use strong, unique passwords (16+ characters)
2. Enable TLS for any WAN/internet exposure
3. Use action policies to restrict destructive operations
4. Monitor rate limiting events in logs
5. Rotate tokens and passwords periodically
6. Review audit trail regularly
7. Keep `dry_run=true` until thoroughly tested
8. Follow deployment checklist in [../docs/SECURITY.md](../docs/SECURITY.md)

---

## Configuration Options

See `lumos-config.json` or environment variables:

| Config Key | Env Variable | Default | Description |
|------------|--------------|---------|-------------|
| `bind` | `LUMOS_BIND` | `:8080` | Listen address |
| `advertise_addr` | `LUMOS_ADVERTISE_ADDR` | auto | Address advertised to peers |
| `agent_id` | `LUMOS_AGENT_ID` | hostname | Unique agent identifier |
| `password` | `LUMOS_AGENT_PASSWORD` | required | Main password |
| `cluster_key` | `LUMOS_CLUSTER_KEY` | optional | Peer cluster key |
| `bootstrap_peers` | `LUMOS_BOOTSTRAP_PEERS` | `[]` | Initial peer list |
| `allow_wake_without_password` | `LUMOS_ALLOW_WAKE_WITHOUT_PASSWORD` | `false` | Allow wake without auth |
| `dry_run` | `LUMOS_DRY_RUN` | `true` | Test mode |
| `ui_user` | `LUMOS_UI_USER` | `lumos` | Web UI username |
| `ui_password` | `LUMOS_UI_PASSWORD` | same as password | Web UI password |
| `mdns_enabled` | `LUMOS_MDNS_ENABLED` | `true` | Enable mDNS discovery |
| `require_tls` | `LUMOS_REQUIRE_TLS` | `false` | Force HTTPS |
| `allow_insecure_remote_http` | `LUMOS_ALLOW_INSECURE_REMOTE_HTTP` | `false` | Allow remote HTTP |

---

## Examples

### Wake a device locally
```bash
curl -X POST http://localhost:8080/v1/command/wake \
  -H "X-Lumos-Password: your-password" \
  -H "Content-Type: application/json" \
  -d '{"mac":"04:D9:F5:39:13:46"}'
```

### Wake a device via relay
```bash
curl -X POST http://localhost:8080/v1/peer/relay \
  -H "X-Lumos-Password: your-password" \
  -H "Content-Type: application/json" \
  -d '{
    "target_agent_id": "LAPTOP",
    "action": "wake",
    "mac": "04:D9:F5:39:13:46"
  }'
```

### Scan network
```bash
curl -X POST http://localhost:8080/v1/ui/scan \
  -u "lumos:your-password" \
  -H "Content-Type: application/json" \
  -d '{"network":"192.168.1.0/24"}'
```

### Create auth token
```bash
curl -X POST http://localhost:8080/v1/auth/pair \
  -H "X-Lumos-Password: your-password" \
  -H "Content-Type: application/json" \
  -d '{"label":"My Phone"}'
```

---

## mDNS Discovery

When `mdns_enabled` is true, agents automatically:
- **Announce**: Broadcast presence on `_lumos-agent._tcp.local.`
- **Discover**: Find other agents on the local network
- **Auto-register**: Add discovered peers automatically

---

## Peer Sync

Agents with `bootstrap_peers` configured will:
- Register themselves every 30 seconds
- Exchange peer lists
- Maintain mesh network topology

---

*Generated: 2026-02-23*



