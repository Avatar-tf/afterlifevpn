#!/bin/bash

DOMAIN=$1

# Install Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Generate UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

# Create Xray config
cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0
          }
        ]
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

# Save VMess config
cat > /usr/local/afterlifevpn/vmess-config.txt <<EOF
VMess Configuration:
Address: $DOMAIN
Port: 443
UUID: $UUID
AlterID: 0
Network: ws
Path: /vmess
TLS: enabled
EOF

systemctl restart xray
systemctl enable xray

echo "VMess installed with UUID: $UUID"
