<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# Security and Trust

## Auth Model

- Bootstrap auth: password
- Operational auth: token (`X-Lumos-Token`)
- Token scopes:
  - `power-admin`
  - `wake-only`
  - `read-only`

## Guardrails

- Rate limiting and lockout on repeated auth failures
- Optional TLS/HTTPS deployment path
- Peer trust via cluster/peer key model
- Policy allow/deny checks for command endpoints

## Operator Guidance

- Prefer TLS where possible
- Keep tokens scoped to least privilege
- Rotate credentials periodically
- Restrict exposed ports/firewall rules

## Canonical Security Docs

- `docs/SECURITY.md`
- `docs/SECURITY_IMPROVEMENTS.md`
- `docs/CREDENTIAL_FLOW_ANALYSIS.md`
- `docs/CREDENTIAL_VALIDATION_SUMMARY.md`




