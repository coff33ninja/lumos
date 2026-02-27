<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Signing and Key Management

This document defines artifact signing expectations and key custody practices.

## Current Implementation

- Release workflow always publishes:
  - binary artifacts
  - `checksums.txt` (SHA-256)
  - lightweight SBOM outputs
- Release workflow signs checksums using keyless cosign (OIDC) and uploads:
  - `checksums.txt.sig`
  - `checksums.txt.pem`

## Required Workflow Permissions

- `id-token: write`
- `contents: write`

These are already configured in `.github/workflows/release.yml`.

## Key Custody Guidance

- Keep private signing keys outside the repository.
- Use organization/repo secrets for CI access.
- Restrict secret access to release maintainers only.
- Rotate signing keys on schedule or after any suspected exposure.

Note:
- Current workflow uses keyless signing, so no private key secret is required for checksum signatures.
- If key-pair signing is introduced later, define and protect those secrets explicitly.

## Rotation and Revocation

- Keep an internal key inventory with:
  - key ID/fingerprint
  - creation date
  - owner
  - intended use
- On rotation:
  - update CI secrets
  - announce effective date in release notes
- On compromise:
  - revoke key immediately
  - rotate and re-sign from trusted environment
  - publish incident note in release changelog



