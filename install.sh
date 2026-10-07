#!/bin/bash
# ============================================================================
# AFTERLIFE VPN - Fresh Server Installer
# Ubuntu 20.04 / 22.04 / 24.04 LTS
# ============================================================================

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

fail() {
    echo -e "\n${RED}✗ Installation failed: $*${NC}" >&2
    exit 1
}

trap 'echo -e "\n\033[0;31m✗ AFTERLIFE installer stopped at line $LINENO. Fix the error above and re-run the installer.\033[0m" >&2' ERR

[[ $EUID -eq 0 ]] || fail "Run this installer as root."

if [[ ! -f /etc/os-release ]]; then
    fail "Unable to identify the operating system."
fi
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || fail "Only Ubuntu is supported by this installer."
case "${VERSION_ID:-}" in
    20.04|22.04|24.04) ;;
    *) fail "Supported Ubuntu releases: 20.04, 22.04 and 24.04 LTS. Detected: ${VERSION_ID:-unknown}" ;;
esac

DOMAIN=${1:-}
if [[ -z "$DOMAIN" ]]; then
    read -r -p "Enter your main domain (example: vpn.example.com): " DOMAIN
fi
[[ -n "$DOMAIN" ]] || fail "A domain is required."

DEFAULT_NS="ns.${DOMAIN}"
TUNNEL_NS=${2:-}
if [[ -z "$TUNNEL_NS" ]]; then
    read -r -p "Enter your tunnel nameserver [${DEFAULT_NS}]: " TUNNEL_NS
    TUNNEL_NS=${TUNNEL_NS:-$DEFAULT_NS}
fi

PUBLIC_IP=$(curl -4 -fsS --max-time 8 ifconfig.me 2>/dev/null || curl -4 -fsS --max-time 8 icanhazip.com 2>/dev/null || true)
[[ -n "$PUBLIC_IP" ]] || fail "Could not determine the public IPv4 address."

echo -e "\n${CYAN}AFTERLIFE VPN preflight${NC}"
echo -e "  Ubuntu      : ${GREEN}${VERSION_ID}${NC}"
echo -e "  Public IPv4 : ${GREEN}${PUBLIC_IP}${NC}"
echo -e "  Domain      : ${GREEN}${DOMAIN}${NC}"
echo -e "  Tunnel NS   : ${GREEN}${TUNNEL_NS}${NC}"

echo -e "\n${YELLOW}[1/9] Installing dependencies...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
    curl wget jq uuid-runtime qrencode apache2-utils openssl ca-certificates \
    dropbear squid dante-server python3 nginx socat cron wireguard \
    iptables iptables-persistent netfilter-persistent net-tools \
    git golang-go dnsutils conntrack

mkdir -p /usr/local/afterlifevpn/{menu,setup,users,data}
mkdir -p /etc/afterlifevpn/cert /etc/hysteria

cat > /usr/local/afterlifevpn/config.conf <<EOF
DOMAIN=$DOMAIN
PUBLIC_IP=$PUBLIC_IP
EOF
cat > /usr/local/afterlifevpn/nameserver.conf <<EOF
NS_HOST="$TUNNEL_NS"
NS_DOMAIN="$TUNNEL_NS"
EOF
echo "8880" > /usr/local/afterlifevpn/ws-port.conf
touch /usr/local/afterlifevpn/users/hysteria_users.txt
chmod 600 /usr/local/afterlifevpn/users/hysteria_users.txt

# The domain must point to this VPS before standalone ACME issuance can succeed.
DNS_IPS=$(dig +short A "$DOMAIN" 2>/dev/null | tr '\n' ' ' || true)
if [[ " $DNS_IPS " != *" $PUBLIC_IP "* ]]; then
    echo -e "\n${RED}Domain preflight failed.${NC}"
    echo -e "  ${WHITE}$DOMAIN${NC} currently resolves to: ${YELLOW}${DNS_IPS:-nothing}${NC}"
    echo -e "  It must contain this VPS public IPv4: ${GREEN}$PUBLIC_IP${NC}"
    echo -e "  Create/fix the A record (DNS-only if using Cloudflare), wait for propagation, then re-run."
    exit 1
fi

echo -e "\n${YELLOW}[2/9] Issuing TLS certificate...${NC}"
if [[ ! -x /root/.acme.sh/acme.sh ]]; then
    curl -fsSL https://get.acme.sh | sh
fi
/root/.acme.sh/acme.sh --register-account -m "admin@$DOMAIN" >/dev/null 2>&1 || true
systemctl stop nginx 2>/dev/null || true
/root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --force
/root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --fullchain-file /etc/afterlifevpn/cert/fullchain.crt \
    --key-file /etc/afterlifevpn/cert/private.key
chown root:root /etc/afterlifevpn/cert/fullchain.crt /etc/afterlifevpn/cert/private.key
chmod 644 /etc/afterlifevpn/cert/fullchain.crt
chmod 600 /etc/afterlifevpn/cert/private.key
openssl x509 -in /etc/afterlifevpn/cert/fullchain.crt -noout -checkend 86400 >/dev/null || fail "Installed certificate is invalid or expiring."

echo -e "\n${YELLOW}[3/9] Configuring Nginx...${NC}"
cat > /etc/nginx/sites-available/afterlifevpn << 'EOF'
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    listen [::]:80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_connect_timeout 10s;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name _;

    ssl_certificate /etc/afterlifevpn/cert/fullchain.crt;
    ssl_certificate_key /etc/afterlifevpn/cert/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location /vmess {
        if ($http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_buffering off;
        proxy_read_timeout 3600s;
    }

    location /vless {
        if ($http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_buffering off;
        proxy_read_timeout 3600s;
    }

    location /trojan {
        if ($http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_buffering off;
        proxy_read_timeout 3600s;
    }

    location / {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_buffering off;
        proxy_read_timeout 3600s;
    }
}
EOF
ln -sf /etc/nginx/sites-available/afterlifevpn /etc/nginx/sites-enabled/afterlifevpn
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx

echo -e "\n${YELLOW}[4/9] Installing Xray core...${NC}"
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
REALITY_KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep -i "Private" | awk '{print $NF}')
PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep -i "Public" | awk '{print $NF}')
SERVER_KEY=$(openssl rand -base64 16)
USER_KEY=$(openssl rand -base64 16)
UUID=$(uuidgen)
echo "REALITY_PRIVATE=$PRIVATE_KEY" > /usr/local/afterlifevpn/reality.key
echo "REALITY_PUBLIC=$PUBLIC_KEY" >> /usr/local/afterlifevpn/reality.key
echo "SS2022_KEY=$SERVER_KEY" > /usr/local/afterlifevpn/ss2022.key
chmod 600 /usr/local/afterlifevpn/reality.key /usr/local/afterlifevpn/ss2022.key

cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [ { "id": "$UUID", "alterId": 0 } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    },
    {
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": { "clients": [ { "id": "$UUID", "email": "admin@vless" } ], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": { "clients": [ { "password": "$UUID", "email": "admin@trojan" } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } }
    },
    {
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "$UUID", "flow": "xtls-rprx-vision" } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.microsoft.com:443",
          "xver": 0,
          "serverNames": ["www.microsoft.com", "microsoft.com"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [""]
        }
      }
    },
    {
      "port": 10010,
      "protocol": "shadowsocks",
      "settings": {
        "password": "$SERVER_KEY",
        "method": "2022-blake3-aes-128-gcm",
        "network": "tcp,udp",
        "clients": [ { "password": "$USER_KEY", "email": "ss2022@afterlife" } ]
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF
systemctl enable --now xray

echo -e "\n${YELLOW}[5/9] Downloading AFTERLIFE components...${NC}"
REPO_REF="${AFTERLIFE_REF:-main}"
REPO="https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/${REPO_REF}"
FILES=(
    menu/menu.sh
    setup/xray-user.sh
    setup/hysteria.sh
    setup/hysteria-user.sh
    setup/slowdns.sh
    setup/squid.sh
    setup/dante.sh
    setup/dropbear.sh
    setup/add-host.sh
    setup/xray-add-vless.sh
    setup/xray-add-trojan.sh
    setup/xray-online.sh
    setup/xray-del.sh
    setup/user-expire.sh
    setup/ssh-ws.sh
)
for file in "${FILES[@]}"; do
    mkdir -p "/usr/local/afterlifevpn/$(dirname "$file")"
    curl -fsSL "$REPO/$file" -o "/usr/local/afterlifevpn/$file" || fail "Could not download $file"
done
chmod +x /usr/local/afterlifevpn/menu/*.sh /usr/local/afterlifevpn/setup/*.sh

echo -e "\n${YELLOW}[6/9] Configuring Hysteria, SSH and UDP backends...${NC}"
HYSTERIA_BACKEND_PORT=4430 bash /usr/local/afterlifevpn/setup/hysteria.sh --fresh
sed -i 's/^NO_START=.*/NO_START=0/' /etc/default/dropbear 2>/dev/null || true
if grep -q '^DROPBEAR_PORT=' /etc/default/dropbear; then
    sed -i 's/^DROPBEAR_PORT=.*/DROPBEAR_PORT=109/' /etc/default/dropbear
else
    echo 'DROPBEAR_PORT=109' >> /etc/default/dropbear
fi
if grep -q '^DROPBEAR_EXTRA_ARGS=' /etc/default/dropbear; then
    sed -i 's/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 109"/' /etc/default/dropbear
else
    echo 'DROPBEAR_EXTRA_ARGS="-p 109"' >> /etc/default/dropbear
fi
grep -qxF "/bin/false" /etc/shells || echo "/bin/false" >> /etc/shells
systemctl enable --now dropbear

wget -qO /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw64"
chmod 755 /usr/bin/badvpn-udpgw
cat > /etc/systemd/system/badvpn.service <<'EOF'
[Unit]
Description=BadVPN UDPGW Port 7300
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now badvpn

if [[ ! -f /etc/wireguard/wg0.conf ]]; then
    cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $(wg genkey)
Address = 10.66.66.1/24
ListenPort = 2048
SaveConfig = true
EOF
    chmod 600 /etc/wireguard/wg0.conf
fi
systemctl enable --now wg-quick@wg0

bash /usr/local/afterlifevpn/setup/squid.sh
bash /usr/local/afterlifevpn/setup/dante.sh
bash /usr/local/afterlifevpn/setup/ssh-ws.sh

echo -e "\n${YELLOW}[7/9] Installing SlowDNS/dnstt...${NC}"
bash /usr/local/afterlifevpn/setup/slowdns.sh "$DOMAIN" "$TUNNEL_NS"

echo -e "\n${YELLOW}[8/9] Enabling default Shared HY port-53 routing...${NC}"
echo "MODE=shared_hy" > /usr/local/afterlifevpn/port53-mode.conf
bash /usr/local/afterlifevpn/menu/menu.sh --restore-p53

cat > /etc/systemd/system/afterlife-port53.service <<'EOF'
[Unit]
Description=Restore AFTERLIFE UDP 53 demultiplexer
After=network-online.target hysteria.service dnstt.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/afterlifevpn/menu/menu.sh --restore-p53
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable afterlife-port53.service

echo -e "\n${YELLOW}[9/9] Final health checks...${NC}"
ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/menu
ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/afterlife

if ! crontab -l 2>/dev/null | grep -q "user-expire.sh"; then
    (crontab -l 2>/dev/null || true; echo "0 0 * * * bash /usr/local/afterlifevpn/setup/user-expire.sh") | crontab -
fi

FAILURES=0
for srv in nginx xray dropbear hysteria dnstt; do
    if systemctl is-active --quiet "$srv"; then
        echo -e "  ${GREEN}✓${NC} $srv"
    else
        echo -e "  ${RED}✗${NC} $srv"
        FAILURES=$((FAILURES + 1))
    fi
done

if ! ss -uln | grep -qE ':4430\s'; then
    echo -e "  ${RED}✗${NC} Hysteria backend UDP 4430 is not listening"
    FAILURES=$((FAILURES + 1))
else
    echo -e "  ${GREEN}✓${NC} Hysteria backend UDP 4430"
fi
if ! ss -uln | grep -qE ':5300\s'; then
    echo -e "  ${RED}✗${NC} dnstt backend UDP 5300 is not listening"
    FAILURES=$((FAILURES + 1))
else
    echo -e "  ${GREEN}✓${NC} dnstt backend UDP 5300"
fi
if ! iptables-legacy -t nat -C PREROUTING -p udp --dport 53 -j AFTERLIFE_MUX 2>/dev/null && \
   ! iptables -t nat -C PREROUTING -p udp --dport 53 -j AFTERLIFE_MUX 2>/dev/null; then
    echo -e "  ${RED}✗${NC} UDP 53 mux rule is missing"
    FAILURES=$((FAILURES + 1))
else
    echo -e "  ${GREEN}✓${NC} UDP 53 mux rule"
fi

if (( FAILURES > 0 )); then
    echo -e "\n${RED}Installation finished with $FAILURES failed health check(s).${NC}"
    echo -e "Run: ${WHITE}menu${NC} → Diagnostics, or inspect systemctl/journalctl before creating users."
    exit 1
fi

echo -e "\n${GREEN}✓ AFTERLIFE VPN installation complete.${NC}"
echo -e "  Port 53 mode : ${CYAN}Shared HY${NC}"
echo -e "  Hysteria     : ${CYAN}public UDP 53 → backend UDP 4430 (Salamander ON)${NC}"
echo -e "  SlowDNS      : ${CYAN}public UDP 53 → backend UDP 5300${NC}"
echo -e "  Menu         : ${WHITE}menu${NC} or ${WHITE}afterlife${NC}"
echo -e "\nCreate Hysteria accounts only after the desired Port 53 mode is active.\n"
