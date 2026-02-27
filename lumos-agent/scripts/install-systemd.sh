#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

install -d /opt/lumos-agent
install -d /etc/lumos-agent
install -m 0755 ./lumos-agent /opt/lumos-agent/lumos-agent

if [[ ! -f /etc/lumos-agent/lumos-agent.env ]]; then
  cat > /etc/lumos-agent/lumos-agent.env <<'EOF'
LUMOS_BIND=:8080
LUMOS_AGENT_PASSWORD=change-me
LUMOS_CLUSTER_KEY=cluster-secret-change-me
LUMOS_DRY_RUN=true
LUMOS_STATE_FILE=/var/lib/lumos-agent/state.json
EOF
fi

id -u lumos >/dev/null 2>&1 || useradd --system --home-dir /opt/lumos-agent --shell /usr/sbin/nologin lumos
install -d -o lumos -g lumos /var/lib/lumos-agent
chown -R lumos:lumos /opt/lumos-agent

install -m 0644 ./deploy/systemd/lumos-agent.service /etc/systemd/system/lumos-agent.service
systemctl daemon-reload
systemctl enable --now lumos-agent

echo "Installed and started lumos-agent service"
