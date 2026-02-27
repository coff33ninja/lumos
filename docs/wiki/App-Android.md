<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Android App

## Responsibilities

- Device discovery and onboarding
- Password-to-token pairing bootstrap
- Token-based day-to-day control
- Device state cache and UI control flows

## Main Capabilities

- Scan local and configured networks
- Add/delete saved agents
- Wake, shutdown, reboot, sleep actions
- Token management (rotate/revoke/re-pair scope)
- Release/version info pull from GitHub release metadata

## Build

```powershell
cd lumos_app
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Notes

- Current core flow does not require special runtime permissions.
- Future optional permissions (for richer network targeting/automation) are tracked in `docs/FUTURE.md`.



