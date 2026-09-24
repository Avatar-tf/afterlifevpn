#!/bin/bash

DOMAIN=$1
MODE=${2:-single}  # single or hopping
PORT_RANGE=${3:-443}
INCLUDE_53=${4:-n}

echo -e "\e[1;33mInstalling Hysteria 2 (Multi-User Ready)...\e[0m"

# Download Hysteria 2
wget -O /usr/local/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
chmod +x /usr/local/bin/hysteria

# Create config and auth directories
mkdir -p /etc/hysteria
mkdir -p /usr/local/afterlifevpn/users

# ==========================================
# CREATE THE MULTI-USER AUTHENTICATION SCRIPT
# ==========================================
cat > /etc/hysteria/auth.sh <<'EOF'
#!/bin/bash
AUTH_PAYLOAD=$1
USERS_FILE="/usr/local/afterlifevpn/users/hysteria_users.txt"

# Extract username and password from the Hysteria 2 URI format (username:password)
USERNAME=$(echo "$AUTH_PAYLOAD" | cut -d':' -f1)
PASSWORD=$(echo "$AUTH_PAYLOAD" | cut -d':' -f2)

# 1. Check if user exists with exact password
USER_RECORD=$(grep "^${USERNAME}|${PASSWORD}|" "$USERS_FILE" 2>/dev/null)

if [ -z "$USER_RECORD" ]; then
    exit 1 # Authentication failed (User/Pass mismatch)
fi

# 2. Check Expiration
EXPIRY=$(echo "$USER_RECORD" | cut -d'|' -f3)
EXPIRY_SEC=$(date -d "$EXPIRY" +%s 2>/dev/null)
CURRENT_SEC=$(date +%s)

if [ "$CURRENT_SEC" -gt "$EXPIRY_SEC" ]; then
    exit 1 # Authentication failed (Account Expired)
fi

exit 0 # Authentication successful
EOF
chmod +x /etc/hysteria/auth.sh

# ==========================================
# CONFIGURE HYSTERIA YAML
# ==========================================
if [[ $MODE == "hopping" ]]; then
    if [[ $INCLUDE_53 == "y" ]]; then
        LISTEN_PORTS="53,$PORT_RANGE"
    else
        LISTEN_PORTS="$PORT_RANGE"
    fi
    
    cat > /etc/hysteria/config.yaml <<EOF
listen: :$LISTEN_PORTS

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

    # Configure firewall for port range
    IFS='-' read -ra RANGE <<< "$PORT_RANGE"
    START_PORT=${RANGE[0]}
    END_PORT=${RANGE[1]:-$START_PORT}
    
    iptables -A INPUT -p udp --dport $START_PORT:$END_PORT -j ACCEPT
    [[ $INCLUDE_53 == "y" ]] && iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables-save > /etc/iptables/rules.v4
    
    DISPLAY_PORTS="Port Hopping: $LISTEN_PORTS"
else
    cat > /etc/hysteria/config.yaml <<EOF
listen: :$PORT_RANGE

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

    # Allow single port
    iptables -A INPUT -p udp --dport $PORT_RANGE -j ACCEPT
    iptables-save > /etc/iptables/rules.v4
    
    DISPLAY_PORTS="Port: $PORT_RANGE"
fi

# Create systemd service
cat > /etc/systemd/system/hysteria.service <<EOF
[Unit]
Description=Hysteria Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Save initial config info for the menu
cat > /usr/local/afterlifevpn/hysteria-config.txt <<EOF
Hysteria 2 Configuration:
Server: $DOMAIN
$DISPLAY_PORTS
Protocol: UDP (QUIC)
Authentication: Multi-User (Command Mode)
EOF

systemctl daemon-reload
systemctl start hysteria
systemctl enable hysteria

echo -e "\e[0;32m✓ Hysteria 2 installed - $DISPLAY_PORTS (Multi-User Ready)\e[0m"
