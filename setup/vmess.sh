#!/bin/bash
# VMess listens on 127.0.0.1:10001 only.
# Nginx already owns public 443 and sends /vmess here.
# SSH-WS stays on / -> 127.0.0.1:8880. Do not bind 443 or 53.
DOMAIN=$1
if [[ -z "$DOMAIN" && -f /usr/local/afterlifevpn/config.conf ]]; then
    # shellcheck disable=SC1091
    source /usr/local/afterlifevpn/config.conf
fi
[[ -z "$DOMAIN" ]] && { echo "Usage: bash vmess.sh your.domain"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y jq uuid-runtime qrencode
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

mkdir -p /usr/local/afterlifevpn/users /usr/local/etc/xray
touch /usr/local/afterlifevpn/users/xray_users.txt

python3 - <<'PY'
import json
from pathlib import Path
p = Path("/usr/local/etc/xray/config.json")
if p.exists() and p.stat().st_size:
    cfg = json.loads(p.read_text())
else:
    cfg = {"log": {"loglevel": "warning"}, "inbounds": [], "outbounds": [{"protocol": "freedom"}]}
clients = []
kept = []
for ib in cfg.get("inbounds", []):
    if ib.get("protocol") == "vmess":
        clients = ib.get("settings", {}).get("clients", [])
        continue
    kept.append(ib)
kept.insert(0, {
    "listen": "127.0.0.1",
    "port": 10001,
    "protocol": "vmess",
    "tag": "vmess-ws",
    "settings": {"clients": clients},
    "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess"}},
})
cfg["inbounds"] = kept
cfg.setdefault("log", {"loglevel": "warning"})
cfg.setdefault("outbounds", [{"protocol": "freedom"}])
p.write_text(json.dumps(cfg, indent=2) + "\n")
PY

cat > /usr/local/afterlifevpn/vmess-config.txt <<EOF
Address: $DOMAIN
PublicPort: 443
Path: /vmess
Local: 127.0.0.1:10001
EOF

systemctl enable xray
systemctl restart xray
sleep 1
if ss -tlnp | grep -q ':10001'; then
    echo "VMess ready on 127.0.0.1:10001. Public 443 was not taken."
else
    echo "Xray did not bind 10001"
    journalctl -u xray -n 20 --no-pager
    exit 1
fi