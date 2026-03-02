<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# Known Issues and Limitations

This file lists current operational and product limitations.

## Transport and Networking

- TLS is optional, not default-on for all deployments.
- Multi-network discovery is functional but still evolving for very large, segmented fleets.
- Relay target validation is hardened, but operational allowlisting/profile tooling is still limited.

## Product Surface

- Admin UX is currently web UI + Android app.
- Dedicated desktop GUI is roadmap, not shipped.
- Policy import/export for bulk fleet rollout is not implemented.
- Onboarding flow still has continuity friction in some scan -> pair -> save paths.

## Version and Compatibility

- App enforces minimum agent version floors for destructive actions.
- Runtime compatibility checks are strongest around destructive actions.
- Capability-level runtime gating across all surfaces is still evolving.
- Independent artifact versioning strategy is still being refined.

## Packaging and Distribution

- Windows/Linux installer packaging is not complete.
- Operator-facing verification UX/docs can still be improved.
- Google Play publication flow is planned but not yet live.
- Windows binary branding/metadata standardization is still in progress.

## Operations

- Some onboarding edge cases remain under refinement.
- Fleet-scale UI modes (location-first/network-first) are planned, not complete.

## Recommended Operator Workarounds

- Use token-first pairing and minimize password reuse.
- Keep `allow_insecure_remote_http` disabled unless required for local testing.
- For production or internet-adjacent environments, use trusted network controls and TLS.
- Track release/versioning docs before upgrading:
  - `docs/VERSIONING.md`
  - `docs/RELEASE_NOTES.md`
