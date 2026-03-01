<!-- lumos-docs-release: tag=v1.1.0; updated_utc=2026-03-01 -->

# Releases and Versioning

Lumos versioning and release process is defined in `docs/VERSIONING.md`.
Current stable target: `1.1.0`.

## Trigger Model

- Automatic release on tag push `v*` (channel inferred from tag suffix)
- Manual release (`workflow_dispatch`) for explicit channel overrides and hotfix control:
  - `stable`: auto-prepends `v` if omitted
  - `beta`/`unreleased`: auto-removes leading `v`
- Manual release also supports `include_apk` for agent-only fallback cuts when APK signing is unavailable.
- Docs release marker (`docs/docs-version.json`) is validated against tag/channel during release workflow.
- Release workflow auto-runs `scripts/update-release-docs.ps1` so docs metadata stays aligned with the selected release tag.

## Release Artifacts

- `app-release.apk`
- `agent.exe`
- `agent-linux-amd64`
- checksums/signature and dependency manifests

Runtime JSON files are excluded from release assets.

## Android Update Reliability

- APK updates require a consistent signing certificate across all releases.
- Release builds are CI-only in GitHub Actions (local release signing is blocked).
- Release keystore material is injected from GitHub Environment secrets (`release`) into CI env vars at build time.
- CI release builds re-sign the packaged APK using `uber-apk-signer` (currently `1.3.0`) before upload.
- Release automation validates APK signer certificate before upload.
- Optional hard pin: set `android_signing.required_cert_sha256` in `release-policy.json`.

## Local Preflight

```powershell
.\scripts\release-doctor.ps1 -ExpectedTag v1.2.1 -Rebuild
```

## Publish Script

```powershell
.\publish-release.ps1 -Channel stable -Tag v1.2.1 -Title "Lumos v1.2.1" -Rebuild
```




