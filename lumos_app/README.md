<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Lumos App (Android)

Flutter Android client for discovering Lumos agents, pairing tokens, and controlling power actions.

## Current Scope

- Android-focused client (APK distribution in this repository).
- Discovery:
  - mDNS (`_lumos-agent._tcp`)
  - server-side scan via authenticated agent
  - fallback direct scan
- Auth model:
  - password used once for pairing
  - long-lived token used for day-to-day actions
- Device actions:
  - wake
  - shutdown
  - reboot
  - sleep
- Agent management:
  - token management (list, rotate, revoke)
  - policy CRUD (`/v1/policy/*`)
  - peer/hive registration management (`/v1/ui/peer/*`)

## Build

From `lumos_app/`:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK output:
- `build/app/outputs/flutter-apk/app-release.apk`

## Runtime Notes

- Devices and tokens are persisted in app-local storage through `SharedPreferences`.
- `flutter_secure_storage` exists in dependencies but is not yet the primary persistence path.
- Minimum supported agent version checks are enforced for destructive actions in app logic.

## Key Screens

- `home_screen.dart`
- `add_device_screen.dart`
- `scan_network_screen.dart`
- `token_management_screen.dart`
- `agent_policy_screen.dart`
- `peer_management_screen.dart`
- `about_screen.dart`

## API Usage

Primary endpoints used by the app:
- `GET /v1/status`
- `POST /v1/auth/pair`
- `GET /v1/auth/token/list`
- `POST /v1/auth/token/rotate`
- `POST /v1/auth/token/revoke`
- `POST /v1/auth/token/self/revoke`
- `POST /v1/command/wake`
- `POST /v1/command/power`
- `GET /v1/policy/state`
- `POST /v1/policy/*`
- `POST /v1/ui/peer/upsert`
- `POST /v1/ui/peer/delete`
- `GET /v1/events` (WebSocket)

## Related Docs

- `../README.md`
- `../docs/KNOWN_ISSUES_AND_LIMITATIONS.md`
- `../docs/FUTURE.md`
- `../docs/VERSIONING.md`



