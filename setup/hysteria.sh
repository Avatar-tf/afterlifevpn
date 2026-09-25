#!/bin/bash
# ==========================================================
# AFTERLIFE - Hysteria 2 Installer (Clean + Ready for Port 53 Menu)
# ==========================================================

if [[ $EUID -ne 0 ]]; then
   echo -e "\033[0;31mError: This script must be run as root.\033[0m"
   exit 1
fi

# Load domain
if [[ -f /usr/local/afterlifevpn/config.conf ]]; then
    source /usr/local/afterlifevpn/config.conf
else
    echo -e "\033[0;31mError: Domain not found. Run the main installer first.\033[0m"
    exit 1
fi

# Defaults
MODE="443"
PORT=443
SALAMANDER="n"
OBFS_PASSWORD=""

clear
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo -e "\e[1;33m      AFTERLIFE - Hysteria 2 Installer\e[0m"
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo
echo -e "  1) Recommended   → UDP 443  (best, no conflict with nginx)"
echo -e "  2) Port 53 Mode  → UDP 53   (for shared / restrictive networks)"
echo -e "  3) Custom Port"
echo
read -p "Select mode [1-3]: " mode_choice

case $mode_choice in
    2)
        MODE="53"
        PORT=53
        ;;
    3)
        read -p "Enter custom UDP port: " PORT
        MODE="custom"
        ;;
    *)
        MODE="443"
        PORT=443
        ;;
esac

echo
read -p "Enable Salamander obfuscation? (y/n) [n]: " SALAMANDER
SALAMANDER=${SALAMANDER:-n}

echo
echo -e "\e[1;33mInstalling / Updating Hysteria 2...\e[0m"

# Download latest binary
wget -q -O /usr/local/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
chmod +x /usr/local/bin/hysteria

mkdir -p /etc/hysteria
mkdir -p /usr/local/afterlifevpn/users
touch /usr/local/afterlifevpn/users/hysteria_users.txt

# ==========================================
# Auth script (supports both user:pass and plain password)
# ==========================================
cat > /etc/hysteria/auth.sh << 'EOF'
#!/bin/bash
AUTH_PAYLOAD="$1"
USERS_FILE="/usr/local/afterlifevpn/users/hysteria_users.txt"

if [[ "$AUTH_PAYLOAD" == *":"* ]]; then
    USERNAME=$(echo "$AUTH_PAYLOAD" | cut -d':' -f1)
    PASSWORD=$(echo "$AUTH_PAYLOAD" | cut -d':' -f2)
    USER_RECORD=\( (grep "^ \){USERNAME}|${PASSWORD}|" "$USERS_FILE" 2>/dev/null)
else
    PASSWORD="$AUTH_PAYLOAD"
    USER_RECORD=\( (grep "| \){PASSWORD}|" "$USERS_FILE" 2>/dev/null | head -1)
fi

[[ -z "$USER_RECORD" ]] && exit 1

EXPIRY=$(echo "$USER_RECORD" | cut -d'|' -f3)
EXPIRY_SEC=$(date -d "$EXPIRY" +%s 2>/dev/null || echo 0)
CURRENT_SEC=$(date +%s)

[[ "$CURRENT_SEC" -gt "$EXPIRY_SEC" ]] && exit 1

exit 0
EOF
chmod +x /etc/hysteria/auth.sh

# ==========================================
# Prepare port 53 if needed
# ==========================================
if [[ "$PORT" == "53" ]]; then
    echo -e "\e[1;33mPreparing UDP port 53...\e[0m"
    if systemctl is-active --quiet systemd-resolved; then
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        mkdir -p /etc/systemd/resolved.conf.d
        cat > /etc/systemd/resolved.conf.d/disable-stub.conf << EOF
[Resolve]
DNSStubListener=no
EOF
        systemctl daemon-reload
    fi
fi

# ==========================================
# Generate config
# ==========================================
if [[ "$SALAMANDER" == "y" || "$SALAMANDER" == "Y" ]]; then
    OBFS_PASSWORD=$(openssl rand -hex 8)
    OBFS_BLOCK="obfs:
  type: salamander
  salamander:
    password: $OBFS_PASSWORD"
else
    OBFS_BLOCK=""
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

# Firewall
if command -v ufw >/dev/null 2>&1; then
    ufw allow ${PORT}/udp >/dev/null 2>&1
else
    iptables -I INPUT -p udp --dport $PORT -j ACCEPT 2>/dev/null
    netfilter-persistent save >/dev/null 2>&1 || true
fi

# Save settings
cat > /usr/local/afterlifevpn/hysteria-config.txt << EOF
MODE=$MODE
PORT=$PORT
SALAMANDER=$SALAMANDER
OBFS_PASSWORD=$OBFS_PASSWORD
DOMAIN=$DOMAIN
EOF

systemctl daemon-reload
systemctl enable hysteria
systemctl restart hysteria

# ==========================================
# Final output
# ==========================================
echo
echo -e "\e[0;32m✓ Hysteria 2 installed / updated successfully!\e[0m"
echo
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo -e "\e[1;33m         HYSTERIA 2 INFORMATION\e[0m"
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo -e " Domain     : $DOMAIN"
echo -e " Port       : $PORT (UDP)"
echo -e " Mode       : $MODE"
echo -e " Salamander : $SALAMANDER"
[[ -n "$OBFS_PASSWORD" ]] && echo -e " Obfs Pass  : $OBFS_PASSWORD"
echo
echo -e "\e[1;33mExample Links (after you create a user):\e[0m"
echo
echo -e " STANDARD"
echo -e " hy2://PASSWORD@$DOMAIN:$PORT?insecure=1&sni=$DOMAIN#Afterlife-Hy2"
echo
echo -e " PORT-HOPPING"
echo -e " hy2://PASSWORD@$DOMAIN:$PORT,20000-50000?insecure=1&sni=$DOMAIN#Afterlife-Hy2-Hop"
echo
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo -e " Now create users from the menu."
echo -e "\e[1;36m══════════════════════════════════════════\e[0m"
echo
