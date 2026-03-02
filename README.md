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

**Lumos puts your local network in your pocket.**

A LAN-first remote power-control stack for discovering, monitoring, and controlling devices on your home or office network — with no mandatory cloud dependency.

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

## Key Features

### For Users
- **Automatic device discovery** via mDNS (`_lumos-agent._tcp`)
- **Wake-on-LAN** support for remotely powering on devices
- **Power control** commands: shutdown, reboot, sleep
- **VPN-friendly** — works across Tailscale and other VPN networks
- **Token-based authentication** with scope control (power-admin, wake-only, read-only)
- **Policy-driven permissions** for fine-grained action control
- **Peer relay** for multi-agent orchestration
- **Web UI** for agent configuration and management
- **100% local** — no accounts, no mandatory cloud, no data collection

### For Developers
- **Open source** — fully auditable codebase (MIT license)
- **Self-hosted first** — run on your own infrastructure
- **Transparent releases** — signed artifacts, checksums, provenance attestations
- **Cross-platform agent** — Windows and Linux support
- **REST API** with WebSocket events for real-time updates
- **Encrypted state files** for secure credential storage
- **CI/CD pipeline** with automated testing and release validation

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

## Use Cases

- **Home lab management** — Control your servers and workstations from your phone
- **Network administration** — Manage power states across multiple devices
- **Smart home integration** — Wake devices on demand without cloud services
- **Remote work** — Access your home network devices over VPN
- **Energy efficiency** — Easily shutdown unused devices to save power

## Core Capabilities

### Agent (lumos-agent)

- **Power commands**: `wake`, `shutdown`, `reboot`, `sleep`
- **Authentication**: Password-based pairing with long-lived tokens
- **Token scopes**: `power-admin`, `wake-only`, `read-only`
- **Policy engine**: Fine-grained per-device action allowances
- **Peer relay**: Mesh-style orchestration for multi-agent setups
- **Web UI**: Built-in admin interface at `http://localhost:8080/`
- **Event streaming**: WebSocket support for real-time updates
- **Auto-generated credentials**: Secure random passwords on first run
- **Encrypted state**: AES-256 encrypted persistent storage
- **Rate limiting**: Protection against brute-force attacks
- **Optional TLS**: HTTPS support for secure remote access

### Android App (lumos_app)

- **Device discovery**: mDNS + server-side scan + fallback direct scan
- **Pairing flow**: Password used once, then token-based operation
- **Token management**: List, rotate, and revoke tokens
- **Policy management**: Configure action allowances per device
- **Peer management**: Register and manage agent mesh
- **Version awareness**: Compatibility checks for safe operations
- **Local storage**: All data stored on device via SharedPreferences
- **No analytics**: Zero tracking or data collection

## Network Architecture

Lumos is designed with a **LAN-first** philosophy but supports flexible deployment:

- **Local network**: Direct communication between app and agents on the same LAN
- **VPN networks**: Full support for VPN-connected control (tested with Tailscale)
- **Peer relay**: Route commands through reachable agents when direct paths are unavailable
- **No cloud required**: All communication stays within your private network or VPN tunnel
- **Optional internet**: Can expose agents over the internet with TLS (not recommended without VPN)

**Real-world validation**: Shutdown commands successfully executed over Tailscale IP paths in production use.

## Quick Start

### Option 1: Download Pre-built Releases (Recommended)

Download the latest release from:
- https://github.com/coff33ninja/lumos/releases/latest

Available assets:
- `app-release.apk` — Android app (install on your phone)
- `agent.exe` — Windows agent
- `agent-linux-amd64` — Linux agent

### Option 2: Build from Source

#### 1) Start the Agent

```powershell
cd lumos-agent
go build -o lumos-agent ./cmd/agent
./lumos-agent
```

**First run generates secure credentials** in `lumos-config.json`:
- `password` — Main API authentication (24 hex chars)
- `cluster_key` — Peer mesh networking (32 hex chars)
- `ui_password` — Web UI access (24 hex chars)
- `shutdown_key` — Internal graceful shutdown (32 hex chars)
- `state_encryption_salt` — State file encryption (32 hex chars)

Open `http://localhost:8080/` to access the web UI.

#### 2) Install the Android App

```powershell
cd lumos_app
flutter pub get
flutter build apk --release
```

Install `build/app/outputs/flutter-apk/app-release.apk` on your Android device.

#### 3) Pair and Control

1. Open the Lumos app on your phone
2. Discover agents via mDNS or manual IP entry
3. Pair using the password from `lumos-config.json`
4. Start controlling your devices!

### Development Workflow

```powershell
# Run agent in dev mode
cd lumos-agent
go run ./cmd/agent

# Run app in dev mode
cd lumos_app
flutter run

# Run tests
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

### Getting Started
- [`lumos-agent/README.md`](lumos-agent/README.md) — Agent setup, API reference, configuration
- [`lumos-agent/QUICK_START.md`](lumos-agent/QUICK_START.md) — Fast setup guide
- [`lumos-agent/CONFIG_GUIDE.md`](lumos-agent/CONFIG_GUIDE.md) — Configuration options
- [`lumos-agent/API_REFERENCE.md`](lumos-agent/API_REFERENCE.md) — Complete API documentation
- [`lumos_app/README.md`](lumos_app/README.md) — Android app overview

### Project Documentation
- [`docs/README.md`](docs/README.md) — Documentation index
- [`docs/VERSIONING.md`](docs/VERSIONING.md) — Release strategy and compatibility
- [`docs/RELEASE_NOTES.md`](docs/RELEASE_NOTES.md) — Changelog and release history
- [`docs/FUTURE.md`](docs/FUTURE.md) — Roadmap and planned features
- [`docs/KNOWN_ISSUES_AND_LIMITATIONS.md`](docs/KNOWN_ISSUES_AND_LIMITATIONS.md) — Current limitations

### Security & Operations
- [`docs/SECURITY.md`](docs/SECURITY.md) — Security policy and vulnerability reporting
- [`docs/SECURITY_IMPROVEMENTS.md`](docs/SECURITY_IMPROVEMENTS.md) — Security audit findings
- [`docs/CREDENTIAL_FLOW_ANALYSIS.md`](docs/CREDENTIAL_FLOW_ANALYSIS.md) — Credential usage analysis
- [`docs/SIGNING_AND_KEYS.md`](docs/SIGNING_AND_KEYS.md) — Signing and key management

### Wiki
- [`docs/wiki/`](docs/wiki/) — Detailed guides synced to GitHub Wiki
  - [Architecture](docs/wiki/Architecture.md)
  - [Security and Trust](docs/wiki/Security-and-Trust.md)
  - [Operations and Troubleshooting](docs/wiki/Operations-and-Troubleshooting.md)
  - [Releases and Versioning](docs/wiki/Releases-and-Versioning.md)

## Security

Lumos implements multiple security layers:

- **Auto-generated credentials** — Cryptographically secure random passwords on first run
- **Token-based authentication** — Password used once for pairing, then long-lived tokens
- **Rate limiting** — 5 failed attempts = 3 minute lockout
- **Encrypted state** — AES-256 encrypted persistent storage
- **HMAC signatures** — Peer-to-peer commands use HMAC-SHA256
- **Optional TLS** — HTTPS support for secure remote access
- **Policy engine** — Fine-grained action allowances per device
- **No data collection** — Zero analytics or tracking

### Reporting Security Issues

**DO NOT** open public GitHub issues for security vulnerabilities.

Use GitHub Security Advisories:
- Go to the Security tab → Report a vulnerability
- See [`docs/SECURITY.md`](docs/SECURITY.md) for full reporting guidelines

### Security Documentation
- [`SECURITY.md`](SECURITY.md) — Security policy
- [`docs/SECURITY.md`](docs/SECURITY.md) — Detailed security guidance
- [`docs/SECURITY_IMPROVEMENTS.md`](docs/SECURITY_IMPROVEMENTS.md) — Security audit findings
- [`docs/CREDENTIAL_FLOW_ANALYSIS.md`](docs/CREDENTIAL_FLOW_ANALYSIS.md) — Credential usage analysis

## Governance

- License: [`LICENSE`](LICENSE) (MIT)
- Contributing: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Code of Conduct: [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
- Ownership: [`.github/CODEOWNERS`](.github/CODEOWNERS)

## Disclaimer

This software is provided as-is without warranty. You are responsible for secure deployment, access control, and network hardening.


