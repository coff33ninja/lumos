<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Release / Signing / Auto-Update Plan

## Code Signing (Placeholder)

- Windows: sign `lumos-agent.exe` and `lumos-tray.exe` with Authenticode certificate in CI.
- macOS: sign and notarize release artifacts.
- Linux: publish checksums and detached signatures.

## Auto-Update (Placeholder)

- Agent: poll signed manifest endpoint and apply staged update on restart.
- Tray: check release channel and prompt before downloading signed binaries.
- Rollback: keep previous binary and state snapshot for fast fallback.



