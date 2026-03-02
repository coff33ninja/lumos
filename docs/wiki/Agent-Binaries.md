<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# Agent Binaries

## Responsibilities

- Expose authenticated power-control APIs
- Execute local power actions or WOL packets
- Maintain pairing tokens and policy enforcement
- Optionally relay to peer agents
- Serve local admin web UI

## Targets

- Windows: `agent.exe`
- Linux: `agent-linux-amd64`

## Build

```powershell
cd lumos-agent
go test ./...
go vet ./...
go build -o agent.exe ./cmd/agent
```

Unified build from repo root:

```powershell
.\rebuild-all.ps1
```

## Runtime Files

- `lumos-config.json` (config)
- `lumos-agent-state.json` (state)

These files are runtime/operator files and are not release assets.




