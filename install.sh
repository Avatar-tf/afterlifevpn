#!/bin/bash
# ==========================================================
# AFTERLIFE VPN - ULTIMATE MASTER INSTALLATION SCRIPT (Fixed)
# ==========================================================
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[0;31mError: This script must be run as root.\033[0m"
   exit 1
fi

printf '\n==== WELCOME TO AFTERLIFE VPN ====\n'
DOMAIN=${1:-}
if [[ -z "$DOMAIN" ]]; then
    read -p "Enter your domain (e.g., tech.itzdajohn.online): " DOMAIN
fi
if [[ -z "$DOMAIN" ]]; then
    echo "Domain is required for SSL generation. Exiting."
    exit 1
fi

read -r -p "SlowDNS nameserver hostname (optional; Enter to skip): " NS_HOST
[[ -z "$NS_HOST" || "$NS_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || exit 1

echo -e "\e[1;33m[1/8] Updating System & Installing Dependencies...\e[0m"
apt-get update -y || exit 1
apt-get install -y curl wget jq uuid-runtime qrencode apache2-utils dropbear squid dante-server python3 nginx socat cron wireguard iptables-persistent net-tools git golang-go || exit 1

mkdir -p /usr/local/afterlifevpn/{menu,setup,users,data}
mkdir -p /etc/afterlifevpn/cert
printf 'DOMAIN=%q\n' "$DOMAIN" > /usr/local/afterlifevpn/config.conf
if [[ -n "$NS_HOST" ]]; then
    PUBLIC_IP=$(curl -4fsS --max-time 8 https://api.ipify.org || true)
    printf 'NS_HOST=%q\nNS_DOMAIN=%q\nNS_IP=%q\n' "$NS_HOST" "$NS_HOST" "$PUBLIC_IP" > /usr/local/afterlifevpn/nameserver.conf
fi
echo "8880" > /usr/local/afterlifevpn/ws-port.conf

echo "[2/8] Issuing and verifying domain TLS certificate..."
if [[ ! -x /root/.acme.sh/acme.sh ]]; then
    curl -fsSL https://get.acme.sh | sh || exit 1
fi
systemctl stop nginx 2>/dev/null || true
if ! /root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --force; then
    echo "Certificate failed: check DNS A record and inbound port 80"; exit 1
fi
/root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --fullchain-file /etc/afterlifevpn/cert/fullchain.crt \
    --key-file /etc/afterlifevpn/cert/private.key || exit 1
openssl x509 -in /etc/afterlifevpn/cert/fullchain.crt -noout -checkend 86400 >/dev/null || exit 1
chmod 600 /etc/afterlifevpn/cert/private.key

echo -e "\e[1;33m[3/8] Configuring Nginx Reverse Proxy (Improved)...\e[0m"

cat > /etc/nginx/sites-available/afterlifevpn << 'EOF'
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
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

    ssl_certificate     /etc/afterlifevpn/cert/fullchain.crt;
    ssl_certificate_key /etc/afterlifevpn/cert/private.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # VMess
    location /vmess {
        if ($http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:10001;
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

    # VLESS
    location /vless {
        if ($http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:10002;
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

    # Trojan
    location /trojan {
        if ($http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:10003;
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

    # Default → SSH-WS (NetMod)
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
EOF

ln -sf /etc/nginx/sites-available/afterlifevpn /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
systemctl enable nginx

echo -e "\e[1;33m[4/8] Installing Xray (VMess, VLess, Trojan, Reality, SS2022)...\e[0m"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

REALITY_KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep -i "Private" | awk '{print $NF}')
PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep -i "Public" | awk '{print $NF}')
SERVER_KEY=$(openssl rand -base64 16)
USER_KEY=$(openssl rand -base64 16)
UUID=$(uuidgen)

echo "REALITY_PRIVATE=$PRIVATE_KEY" > /usr/local/afterlifevpn/reality.key
echo "REALITY_PUBLIC=$PUBLIC_KEY"  >> /usr/local/afterlifevpn/reality.key
echo "SS2022_KEY=$SERVER_KEY"      > /usr/local/afterlifevpn/ss2022.key

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

systemctl restart xray
systemctl enable xray

echo -e "\e[1;33m[5/8] Installing Hysteria 2 (port 4430)...\e[0m"
bash <(curl -fsSL https://get.hy2.sh/) || { echo "Hysteria installer failed"; exit 1; }

mkdir -p /etc/hysteria
cat > /etc/hysteria/config.yaml <<EOF
listen: :4430

tls:
  cert: /etc/afterlifevpn/cert/fullchain.crt
  key: /etc/afterlifevpn/cert/private.key

auth:
  type: command
  command: /etc/hysteria/auth.sh

masquerade:
  type: proxy
  proxy:
    url: https://www.microsoft.com
    rewriteHost: true
EOF

mkdir -p /usr/local/afterlifevpn/users
touch /usr/local/afterlifevpn/users/hysteria_users.txt
cat > /etc/hysteria/auth.sh <<'AUTH_SCRIPT'
#!/bin/sh
token="$2"
[ -n "$token" ] || token="$1"
awk -F '|' -v token="$token" '$2 == token && $3 >= strftime("%Y-%m-%d") {print $1; found=1; exit} END {if (!found) exit 1}' /usr/local/afterlifevpn/users/hysteria_users.txt
AUTH_SCRIPT
chmod 700 /etc/hysteria/auth.sh
systemctl enable hysteria-server.service
systemctl restart hysteria-server.service || { journalctl -u hysteria-server -n 20 --no-pager; exit 1; }

echo -e "\e[1;33m[6/8] Configuring Dropbear, BadVPN, WireGuard & Ports...\e[0m"
sed -i 's/DROPBEAR_PORT=.*/DROPBEAR_PORT=109/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 109"/g' /etc/default/dropbear
grep -q "/bin/false" /etc/shells || echo "/bin/false" >> /etc/shells
systemctl restart dropbear

wget -qO /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw64"
chmod +x /usr/bin/badvpn-udpgw

cat > /etc/systemd/system/badvpn.service << 'EOF'
[Unit]
Description=BadVPN UDPGW Port 7300
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable badvpn
systemctl start badvpn

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $(wg genkey)
Address = 10.66.66.1/24
ListenPort = 2048
SaveConfig = true
EOF

systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Port 53 forwarding is managed by the menu; do not preempt it.
netfilter-persistent save 2>/dev/null || true

echo -e "\e[1;33m[7/8] Pulling Scripts from GitHub...\e[0m"
REPO="https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/review/main-baseline-fixes"

wget -q -O /usr/local/afterlifevpn/menu/menu.sh          "$REPO/menu/menu.sh"
wget -q -O /usr/local/afterlifevpn/setup/xray-user.sh     "$REPO/setup/xray-user.sh"
wget -q -O /usr/local/afterlifevpn/setup/hysteria-user.sh "$REPO/setup/hysteria-user.sh"
wget -q -O /usr/local/afterlifevpn/setup/slowdns.sh "$REPO/setup/slowdns.sh"
wget -q -O /usr/local/afterlifevpn/setup/add-host.sh "$REPO/setup/add-host.sh"
wget -q -O /usr/local/afterlifevpn/setup/squid.sh         "$REPO/setup/squid.sh"
wget -q -O /usr/local/afterlifevpn/setup/dante.sh         "$REPO/setup/dante.sh"
wget -q -O /usr/local/afterlifevpn/setup/xray-add-vless.sh "$REPO/setup/xray-add-vless.sh"
wget -q -O /usr/local/afterlifevpn/setup/xray-add-trojan.sh "$REPO/setup/xray-add-trojan.sh"
wget -q -O /usr/local/afterlifevpn/setup/xray-online.sh   "$REPO/setup/xray-online.sh"
wget -q -O /usr/local/afterlifevpn/setup/xray-del.sh      "$REPO/setup/xray-del.sh"
wget -q -O /usr/local/afterlifevpn/setup/user-expire.sh   "$REPO/setup/user-expire.sh"
wget -q -O /usr/local/afterlifevpn/setup/ssh-ws.sh        "$REPO/setup/ssh-ws.sh"

chmod +x /usr/local/afterlifevpn/menu/menu.sh
chmod +x /usr/local/afterlifevpn/setup/*.sh

# Run extra setup scripts
bash /usr/local/afterlifevpn/setup/squid.sh
bash /usr/local/afterlifevpn/setup/dante.sh
bash /usr/local/afterlifevpn/setup/ssh-ws.sh   # installs the fixed WS-SSH

echo -e "\e[1;33m[8/8] Finalizing Setup & Automation...\e[0m"
ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/menu
ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/afterlife

if ! crontab -l 2>/dev/null | grep -q "user-expire.sh"; then
    (crontab -l 2>/dev/null; echo "0 0 * * * bash /usr/local/afterlifevpn/setup/user-expire.sh") | crontab -
fi

echo -e "\n\e[0;32m✓ AFTERLIFE VPN Installation Complete!\e[0m"
echo -e "\e[1;37mType 'menu' or 'afterlife' to launch the dashboard.\e[0m"
echo "Hysteria installed on UDP 4430. Verify with systemctl status hysteria-server."
