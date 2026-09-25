#!/bin/bash

# ==========================================================
# AFTERLIFE VPN - ULTIMATE MASTER INSTALLATION SCRIPT
# ==========================================================

if [[ $EUID -ne 0 ]]; then
   echo -e "\033[0;31mError: This script must be run as root.\033[0m"
   exit 1
fi

DOMAIN=$1
if [[ -z "$DOMAIN" ]]; then
    read -p "Enter your domain (e.g., tech.itzdajohn.online): " DOMAIN
fi

if [[ -z "$DOMAIN" ]]; then
    echo "Domain is required for SSL generation. Exiting."
    exit 1
fi

echo -e "\e[1;33m[1/8] Updating System & Installing Dependencies...\e[0m"
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget jq uuid-runtime qrencode apache2-utils dropbear squid dante-server python3-websockets nginx socat cron wireguard iptables-persistent net-tools

mkdir -p /usr/local/afterlifevpn/{menu,setup,users,data}
mkdir -p /etc/afterlifevpn/cert
echo "DOMAIN=$DOMAIN" > /usr/local/afterlifevpn/config.conf
echo "8880" > /usr/local/afterlifevpn/ws-port.conf

echo -e "\e[1;33m[2/8] Generating SSL Certificates...\e[0m"
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m admin@$DOMAIN
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone
~/.acme.sh/acme.sh --installcert -d $DOMAIN \
    --fullchainpath /etc/afterlifevpn/cert/fullchain.crt \
    --keypath /etc/afterlifevpn/cert/private.key
chmod 644 /etc/afterlifevpn/cert/*

echo -e "\e[1;33m[3/8] Configuring Nginx Reverse Proxy...\e[0m"
cat > /etc/nginx/sites-available/afterlifevpn <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name _;
    location / { proxy_pass http://127.0.0.1:8880; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
}
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name _;
    ssl_certificate /etc/afterlifevpn/cert/fullchain.crt;
    ssl_certificate_key /etc/afterlifevpn/cert/private.key;
    
    # VMESS WS Routing
    location /vmess { if (\$http_upgrade != "websocket") { return 404; } proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    
    # VLESS WS Routing
    location /vless { if (\$http_upgrade != "websocket") { return 404; } proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    
    # TROJAN WS Routing
    location /trojan { if (\$http_upgrade != "websocket") { return 404; } proxy_pass http://127.0.0.1:10003; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
    
    # Default SSH Routing
    location / { proxy_pass http://127.0.0.1:8880; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host \$host; }
}
EOF
ln -sf /etc/nginx/sites-available/afterlifevpn /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default 2>/dev/null
systemctl restart nginx
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
echo "REALITY_PUBLIC=$PUBLIC_KEY" >> /usr/local/afterlifevpn/reality.key
echo "SS2022_KEY=$SERVER_KEY" > /usr/local/afterlifevpn/ss2022.key

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

echo -e "\e[1;33m[5/8] Installing Hysteria 2...\e[0m"
bash <(curl -fsSL https://app.hysteria.network/get.sh)
mkdir -p /etc/hysteria
cat > /etc/hysteria/config.yaml <<EOF
listen: :443
tls:
  cert: /etc/afterlifevpn/cert/fullchain.crt
  key: /etc/afterlifevpn/cert/private.key
auth:
  type: password
  password: supersecretpassword
masquerade:
  type: proxy
  proxy:
    url: https://www.microsoft.com
    rewriteHost: true
EOF
systemctl enable hysteria-server.service
systemctl restart hysteria-server.service

echo -e "\e[1;33m[6/8] Configuring Dropbear, BadVPN, WireGuard, & Ports...\e[0m"
sed -i 's/DROPBEAR_PORT=.*/DROPBEAR_PORT=109/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 109"/g' /etc/default/dropbear
if ! grep -q "/bin/false" /etc/shells; then echo "/bin/false" >> /etc/shells; fi
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

iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 443
netfilter-persistent save

echo -e "\e[1;33m[7/8] Pulling Scripts from GitHub...\e[0m"
REPO="https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main"
wget -q -O /usr/local/afterlifevpn/menu/menu.sh "$REPO/menu/menu.sh"
wget -q -O /usr/local/afterlifevpn/setup/xray-user.sh "$REPO/setup/xray-user.sh"
wget -q -O /usr/local/afterlifevpn/setup/hysteria-user.sh "$REPO/setup/hysteria-user.sh"
wget -q -O /usr/local/afterlifevpn/setup/squid.sh "$REPO/setup/squid.sh"
wget -q -O /usr/local/afterlifevpn/setup/dante.sh "$REPO/setup/dante.sh"

# NEW: Automatically pull the missing files we just created
wget -q -O /usr/local/afterlifevpn/setup/xray-add-vless.sh "$REPO/setup/xray-add-vless.sh"
wget -q -O /usr/local/afterlifevpn/setup/xray-add-trojan.sh "$REPO/setup/xray-add-trojan.sh"
wget -q -O /usr/local/afterlifevpn/setup/xray-online.sh "$REPO/setup/xray-online.sh"
wget -q -O /usr/local/afterlifevpn/setup/xray-renew.sh "$REPO/setup/xray-renew.sh"
wget -q -O /usr/local/afterlifevpn/setup/xray-del.sh "$REPO/setup/xray-del.sh"
wget -q -O /usr/local/afterlifevpn/setup/user-expire.sh "$REPO/setup/user-expire.sh"

chmod +x /usr/local/afterlifevpn/menu/menu.sh
chmod +x /usr/local/afterlifevpn/setup/*.sh

bash /usr/local/afterlifevpn/setup/squid.sh
bash /usr/local/afterlifevpn/setup/dante.sh

echo -e "\e[1;33m[8/8] Finalizing Setup & Automation...\e[0m"
ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/menu
ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/afterlife

# NEW: Setup Auto-Expiry Cron Job natively during installation
if ! crontab -l 2>/dev/null | grep -q "user-expire.sh"; then
    (crontab -l 2>/dev/null; echo "0 0 * * * bash /usr/local/afterlifevpn/setup/user-expire.sh") | crontab -
fi

echo -e "\n\e[0;32m✓ AFTERLIFE VPN Installation Complete!\e[0m"
echo -e "\e[1;37mType 'menu' or 'afterlife' to launch the dashboard.\e[0m\n"
