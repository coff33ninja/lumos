<!-- lumos-docs-release: tag=v1.0.0; updated_utc=2026-02-27 -->

# Operations and Troubleshooting

## Scan Fails to Detect Agent

Check:
- Agent bind port matches app scan ports
- `allow_insecure_remote_http` policy for non-TLS LAN testing
- Correct subnet range for scan target
- Firewall rules on host/network

## Power Command Returns Success but Host Does Not Act

Check:
- `dry_run` is disabled
- Host OS power command permissions
- Policy allowances allow shutdown/reboot/sleep for current token

## WOL Fails

Check:
- Correct target MAC and broadcast path
- NIC/BIOS WOL settings enabled on target machine
- Same-LAN vs relay path configuration

## Reference

- `lumos-agent/CONFIG_GUIDE.md`
- `lumos-agent/API_REFERENCE.md`
- `docs/KNOWN_ISSUES_AND_LIMITATIONS.md`



