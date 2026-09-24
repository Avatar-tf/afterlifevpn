#!/bin/bash

DOMAIN=$1

echo -e "\e[1;33mInstalling Xray (VMess Multi-User Ready)...\e[0m"

# Install required JSON parser and UUID tools for the menu system
apt-get update
apt-get install -y jq uuid-runtime

# Install Xray Core
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Create necessary directories for the menu database
mkdir -p /usr/local/afterlifevpn/users

# Create Xray config (Multi-User Foundation)
cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        },
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/afterlifevpn/cert/fullchain.crt",
              "keyFile": "/etc/afterlifevpn/cert/private.key"
            }
          ]
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

# Save base config info for the menu
cat > /usr/local/afterlifevpn/vmess-config.txt <<EOF
VMess Core Configuration:
Address: $DOMAIN
Port: 443
Network: WebSocket (ws)
Path: /vmess
TLS: Enabled
Authentication: Multi-User (JSON Dynamic)
EOF

systemctl restart xray
systemctl enable xray

echo -e "\e[0;32m✓ Xray installed successfully. Base configuration ready for user injection.\e[0m"
