#!/bin/bash

# ==========================================================
# AFTERLIFE VPN - MASTER INSTALLATION SCRIPT
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

echo -e "\e[1;33m[1/6] Updating System & Installing Dependencies...\e[0m"
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget jq uuid-runtime qrencode apache2-utils dropbear squid dante-server python3-websockets nginx socat cron

# Create Directory Structure
mkdir -p /usr/local/afterlifevpn/{menu,setup,users,data}
mkdir -p /etc/afterlifevpn/cert
echo "DOMAIN=$DOMAIN" > /usr/local/afterlifevpn/config.conf
echo "8880" > /usr/local/afterlifevpn/ws-port.conf

echo -e "\e[1;33m[2/6] Generating SSL Certificates...\e[0m"
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m admin@$DOMAIN
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone
~/.acme.sh/acme.sh --installcert -d $DOMAIN \
    --fullchainpath /etc/afterlifevpn/cert/fullchain.crt \
    --keypath /etc/afterlifevpn/cert/private.key
chmod 644 /etc/afterlifevpn/cert/*

echo -e "\e[1;33m[3/6] Configuring Nginx Reverse Proxy...\e[0m"
cat > /etc/nginx/sites-available/afterlifevpn <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name _;

    ssl_certificate /etc/afterlifevpn/cert/fullchain.crt;
    ssl_certificate_key /etc/afterlifevpn/cert/private.key;

    location /vmess {
        if (\$http_upgrade != "websocket") {
            return 404;
        }
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location / {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF
ln -sf /etc/nginx/sites-available/afterlifevpn /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default 2>/dev/null
systemctl restart nginx
systemctl enable nginx

echo -e "\e[1;33m[4/6] Installing Back-Room Protocols...\e[0m"
# Xray (VMess on internal port 10001)
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
systemctl restart xray
systemctl enable xray

echo -e "\e[1;33m[5/6] Pulling Scripts from GitHub...\e[0m"
REPO="https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main"

# Download Menu and setup scripts
wget -q -O /usr/local/afterlifevpn/menu/menu.sh "$REPO/menu/menu.sh"
wget -q -O /usr/local/afterlifevpn/setup/xray-user.sh "$REPO/setup/xray-user.sh"
wget -q -O /usr/local/afterlifevpn/setup/hysteria-user.sh "$REPO/setup/hysteria-user.sh"
wget -q -O /usr/local/afterlifevpn/setup/squid.sh "$REPO/setup/squid.sh"
wget -q -O /usr/local/afterlifevpn/setup/dante.sh "$REPO/setup/dante.sh"

chmod +x /usr/local/afterlifevpn/menu/menu.sh
chmod +x /usr/local/afterlifevpn/setup/*.sh

# Run Proxy Setup Scripts
bash /usr/local/afterlifevpn/setup/squid.sh
bash /usr/local/afterlifevpn/setup/dante.sh

echo -e "\e[1;33m[6/6] Finalizing Setup...\e[0m"
ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/menu
ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/afterlife

echo -e "\n\e[0;32m✓ AFTERLIFE VPN Installation Complete!\e[0m"
echo -e "\e[1;37mType 'menu' or 'afterlife' to launch the dashboard.\e[0m\n"
