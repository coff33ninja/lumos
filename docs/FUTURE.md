<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Lumos Future Roadmap

This file tracks planned work that is not fully implemented yet.

## 1. Desktop UX Evolution (Web GUI -> Desktop GUI)

Goal: move from browser-only local UI to a first-class desktop application while keeping API parity with mobile.

Planned:
- Desktop GUI app for Windows and Linux (initially as a local control client for one agent).
- Authenticated hive management from desktop:
  - after authenticating to peer agents, view/edit peer registrations and policy allowances.
  - parity with mobile policy + peer-management flows.
- Progressive migration strategy:
  - Phase 1: desktop wrapper/client over existing HTTP API.
  - Phase 2: richer local desktop onboarding and diagnostics.
  - Phase 3: optional replacement of web-only admin workflows.

## 2. Fleet and Hive Management

Goal: operate many agents across LAN, VPN, and mixed routed networks.

Planned:
- Network topology model (site/zone/subnet/VPN) and routing-aware relay fallback.
- Grouping/tag/location filters in app and desktop client.
- Bulk policy operations:
  - import/export JSON policy profiles.
  - apply policy templates to multiple agents.
- Better authenticated hive operations:
  - edit peer/hive metadata from mobile and desktop after verification.
  - clearer relay-path visibility and failure reasons.

## 3. Security Hardening (Next Major Pass)

Goal: shift to secure-by-default behavior for production deployments.

Planned:
- TLS-first deployment guidance and stricter defaults for non-local traffic.
- Optional token expiration and stricter rotation lifecycle.
- Expanded audit/security telemetry and suspicious-activity alerts.
- Additional transport hardening and service-level OS hardening defaults.

## 4. Distribution and Operations

Goal: make deployment and updates simple for non-developer operators.

Planned:
- Windows installer (`.msi`/`.exe`) with service install/uninstall/upgrade.
- Linux packaging (`.deb`/`.rpm`) with `systemd` integration.
- Signed downloads, checksums, and clearer upgrade guidance.
- In-app and desktop update prompts tied to compatibility rules.
- Windows binary branding and metadata:
  - embed app icon/logo in `agent.exe` so Explorer shows Lumos identity.
  - embed file version metadata (product name, company/author, description, copyright).
- Android package metadata parity:
  - keep developer/publisher info consistent with desktop binary metadata.

## 5. Mobile UX and Platform Features

Goal: improve day-to-day control and large-fleet usability.

Planned:
- Google Play Store distribution path:
  - planned publication to Google Play after stability gates are met.
  - staged track rollout (internal -> closed -> production).
  - app signing/keystore and versioning process hardened for store delivery.
- Location-assisted discovery mode (optional permissioned feature).
- Android home-screen shortcuts/widgets ("charms") for one-tap actions.
- Improved onboarding continuity and troubleshooting hints.
  - remove current back-navigation dependency after scan->select->pair.
  - add explicit forward progression (`Next` / `Continue`) from successful onboarding to saved-device list.
  - support multi-select onboarding completion without forcing manual return to add-device screen.
- Better compatibility UX when agent version is below required command floor.

## 6. Release Engineering and CI/CD

Goal: predictable, auditable releases.

Planned:
- Mature RC -> stable promotion process (`vX.Y.Z-rc.N` then `vX.Y.Z`).
- Expanded post-release smoke tests (artifact + API shape + version metadata checks).
- Signed artifacts for APK and agent binaries as part of production release readiness.
- App/agent compatibility gating and mixed-version protections:
  - enforce explicit APK->agent compatibility checks before destructive commands and peer relay actions.
  - publish and validate compatibility table in CI/release policy checks (supported and blocked version pairs).
  - fail release jobs when compatibility policy is missing for changed API/capability surfaces.
- Decoupled artifact versioning with coordinated ship rules:
  - allow independent APK and binary patch versions when no protocol break exists.
  - require compatibility metadata update when only one side is bumped.
  - produce channel-specific update prompts (for example: "update app", "update agent", or "both required").

## 7. Candidate v1.0.0 Exit Criteria

- Stable release flow rehearsed on at least one full RC cycle.
- Security hardening items for pre-v1 scope closed or explicitly accepted.
- Android + Windows + Linux artifacts validated from release assets.
- Known limitations documented and acknowledged.

## 8. Remote Desktop and Widgets Expansion

Goal: add secure remote desktop capability on top of agent/app while preserving current power-control reliability.

### Architecture Direction

- Split responsibilities into two planes:
  - Control plane: existing power/status/policy APIs.
  - Data plane: remote desktop stream/input/clipboard sessions.
- Keep capability-driven behavior:
  - app/desktop show remote controls only if agent advertises support.
- Keep parity across clients:
  - Android app and desktop client should consume the same policy/capability model.

### Planned Capabilities

- Agent capability flags in `/v1/status`:
  - `rdp_stream`
  - `rdp_input`
  - `rdp_clipboard`
  - `rdp_file_transfer` (later phase)
- Policy scopes/allowances:
  - `remote_view`
  - `remote_control`
  - `clipboard_read`
  - `clipboard_write`
  - `file_transfer` (later phase)
- Default policy for remote desktop scopes: deny-by-default.

### Security and Trust Requirements

- Encrypted transport for remote sessions (`wss`/secure session channel).
- Session-scoped short-lived credentials for remote session start.
- Explicit device-side approval options for first-time remote control.
- Full session audit events:
  - initiator, target, start/end timestamps, action class (view/control).
- Relay path restrictions and allowlists for cross-network operation.

### UX and Product Flow

- Mobile app:
  - one-tap "Connect" from device card.
  - view-only vs control mode switch.
  - clear disconnect/emergency input-stop.
- Desktop client:
  - multi-monitor selection.
  - quality presets (latency/fps/resolution).
  - keyboard/mouse capture modes.
- Onboarding:
  - if unsupported, display capability reason + minimum required versions.

### Widget Support Plan (Android)

- Per-device widgets for:
  - Wake
  - Shutdown/Reboot/Sleep
  - Remote session deep-link launch
- Add optional guardrails for sensitive actions:
  - biometric confirmation or secure unlock requirement before destructive actions.

### CI/CD and Compatibility Gating

- Add protocol compatibility matrix:
  - app version <-> agent version <-> remote protocol version.
- CI release gates must fail when:
  - protocol/capability changed without matrix update.
  - unsupported version combinations are not explicitly documented.
- Channel-aware rollout:
  - remote desktop features can ship behind beta channel first.

### Phased Delivery

1. Phase A: API/policy foundation
- capability flags + policy schema + deny-by-default enforcement.

2. Phase B: view-only remote session
- stream-only mode from agent to app/desktop.

3. Phase C: interactive control
- keyboard/mouse input and clipboard with policy checks.

4. Phase D: relay and multi-network hardening
- cross-agent relay path and route-aware fallback behavior.

5. Phase E: widgets and operational polish
- Android widgets, better recovery UX, richer audit/reporting.

### Acceptance Criteria (Initial Rollout)

- Remote session can be started and terminated from both app and desktop.
- View-only and control modes are policy-gated and auditable.
- Unsupported versions are blocked with explicit compatibility errors.
- No regression in existing wake/power flows during remote feature rollout.

## 9. Transparency and Project Metadata

Goal: make project state, release intent, and operational trust signals easy to verify for users and contributors.

Planned:
- Expand transparency docs with a single "project status board" view:
  - current stable release
  - supported version ranges
  - known high-priority risks
  - active roadmap milestones
- Add a concise "what changed and why" summary for each release in addition to technical release notes.
- Maintain public security posture notes:
  - open hardening items
  - mitigations currently in place
  - accepted risks with rationale
- Improve project metadata consistency across README, release pages, and docs:
  - maintainer/contact details
  - support paths
  - licensing and attribution links
- Publish a lightweight trust checklist for operators:
  - verification of release checksums/signatures
  - APK signer continuity checks
  - compatibility check steps before upgrade



