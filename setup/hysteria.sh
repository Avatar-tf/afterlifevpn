#!/bin/bash
# ==========================================================
# AFTERLIFE - Hysteria 2 Installer (Multi-User + Port 53 + Salamander)
# ==========================================================

if [[ $EUID -ne 0 ]]; then
   echo -e "\033[0;31mError: This script must be run as root.\033[0m"
   exit 1
fi

# Load domain from main config
if [[ -f /usr/local/afterlifevpn/config.conf ]]; then
    source /usr/local/afterlifevpn/config.conf
else
    echo -e "\033[0;31mError: Domain not found. Please run the main installer first.\033[0m"
    exit 1
fi

# Defaults
MODE="single"          # single | 53
PORT=36712
SALAMANDER="n"
PASSWORD=$(openssl rand -hex 8)

clear
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo -e "\e[1;33m      AFTERLIFE - Hysteria 2 Installer\e[0m"
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo
echo -e "  1) Standard Mode (Port 36712)"
echo -e "  2) Port 53 Mode (UDP 53)"
echo
read -p "Select mode [1-2]: " mode_choice

case $mode_choice in
    2)
        MODE="53"
        PORT=53
        ;;
    *)
        MODE="single"
        PORT=36712
        ;;
esac

echo
read -p "Enable Salamander obfuscation? (y/n) [n]: " SALAMANDER
SALAMANDER=${SALAMANDER:-n}

echo
echo -e "\e[1;33mInstalling Hysteria 2...\e[0m"

# Download latest Hysteria 2
wget -q -O /usr/local/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
chmod +x /usr/local/bin/hysteria

mkdir -p /etc/hysteria
mkdir -p /usr/local/afterlifevpn/users
touch /usr/local/afterlifevpn/users/hysteria_users.txt

# ==========================================
# Multi-user authentication script
# ==========================================
cat > /etc/hysteria/auth.sh << 'EOF'
#!/bin/bash
AUTH_PAYLOAD="$1"
USERS_FILE="/usr/local/afterlifevpn/users/hysteria_users.txt"

USERNAME=$(echo "$AUTH_PAYLOAD" | cut -d':' -f1)
PASSWORD=$(echo "$AUTH_PAYLOAD" | cut -d':' -f2)

USER_RECORD=$(grep "^${USERNAME}|${PASSWORD}|" "$USERS_FILE" 2>/dev/null)
if [[ -z "$USER_RECORD" ]]; then
    exit 1
fi

EXPIRY=$(echo "$USER_RECORD" | cut -d'|' -f3)
EXPIRY_SEC=$(date -d "$EXPIRY" +%s 2>/dev/null || echo 0)
CURRENT_SEC=$(date +%s)

if [[ "$CURRENT_SEC" -gt "$EXPIRY_SEC" ]]; then
    exit 1
fi

exit 0
EOF
chmod +x /etc/hysteria/auth.sh

# ==========================================
# Handle Port 53 (free the port if needed)
# ==========================================
if [[ "$MODE" == "53" ]]; then
    echo -e "\e[1;33mPreparing UDP port 53...\e[0m"
    
    # Stop systemd-resolved if it is using port 53
    if systemctl is-active --quiet systemd-resolved; then
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        # Prevent it from taking port 53 again
        mkdir -p /etc/systemd/resolved.conf.d
        cat > /etc/systemd/resolved.conf.d/disable-stub.conf << EOF
[Resolve]
DNSStubListener=no
EOF
        systemctl daemon-reload
    fi
fi

# ==========================================
# Generate Hysteria config
# ==========================================
OBFS_BLOCK=""
if [[ "$SALAMANDER" == "y" || "$SALAMANDER" == "Y" ]]; then
    OBFS_PASSWORD=$(openssl rand -hex 8)
    OBFS_BLOCK="obfs:
  type: salamander
  salamander:
    password: $OBFS_PASSWORD"
fi

cat > /etc/hysteria/config.yaml << EOF
listen: :$PORT

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

quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432

$OBFS_BLOCK
EOF

# ==========================================
# Systemd service
# ==========================================
cat > /etc/systemd/system/hysteria.service << EOF
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

# ==========================================
# Firewall
# ==========================================
if command -v ufw >/dev/null 2>&1; then
    ufw allow ${PORT}/udp >/dev/null 2>&1
else
    iptables -I INPUT -p udp --dport $PORT -j ACCEPT
    netfilter-persistent save >/dev/null 2>&1 || true
fi

# ==========================================
# Save configuration info
# ==========================================
cat > /usr/local/afterlifevpn/hysteria-config.txt << EOF
MODE=$MODE
PORT=$PORT
SALAMANDER=$SALAMANDER
OBFS_PASSWORD=${OBFS_PASSWORD:-}
DOMAIN=$DOMAIN
EOF

systemctl daemon-reload
systemctl enable hysteria
systemctl restart hysteria

# ==========================================
# Generate example links (for display)
# ==========================================
echo
echo -e "\e[0;32m✓ Hysteria 2 installed successfully!\e[0m"
echo
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo -e "\e[1;33m         HYSTERIA 2 INFORMATION\e[0m"
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo -e " Domain     : $DOMAIN"
echo -e " Port       : $PORT"
echo -e " Mode       : $MODE"
echo -e " Salamander : $SALAMANDER"
echo
echo -e "\e[1;33mExample Links (after you create a user):\e[0m"
echo
echo -e " STANDARD LINK"
echo -e " hy2://USERNAME:PASSWORD@$DOMAIN:$PORT?insecure=1&sni=$DOMAIN#Afterlife-Hy2"
echo
echo -e " PORT-HOPPING STYLE LINK"
echo -e " hy2://USERNAME:PASSWORD@$DOMAIN:$PORT,20000-50000?insecure=1&sni=$DOMAIN#Afterlife-Hy2-Hop"
echo
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo -e " Use the menu to create Hysteria users."
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo
