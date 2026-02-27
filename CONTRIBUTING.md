<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Contributing to Lumos

Thanks for contributing. Keep changes focused, testable, and documented.

## Development Setup

1. Clone the repo and open at root.
2. Install prerequisites:
   - Go 1.26.0
   - Flutter stable SDK
   - Android SDK (for APK work)
3. Run checks before commit:
   - Agent:
     - `cd lumos-agent`
     - `go test ./...`
     - `go vet ./...`
   - App:
     - `cd ../lumos_app`
     - `flutter analyze`
     - `flutter test`

## Pull Request Guidelines

- Keep PRs scoped to a single concern.
- Update docs when behavior, API, or operator workflow changes.
- Include test evidence in PR description.
- Do not commit secrets, local state files, or generated runtime configs.

## Release-Related Changes

- Follow:
  - `docs/VERSIONING.md`
  - `docs/RELEASE_CHECKLIST.md`
- Keep `docs/RELEASE_NOTES.md` metadata/checklist accurate before release cuts.

## Security Reports

Do not file public issues for vulnerabilities. Use private reporting:
- See `docs/SECURITY.md`.



