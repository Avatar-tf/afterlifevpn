#!/bin/bash
# AFTERLIFE Multi-Protocol Nginx Installer
# Supports: SSH-WS (NetMod), VMess, VLESS, Trojan, and easy extension

set -e

echo "[*] Installing / Updating AFTERLIFE Nginx configuration..."

# Create directory for certs if it doesn't exist (ssl.sh usually handles this)
mkdir -p /etc/afterlifevpn/cert

# Backup existing config if present
if [ -f /etc/nginx/sites-available/afterlifevpn ]; then
    cp /etc/nginx/sites-available/afterlifevpn /etc/nginx/sites-available/afterlifevpn.bak.$(date +%Y%m%d-%H%M%S)
fi

# Write the multi-protocol nginx config
cat > /etc/nginx/sites-available/afterlifevpn << 'EOF'
# ============================================================
# AFTERLIFE Multi-Protocol Nginx Config
# Protocols:
#   /          → SSH-WS (NetMod)          → 127.0.0.1:8880
#   /vmess     → VMess (Xray)             → 127.0.0.1:10001
#   /vless     → VLESS (Xray)             → 127.0.0.1:10002
#   /trojan    → Trojan (Xray)            → 127.0.0.1:10003
# ============================================================

map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

# ---------- HTTP (port 80) ----------
server {
    listen 80;
    listen [::]:80;
    server_name _;

    # Redirect everything to HTTPS (optional but recommended)
    # return 301 https://$host$request_uri;

    # Or keep SSH-WS available on port 80 too
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

# ---------- HTTPS (port 443) ----------
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name _;

    ssl_certificate     /etc/afterlifevpn/cert/fullchain.crt;
    ssl_certificate_key /etc/afterlifevpn/cert/private.key;

    # Modern SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # ----- VMess -----
    location /vmess {
        if ($http_upgrade != "websocket") {
            return 404;
        }
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

    # ----- VLESS -----
    location /vless {
        if ($http_upgrade != "websocket") {
            return 404;
        }
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

    # ----- Trojan -----
    location /trojan {
        if ($http_upgrade != "websocket") {
            return 404;
        }
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

    # ----- Default: SSH-WS (NetMod) -----
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

# Enable the site
mkdir -p /etc/nginx/sites-enabled
ln -sf /etc/nginx/sites-available/afterlifevpn /etc/nginx/sites-enabled/afterlifevpn

# Remove default site if it exists (optional, cleaner)
rm -f /etc/nginx/sites-enabled/default

# Test and reload
if nginx -t; then
    systemctl reload nginx
    echo
    echo "[+] Nginx configuration updated and reloaded successfully."
    echo "[+] Active routes:"
    echo "    /          → SSH-WS     (127.0.0.1:8880)"
    echo "    /vmess     → VMess      (127.0.0.1:10001)"
    echo "    /vless     → VLESS      (127.0.0.1:10002)"
    echo "    /trojan    → Trojan     (127.0.0.1:10003)"
else
    echo "[!] Nginx configuration test failed. Please check the error above."
    exit 1
fi
