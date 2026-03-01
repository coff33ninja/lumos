<!-- lumos-docs-release: tag=v1.1.0; updated_utc=2026-03-01 -->

# Lumos

![Lumos Logo](branding/lumos-logo-app.svg)
[![Stable Release](https://img.shields.io/github/v/release/coff33ninja/lumos?display_name=tag&sort=semver)](https://github.com/coff33ninja/lumos/releases/latest)
[![CI Validate](https://github.com/coff33ninja/lumos/actions/workflows/ci.yml/badge.svg)](https://github.com/coff33ninja/lumos/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-1c7ed6)](LICENSE)
[![Top Language](https://img.shields.io/github/languages/top/coff33ninja/lumos)](https://github.com/coff33ninja/lumos)
[![Language Count](https://img.shields.io/github/languages/count/coff33ninja/lumos)](https://github.com/coff33ninja/lumos)
[![LAN First](https://img.shields.io/badge/network-LAN--first-0b7285)](docs/README.md)
[![Self Hosted](https://img.shields.io/badge/model-self--hosted-2f9e44)](docs/README.md)
[![No Mandatory Cloud](https://img.shields.io/badge/cloud-not%20required-495057)](docs/README.md)

Lumos is a LAN-first remote power-control stack:

- `lumos-agent`: Go service for Wake-on-LAN, power actions, relay, policy, and web admin
- `lumos_app`: Flutter Android client for discovery, pairing, and daily control

## Why I Built This

I got tired of paying for proprietary software that limits core features or locks practical remote-control workflows behind subscriptions.  
Lumos exists because I wanted a tool that I can run myself, control myself, and improve myself.

Project values:
- self-hosted first
- no mandatory cloud dependency
- transparent release process and compatibility policy
- practical security over vendor lock-in

## Get Latest Release

Download current release assets from:

- https://github.com/coff33ninja/lumos/releases/latest

Expected assets:

- `app-release.apk`
- `agent.exe`
- `agent-linux-amd64`

## Why Lumos

- Fast local-network control without cloud lock-in
- Works across VPN networks (for example Tailscale) for remote peer control
- Token-first auth model for day-to-day safety
- Policy-driven command controls (`wake`, `shutdown`, `reboot`, `sleep`)
- Release pipeline with compatibility checks, signed artifacts, checksums, and provenance attestations

## Prerequisites

- Go `1.26.0` (matches `lumos-agent/go.mod`)
- Flutter stable SDK
- Android SDK (for local app development)

## Built With

- Go (`lumos-agent`)
- Dart + Flutter (`lumos_app`)
- PowerShell (build, validation, release scripts)
- GitHub Actions YAML (CI/CD automation)
- JSON policy/config metadata (`release-policy.json`, release/docs metadata)

## Components

| Component | Purpose | Platforms |
|---|---|---|
| `lumos-agent` | API + relay + policy + web admin | Windows, Linux |
| `lumos_app` | Discovery, pairing, control UX | Android |

## Core Capabilities

### Agent

- Power commands (`wake`, `shutdown`, `reboot`, `sleep`)
- Pair/token APIs with scope enforcement (`power-admin`, `wake-only`, `read-only`)
- Peer relay and policy APIs (`/v1/policy/*`, `/v1/peer/*`)
- Mesh-style peer orchestration for agents that are temporarily offline from direct app access
- Web UI and event stream support
- First-run secure credential generation

### Android App

- mDNS + scan-based discovery
- Password bootstrap -> token-first operation
- Token management and policy management UI
- Peer management UI
- Release-aware version visibility

## Network Reality Check

- LAN-first by default, but supports VPN-connected control paths.
- Verified in real use: shutdown command executed successfully over a Tailscale IP path.
- Peer/relay model helps route actions through reachable agents when direct paths are unavailable.

## Quick Start

### 1) Start the Agent

```powershell
cd lumos-agent
go build -o lumos-agent ./cmd/agent
./lumos-agent
```

First run generates secure credentials in `lumos-config.json` (password, cluster key, UI password, shutdown key, state encryption salt).

### 2) Run App Locally (Dev)

```powershell
cd lumos_app
flutter pub get
flutter run
```

### 3) Run Local Validation

```powershell
cd lumos-agent
go test ./...
go vet ./...

cd ../lumos_app
flutter analyze
flutter test
```

## Build and Release Model

- Local release publishing is blocked by design (`publish-release.ps1` is real-publish in GitHub Actions only; local is `-DryRun`).
- Signed release APK builds are CI-only in GitHub Actions.
- Local unified packaging is supported for agent artifacts:

```powershell
.\rebuild-all.ps1 -SkipApp
```

- Release workflow ([`.github/workflows/release.yml`](.github/workflows/release.yml)) handles:
  - channel/tag normalization (`stable` -> `v*`, prerelease -> non-`v`)
  - docs metadata auto-update (`scripts/update-release-docs.ps1`)
  - compatibility, notes, and docs-version validation
  - APK signing continuity checks and `uber-apk-signer` integration in CI
  - checksums, signatures, and provenance attestations

Release version tracking:
- Current stable release tag reference: `v1.1.0` (auto-updated by release tooling).
- Root README stable badge is sourced from GitHub Releases.
- Docs version tracking is pinned in [`docs/docs-version.json`](docs/docs-version.json) and validated in CI/release flows.

## Project Layout

- [`lumos-agent/`](lumos-agent/) Go agent source, config guide, API reference
- [`lumos_app/`](lumos_app/) Flutter Android app source
- [`build/`](build/) generated artifacts (`windows/`, `linux/`, `android/`)
- [`docs/`](docs/) canonical project docs
- [`docs/wiki/`](docs/wiki/) source pages synced to GitHub Wiki
- [`.github/workflows/`](.github/workflows/) CI/CD automation

## Documentation

Detailed operational and release specifics are intentionally kept under `docs/`:

- [`docs/README.md`](docs/README.md) documentation index
- [`docs/VERSIONING.md`](docs/VERSIONING.md) release strategy, tags, compatibility, signing flow
- [`docs/RELEASE_NOTES.md`](docs/RELEASE_NOTES.md) release notes source
- [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) pre-cut checklist
- [`docs/SECURITY.md`](docs/SECURITY.md) security policy and reporting
- [`docs/SIGNING_AND_KEYS.md`](docs/SIGNING_AND_KEYS.md) signing/key custody guidance
- [`docs/KNOWN_ISSUES_AND_LIMITATIONS.md`](docs/KNOWN_ISSUES_AND_LIMITATIONS.md) active limitations
- [`docs/FUTURE.md`](docs/FUTURE.md) roadmap

## Security

- Do not report vulnerabilities in public issues.
- Use GitHub Security Advisories (Security tab -> Report a vulnerability).
- Security policy and hardening guidance:
  - [`SECURITY.md`](SECURITY.md)
  - [`docs/SECURITY.md`](docs/SECURITY.md)
  - [`docs/SECURITY_IMPROVEMENTS.md`](docs/SECURITY_IMPROVEMENTS.md)
  - [`docs/CREDENTIAL_FLOW_ANALYSIS.md`](docs/CREDENTIAL_FLOW_ANALYSIS.md)

## Governance

- License: [`LICENSE`](LICENSE) (MIT)
- Contributing: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Code of Conduct: [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
- Ownership: [`.github/CODEOWNERS`](.github/CODEOWNERS)

## Disclaimer

This software is provided as-is without warranty. You are responsible for secure deployment, access control, and network hardening.


