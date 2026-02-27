<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Lumos Release Notes

Primary release-notes source for `publish-release.ps1`.

## Release Metadata

- Channel: `stable`
- Tag: `v1.0.0`
- Commit: `auto`
- Date (UTC): `2026-02-27`
- Compatibility baseline: app `v1.0.x` and agent `v1.0.x` patch line.

## Release Cut Checklist

- [x] Metadata block updated.
- [x] Validation gates passed (`go test`, `go vet`, `flutter analyze`, `flutter test`).
- [x] Release artifacts built and verified.
- [x] CI/CD and signing behavior reflected accurately.
- [x] Documentation references reviewed.

## First Stable Release Summary (v1.0.0)

`v1.0.0` is the first stable Lumos cut that formalizes the LAN-first remote power-control stack as:
- `lumos-agent` (Go, Windows/Linux) for control APIs, relay, policy, and web admin.
- `lumos_app` (Flutter Android) for discovery, pairing, token management, and daily operations.

This release aligns release policy, docs metadata, and runtime compatibility signaling for the `1.0.x` line.

## What Ships in v1.0.0

### Agent
- Token + password auth with scope-aware tokens (`power-admin`, `wake-only`, `read-only`).
- Policy CRUD APIs and deterministic policy-deny behavior.
- Peer management APIs and web UI peer registration with verification.
- Safe-mode confirmation/cooldown model for destructive actions.
- `/v1/status` version/capability reporting with compatibility range signaling.
- First-run auto-generated credentials (`password`, `cluster_key`, `ui_password`, `shutdown_key`, `state_encryption_salt`).

### Android App
- mDNS and scan-based discovery.
- Token-first pairing and per-device token management.
- Agent policy management UI.
- Peer management UI.
- Release-aware version visibility in app surfaces.
- Runtime compatibility checks before destructive actions.

### Build Artifacts
- `build/windows/agent.exe`
- `build/linux/agent-linux-amd64`
- `build/android/app-release.apk` (when APK is included in release workflow)

## CI/CD and Release Guarantees (v1.0.0)

From `.github/workflows/ci.yml`, `.github/workflows/release.yml`, and release scripts:
- CI validates version/docs policy and runs Go + Flutter checks on `main`/PR.
- Tag normalization is enforced by channel (`stable` uses `v*`; prerelease uses non-`v`).
- Release workflow auto-updates docs metadata before publish.
- Compatibility validation is enforced against `release-policy.json`.
- Release metadata/docs version are validated before upload.
- Local real publish is blocked; `publish-release.ps1` allows local `-DryRun` only.
- APK signing is CI-driven via protected release secrets, with signer continuity validation.
- `include_apk=false` supports agent-only emergency releases.
- Release assets include checksums, SBOM outputs, provenance attestations, and checksum signature/certificate.

## Documentation Baseline Used for This Release

- `README.md` for high-level product scope.
- `docs/VERSIONING.md` for tag/channel and compatibility policy.
- `docs/SECURITY.md`, `docs/SECURITY_IMPROVEMENTS.md`, and credential analysis docs for security posture.
- `docs/FUTURE.md` for planned post-v1 work.

