<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# Credential Flow Analysis (Implementation Snapshot)

This document records implemented credential flows only.
Historical issue narratives are intentionally excluded.

## Credential Set

The agent currently manages these credentials:
- `password` (bootstrap auth credential)
- `ui_password` (web UI auth credential)
- `cluster_key` (peer trust key)
- `shutdown_key` (internal shutdown operation key)
- `state_encryption_salt` (state encryption derivation salt)

## Generation and Storage

- On first run, credentials are auto-generated when missing.
- Runtime configuration is stored in `lumos-agent/lumos-config.json`.
- Runtime state is stored in `lumos-agent-state.json` on each host.
- Runtime state/config artifacts are excluded from release assets.

## Authentication Flows

### Password Bootstrap
1. Client authenticates with password for initial pairing/admin actions.
2. Agent validates against configured bcrypt-backed credential path.

### Token Operational Flow
1. Pairing returns token(s) with explicit scope.
2. Normal command/control uses token headers.
3. Agent enforces scope + policy before command execution.

### UI Flow
1. Web UI uses `ui_password` for authentication.
2. UI actions flow through authenticated UI handlers.

### Peer Flow
1. Agents trust peers through `cluster_key` + relay validation.
2. Peer operations are constrained by policy and registration state.

## Lifecycle Expectations

- Rotate credentials during operational maintenance windows.
- Revoke/rotate tokens when ownership or device trust changes.
- Keep cluster key consistent only across trusted peers.
- Keep credentials out of git, release assets, and public logs.

## Production-Line Fill Later

Add evidence sections when production operations are formalized:
- rotation cadence and owner mapping
- recovery playbooks
- credential lifecycle metrics
- change-audit references
