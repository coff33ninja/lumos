<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Architecture

Lumos uses a client-agent model with optional agent-to-agent relay.

## Components

- Android app (`lumos_app`)
- Agent service (`lumos-agent`)
- Optional peer mesh (hive) across agents

## Core Flows

1. Discovery
- App scans configured subnets/ports and validates `/v1/status`.

2. Pairing
- Bootstrap uses password to call `/v1/auth/pair`.
- Agent returns token (`power-admin`, `wake-only`, `read-only`).

3. Control
- App uses token for `/v1/command/*`.
- Agent enforces scope and policy allowances.

4. Relay
- Agent can relay commands to registered peers when enabled.
- Relay trust is controlled by peer registration and keys.

## Design Principles

- LAN-first reliability
- Explicit auth and policy checks
- Operational transparency through logs, docs, release metadata



