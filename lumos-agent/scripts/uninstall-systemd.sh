#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

systemctl disable --now lumos-agent || true
rm -f /etc/systemd/system/lumos-agent.service
systemctl daemon-reload

echo "Removed lumos-agent service unit"
