<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# Lumos Documentation

This folder contains project-level operational and security documentation.

## Core Docs

- `VERSIONING.md` - canonical tag/channel/versioning and release-cut method
- `KNOWN_ISSUES_AND_LIMITATIONS.md` - current operational and product limits
- `FUTURE.md` - roadmap and planned scope (including desktop GUI evolution)
- `SECURITY.md` - security policy, disclosure process, and deployment guidance
- `SIGNING_AND_KEYS.md` - artifact signing flow and key custody/rotation guidance
- `SECURITY_IMPROVEMENTS.md` - tracked security gaps and remediation priorities
- `CREDENTIAL_FLOW_ANALYSIS.md` - credential usage flow analysis
- `CREDENTIAL_VALIDATION_SUMMARY.md` - validation summary of generated credentials
- `RELEASE_NOTES.md` - release notes source used by `publish-release.ps1`
- `RELEASE_CHECKLIST.md` - release readiness checklist
- `docs-version.json` - docs release version marker validated during CI/release
- `scripts/update-release-docs.ps1` - auto-updates release metadata and global docs release stamp
- `PEER_MANAGEMENT_IMPLEMENTATION.md` - peer management feature notes
- `wiki/` - GitHub Wiki source pages (sync via `scripts/publish-wiki.ps1`)
- GitHub Action sync: `.github/workflows/wiki-sync.yml` (auto-publishes wiki on doc changes)

## Maintainer Notes

- Keep links relative to this folder for inter-doc references.
- Keep root `README.md` high-level; detailed docs should live here.
- Update `RELEASE_NOTES.md` and `RELEASE_CHECKLIST.md` before stable release tags.
- Release workflow auto-updates docs metadata via `scripts/update-release-docs.ps1`; use the same script locally when preparing manual release commits.
- Follow `VERSIONING.md` for RC/stable tag flow and artifact upload policy.
- Keep `KNOWN_ISSUES_AND_LIMITATIONS.md` and `FUTURE.md` updated when behavior or priorities change.
- Keep `docs/wiki/*.md` in sync with architecture/ops/security/release changes before publishing wiki updates.




