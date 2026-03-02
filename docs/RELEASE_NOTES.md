<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# Lumos Release Notes

Primary release-notes source for `publish-release.ps1`.

## Release Metadata

- Channel: `stable`
- Tag: `v1.2.0`
- Commit: `auto`
- Date (UTC): `2026-03-02`
- Compatibility baseline: app `v1.1.x` and agent `v1.1.x` patch line.

## Release Cut Checklist

- [x] Metadata block updated.
- [x] Validation gates passed (`go test`, `go vet`, `flutter analyze`, `flutter test`).
- [x] Release artifacts built and verified.
- [x] CI/CD and signing behavior reflected accurately.
- [x] Documentation references reviewed.

## Push History Since First Stable (v1.0.0)

Main branch pushes between `v1.0.0` and current `v1.1.0` prep:

- `2026-02-27` `e3be03e` Allow dirty tree during CI release publish after docs stamp
- `2026-02-27` `0db38be` Add Android signing secret bootstrap and enforce APK signing config
- `2026-02-27` `cf02f5e` Support generated keystore mode for Android signing secret setup
- `2026-02-27` `1a38fbe` Update Android signing cert fingerprint policy
- `2026-03-01` `edfecc7` Create `codeql.yml`
- `2026-03-01` `2643022` CodeQL Java/Kotlin autobuild root targeting update
- `2026-03-01` `2b284cd` CodeQL Android symlink shim for autobuild detection
- `2026-03-01` `b0bc876` CodeQL Flutter `local.properties` bootstrap for Android build
- `2026-03-01` `be81aff` CodeQL Java/Kotlin `flutter pub get` pre-step

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

  - app: `v1.2.x` patch line supported

  - agent: `v1.2.x` patch line supported


