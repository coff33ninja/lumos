<!-- lumos-docs-release: tag=v1.1.0; updated_utc=2026-03-01 -->

# Lumos Versioning and Release Method

This document defines how Lumos versions are named, validated, and published.

## Scope

- `lumos-agent` (Go binaries: Windows/Linux)
- `lumos_app` (Flutter APK)
- single-repo coordinated releases

## Version Policy Source of Truth

- `release-policy.json` is the canonical source for:
  - `min_agent_version_for_power`
  - `allowed_version_bump_channels`
  - `compatibility_matrix` (app range ↔ agent range)
- Current value:
  - `min_agent_version_for_power = v1.0.0`
- Validation is enforced by:
  - `scripts/validate-version-policy.ps1`
  - `scripts/validate-release-compatibility.ps1`
  - CI workflow (`.github/workflows/ci.yml`)

## Tag Strategy

Use these tag formats:

1. Release candidate (required before stable)
- Format: `MAJOR.MINOR.PATCH-rc.N` (no `v` prefix)
- Example: `1.0.0-rc.1`
- Purpose: dry-run a full release flow with production-like artifacts.

2. Stable release
- Format: `vMAJOR.MINOR.PATCH`
- Example: `v1.0.0`
- Purpose: official public release after RC verification.

3. Beta snapshot (optional, fast iteration)
- Format: `MAJOR.MINOR.PATCH-beta.<stamp>` (no `v` prefix)
- Example: `1.0.1-beta.202602271845`
- Purpose: frequent test drops while features are still moving.

4. Unreleased snapshot (optional, fast iteration)
- Format: `MAJOR.MINOR.PATCH-unreleased.<stamp>` (no `v` prefix)
- Example: `1.0.1-unreleased.202602271900`
- Purpose: internal snapshots that should stay prerelease.

## Release Channels

`publish-release.ps1` channels:

- `stable`: non-prerelease GitHub release
- `beta`: prerelease GitHub release
- `unreleased`: prerelease snapshot

## Push History Since First Stable (v1.0.0)

Main branch pushes since the first stable release:

- `2026-02-27` `e3be03e` Allow dirty tree during CI release publish after docs stamp
- `2026-02-27` `0db38be` Add Android signing secret bootstrap and enforce APK signing config
- `2026-02-27` `cf02f5e` Support generated keystore mode for Android signing secret setup
- `2026-02-27` `1a38fbe` Update Android signing cert fingerprint policy
- `2026-03-01` `edfecc7` Create `codeql.yml`
- `2026-03-01` `2643022` CodeQL Java/Kotlin autobuild root targeting update
- `2026-03-01` `2b284cd` CodeQL Android symlink shim for autobuild detection
- `2026-03-01` `b0bc876` CodeQL Flutter `local.properties` bootstrap for Android build
- `2026-03-01` `be81aff` CodeQL Java/Kotlin `flutter pub get` pre-step

## Required Pre-Cut Inputs

Before every tag cut:

- Update `docs/RELEASE_NOTES.md` metadata block:
  - channel
  - tag
  - commit
  - date (UTC)
- Complete release checklist in `docs/RELEASE_NOTES.md`.
- Keep `docs/RELEASE_CHECKLIST.md` aligned with current process.

`publish-release.ps1` enforces this by failing when placeholders/checklist are not completed.

## Validation Gates

All must pass before publishing:

1. Agent
- `cd lumos-agent`
- `go test ./...`
- `go vet ./...`

2. App
- `cd ../lumos_app`
- `flutter analyze`
- `flutter test`

3. Build artifacts
- `./rebuild-all.ps1`
- Must produce:
  - `build/android/app-release.apk`
  - `build/windows/agent.exe`
  - `build/linux/agent-linux-amd64`

4. Docs version metadata
- `./scripts/validate-docs-version.ps1 -ExpectedTag <tag> -Channel <channel>`
- Must match `docs/docs-version.json -> release_tag`.

One-command preflight:

```powershell
./scripts/release-doctor.ps1 -ExpectedTag v1.1.0 -Rebuild
```

## Automatic Changelog Generation

Every release automatically includes a detailed changelog of all commits since the previous release:

- Commits are grouped by type (Features, Bug Fixes, Security, Documentation, etc.)
- Each entry includes commit hash, message, author, and date
- Supports conventional commit format (feat:, fix:, docs:, etc.)
- Falls back to keyword detection for non-conventional commits

### When It Happens

**Automatic (new releases):**
- Runs during `publish-release.ps1` or GitHub Actions workflow
- Generates changelog from previous tag to current tag
- Appends to release notes automatically

**Manual (existing releases):**
```powershell
# Update all old releases with changelogs
./scripts/update-existing-releases.ps1 -AllReleases -DryRun
./scripts/update-existing-releases.ps1 -AllReleases
```

**Preview before releasing:**
```powershell
./scripts/preview-changelog.ps1 -ShowStats
```

### Handling Release Reverts

If you need to revert a release:

```powershell
./scripts/handle-release-revert.ps1 -RevertedTag v1.2.0 -RollbackToTag v1.1.0
```

This will:
1. Delete the bad release from GitHub
2. Delete the git tag
3. Verify the rollback release has proper changelog

## Publish Commands

From repo root:

1. RC cut
```powershell
./publish-release.ps1 -Channel beta -Tag 1.1.0-rc.1 -Title "Lumos 1.1.0-rc.1" -Rebuild
```

2. Stable cut
```powershell
./publish-release.ps1 -Channel stable -Tag v1.1.0 -Title "Lumos v1.1.0" -Rebuild
```

3. Beta snapshot
```powershell
./publish-release.ps1 -Channel beta -Rebuild
```

Commit changelog is automatically generated and included in release notes.

## Asset Policy

Only upload binary artifacts:

- `app-release.apk`
- `agent.exe`
- `agent-linux-amd64`

Never upload runtime config/state files:

- `lumos-config.json`
- `lumos-agent-state.json`

## Compatibility Matrix Rule

Release body must include a compatibility matrix (auto-appended by `publish-release.ps1`) with:

- app version (`lumos_app/pubspec.yaml`)
- agent tag/version
- commit hash

Policy enforcement:
- `publish-release.ps1` validates `release-policy.json` compatibility matrix before upload.
- `scripts/release-doctor.ps1` validates compatibility when `-ExpectedTag` is provided.
- `release-publish` workflow validates compatibility matrix against release tag/channel before publish.
- Patch-line skew is allowed when the matrix rule permits it (for example app `v1.0.1` with agent `v1.0.0`).
- Runtime enforcement: agent publishes `compatibility.app_range` via `/v1/status`, and the app enforces that range before destructive power actions.

## Android Signing Continuity

Android in-place updates require the same signing certificate for every APK release.

- `lumos_app/android/app/build.gradle` now requires release keystore config for release tasks.
- `rebuild-all.ps1` can re-sign `build/android/app-release.apk` with `uber-apk-signer` in CI.
- Release flows run `scripts/validate-apk-signing.ps1` and reject debug-signed APKs.
- Optional policy pin: `release-policy.json -> android_signing.required_cert_sha256`.

Release keystore source:

1. GitHub Actions environment variables (`LUMOS_ANDROID_STORE_FILE`, `LUMOS_ANDROID_STORE_PASSWORD`, `LUMOS_ANDROID_KEY_ALIAS`, `LUMOS_ANDROID_KEY_PASSWORD`)

GitHub Actions release workflow derives these env vars from repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Bootstrap command:

```powershell
./scripts/setup-android-signing-secrets.ps1 `
  -Repo coff33ninja/lumos `
  -Environment release `
  -KeystorePath "C:\path\to\release.jks" `
  -KeystorePassword "<store-password>" `
  -KeyAlias "<key-alias>" `
  -KeyPassword "<key-password>"
```

CI signing normalization:

- `release-publish` exports `LUMOS_USE_UBER_APK_SIGNER=true` and `LUMOS_UBER_APK_SIGNER_VERSION=1.3.0`.
- `rebuild-all.ps1` downloads `uber-apk-signer-1.3.0.jar`, verifies SHA-256 from the upstream release checksum file, and re-signs in place with `--allowResign --overwrite`.
- Final release gate still validates signer continuity with `scripts/validate-apk-signing.ps1`.

Local release signing is intentionally blocked. Release APKs must be produced in GitHub Actions.

Recommended protection model (enabled for this repo):

- Use GitHub Environment `release` for signing secrets.
- Keep Android signing secrets as environment secrets (not plain repo secrets).
- Add required reviewers in `Settings -> Environments -> release` so publish jobs require explicit approval.

Important trust distinction:

- GitHub checksums/cosign signatures prove artifact provenance after upload.
- Android install/update acceptance is determined by the APK signing certificate inside the APK.
- Both should be validated; only the APK signer controls whether an existing install can be upgraded in-place.

## CI/CD Interaction

- `.github/workflows/version-bump-tag.yml` watches `lumos_app/pubspec.yaml` on `main`:
  - derives `<version>` from `version:` (ignoring build suffix after `+`)
  - creates/pushes tag only if it does not already exist
  - stable pubspec versions produce `v<version>` tags
  - prerelease pubspec versions (`-beta`, `-rc`, `-unreleased`) produce non-`v` tags
- `.github/workflows/release.yml` supports two release entry paths:
  1. Automatic release on tag push matching `v*` or plain semver/prerelease tags (channel inferred from tag suffix).
2. Manual release via `workflow_dispatch` for any semver tag, with explicit channel selection (`stable`, `beta`, `unreleased`):
   - `stable` auto-normalizes to `v*` tags (example input `1.1.1` becomes `v1.1.1`)
   - `beta`/`unreleased` auto-normalize to no `v` prefix
- `release-publish` also supports `include_apk` input:
  - `true` (default): build/publish signed APK + agent binaries
  - `false`: publish agent binaries only (Windows/Linux), skip APK
- Stable manual runs use non-suffixed semver and are normalized to `v` tags (for example input `1.1.1` publishes as `v1.1.1`).
- RC/beta/unreleased tags with suffixes (for example `1.2.0-rc.1`) are published as prereleases on push; manual dispatch can still be used to override channel.
- Local execution of `publish-release.ps1` is supported only with `-DryRun`. Real publish/sign flows must run in GitHub Actions.
- Promote to next stable semver tag after RC/patch validation passes.

## Documentation Version Control

- `docs/docs-version.json` is the docs release marker.
- `scripts/update-release-docs.ps1` auto-refreshes release-facing docs metadata (tag/channel/date) and stamps Markdown docs with a release marker comment.
- `scripts/validate-docs-version.ps1` is enforced in:
  - `ci-validate` (format/sanity)
  - `release-publish` (must match release tag/channel)
  - `publish-release.ps1` and `scripts/release-doctor.ps1` preflight checks

### Manual patch release example

1. Push the target code to `main` (or tagged commit).
2. Open GitHub Actions -> `release-publish` -> `Run workflow`.
3. Set:
   - `tag = 1.1.1` (workflow normalizes to `v1.1.1` for stable)
   - `channel = stable`
   - `include_apk = true` (or `false` for agent-only emergency release)
4. Run and verify release assets/signatures on the generated release page.

## Recommended v1 sequence

1. Cut `1.0.0-rc.1` and validate on Android + Windows + Linux.
2. Fix regressions if found and repeat RC (`rc.2`, `rc.3`, ...).
3. Cut `v1.0.0` stable when no blocking issues remain.




