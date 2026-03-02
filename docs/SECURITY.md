<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# Security Policy

This document is intentionally maintained as a clean baseline for initial repository publication.

## Supported Versions

Security fixes target the latest maintained code line.

| Version | Supported |
| --- | --- |
| Latest (`main`) | :white_check_mark: |
| Older tags | :x: |

## Reporting a Vulnerability

Do not open public issues for vulnerabilities.

Report privately through:
- GitHub Security Advisories (Security tab -> Report a vulnerability)
- Maintainer security email (to be finalized)

## Security Issues Register

Security issues go here:
- `docs/SECURITY_IMPROVEMENTS.md`

Current state:
- Register is intentionally empty at baseline.
- Populate during production hardening and ongoing operations.

## Production-Line Design Strategy

When filling security records later, follow this sequence:
1. Intake: capture report source, affected component, and reproducibility.
2. Triage: assign severity, impact, and ownership.
3. Containment: apply temporary mitigation if needed.
4. Remediation: implement code/config/docs fix.
5. Verification: validate fix with tests and manual checks.
6. Release: publish fix with release note reference.
7. Closure: record evidence and residual risk decision.

## Security Baseline (Implemented)

- Token-first operational auth model.
- Scoped token authorization (`power-admin`, `wake-only`, `read-only`).
- Safe-mode safeguards for destructive actions.
- Audit trail and policy enforcement paths.
- Optional TLS deployment path.

## Additional References

- `docs/SIGNING_AND_KEYS.md`
- `docs/VERSIONING.md`
- `docs/RELEASE_NOTES.md`

---

**Last Updated**: 2026-02-27

