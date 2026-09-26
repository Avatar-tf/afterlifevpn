#!/bin/bash
# AFTERLIFE - Hysteria 2 setup (does not wipe a live node unless you type YES)
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31mError: root required.\033[0m"
    exit 1
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
HY_YAML="/etc/hysteria/config.yaml"
AUTH_SH="/etc/hysteria/auth.sh"
CONF="/usr/local/afterlifevpn/hysteria-config.txt"
DOMAIN_FILE="/usr/local/afterlifevpn/config.conf"

DOMAIN=""; PUBLIC_IP=""
[[ -f "$DOMAIN_FILE" ]] && source "$DOMAIN_FILE" 2>/dev/null || true
HOST="${DOMAIN:-$PUBLIC_IP}"
IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || echo "$PUBLIC_IP")
[[ -z "$HOST" ]] && HOST="$IP"

write_auth() {
    python3 -c '
from pathlib import Path
Path("/etc/hysteria/auth.sh").write_text("""#!/usr/bin/env python3
import sys
from datetime import datetime
auth = sys.argv[2] if len(sys.argv) > 2 else (sys.argv[1] if len(sys.argv) > 1 else "")
path = "/usr/local/afterlifevpn/users/hysteria_users.txt"
username = None
password = auth
if ":" in auth:
    username, password = auth.split(":", 1)
try:
    lines = open(path).read().splitlines()
except FileNotFoundError:
    sys.exit(1)
record = None
for line in lines:
    parts = line.split("|")
    if len(parts) < 3:
        continue
    u, p, exp = parts[0], parts[1], parts[2]
    if username is not None:
        if u == username and p == password:
            record = (u, p, exp); break
    elif p == password:
        record = (u, p, exp); break
if record is None:
    sys.exit(1)
try:
    if datetime.now() > datetime.strptime(record[2], "%Y-%m-%d"):
        sys.exit(1)
except ValueError:
    sys.exit(1)
print(record[0]); sys.exit(0)
""")
'
    chmod 755 "$AUTH_SH"
}

save_conf() {
    mkdir -p /usr/local/afterlifevpn
    cat > "$CONF" <<EOF
MODE=$1
PORT=$2
SALAMANDER=$3
OBFS_PASSWORD=$4
DOMAIN=$HOST
EOF
}

restart_hy() {
    systemctl daemon-reload
    systemctl enable hysteria >/dev/null 2>&1
    systemctl restart hysteria
    sleep 1
    systemctl is-active hysteria
    ss -ulnp | grep hysteria || true
}

toggle_salamander() {
    [[ -f "$HY_YAML" ]] || { echo -e "${RED}No yaml. Use first install.${NC}"; return; }
    if grep -qE '^obfs:' "$HY_YAML"; then
        echo -e "${YELLOW}Salamander is ON. Turn OFF? [y/N]${NC}"
        read -r a
        if [[ "$a" == "y" || "$a" == "Y" ]]; then
            python3 -c '
from pathlib import Path
p = Path("/etc/hysteria/config.yaml")
lines = p.read_text().splitlines(); out=[]; i=0
while i < len(lines):
    if lines[i].strip() == "obfs:":
        i += 1
        while i < len(lines) and (lines[i].startswith(" ") or lines[i].startswith("\t") or lines[i].strip()==""):
            i += 1
        continue
    out.append(lines[i]); i += 1
p.write_text("\n".join(out)+"\n")
'
            save_conf 53 53 n ""
            echo -e "${GREEN}Salamander off. Old links without obfs work again.${NC}"
            restart_hy
        fi
    else
        echo -e "${YELLOW}Salamander is OFF. Turn ON? [y/N]${NC}"
        read -r a
        if [[ "$a" == "y" || "$a" == "Y" ]]; then
            OBFS=$(openssl rand -hex 8)
            printf '\nobfs:\n  type: salamander\n  salamander:\n    password: %s\n' "$OBFS" >> "$HY_YAML"
            save_conf 53 53 y "$OBFS"
            echo -e "${GREEN}Salamander on.${NC}"
            echo -e " Obfs password: ${YELLOW}${OBFS}${NC}"
            echo -e " Add to links: &obfs=salamander&obfs-password=${OBFS}"
            restart_hy
        fi
    fi
}

first_install() {
    write_auth
    mkdir -p /etc/hysteria /usr/local/afterlifevpn/users
    touch /usr/local/afterlifevpn/users/hysteria_users.txt
    wget -q -O /usr/local/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
    chmod +x /usr/local/bin/hysteria
    cat > "$HY_YAML" <<EOF
listen: :53

tls:
  cert: /etc/afterlifevpn/cert/fullchain.crt
  key: /etc/afterlifevpn/cert/private.key

auth:
  type: command
  command: /etc/hysteria/auth.sh

masquerade:
  type: proxy
  proxy:
    url: https://www.google.com
    rewriteHost: true

quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432
EOF
    cat > /etc/systemd/system/hysteria.service <<EOF
[Unit]
Description=AFTERLIFE Hysteria 2 Server
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=always
RestartSec=3
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
    save_conf 53 53 n ""
    restart_hy
    echo -e "${GREEN}Installed on UDP 53. Create users from the user menu.${NC}"
}

# ----- main -----
clear
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${YELLOW}      AFTERLIFE — HYSTERIA SETUP${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo
if [[ -f "$HY_YAML" ]]; then
    echo -e "  Live yaml found. ${GREEN}Will not overwrite listen/auth.${NC}"
    echo
    echo -e "  ${GREEN}1)${NC} Toggle Salamander (safe)"
    echo -e "  ${GREEN}2)${NC} Rewrite auth helper only (safe)"
    echo -e "  ${RED}9)${NC} Full reinstall (type YES) — wipes yaml"
    echo -e "  ${RED}0)${NC} Back"
    echo
    read -r -p "  Select: " c
    case "$c" in
        1) toggle_salamander ;;
        2) write_auth; echo -e "${GREEN}auth.sh refreshed${NC}"; restart_hy ;;
        9)
            read -r -p "  Type YES to wipe yaml: " y
            [[ "$y" == "YES" ]] && first_install || echo "Cancelled"
            ;;
        *) ;;
    esac
else
    echo -e "  No yaml. First install on ${YELLOW}UDP 53${NC}."
    read -r -p "  Continue? [Y/n]: " g
    [[ "$g" == "n" || "$g" == "N" ]] || first_install
fi
read -r -p "  Press Enter..."
