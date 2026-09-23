#!/bin/bash

DOMAIN=$1
MODE=${2:-single}  # single or hopping
PORT_RANGE=${3:-443}
INCLUDE_53=${4:-n}

# Download Hysteria 2
wget -O /usr/local/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
chmod +x /usr/local/bin/hysteria

# Generate password
PASSWORD=$(openssl rand -base64 16)

# Create config directory
mkdir -p /etc/hysteria

# Configure based on mode
if [[ $MODE == "hopping" ]]; then
    # Port hopping mode
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
  type: password
  password: $PASSWORD

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
    
    # Allow port range
    iptables -A INPUT -p udp --dport $START_PORT:$END_PORT -j ACCEPT
    [[ $INCLUDE_53 == "y" ]] && iptables -A INPUT -p udp --dport 53 -j ACCEPT
    iptables-save > /etc/iptables/rules.v4
    
    DISPLAY_PORTS="Port Hopping: $LISTEN_PORTS"
else
    # Single port mode
    cat > /etc/hysteria/config.yaml <<EOF
listen: :$PORT_RANGE

tls:
  cert: /etc/afterlifevpn/cert/fullchain.crt
  key: /etc/afterlifevpn/cert/private.key

auth:
  type: password
  password: $PASSWORD

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

[Install]
WantedBy=multi-user.target
EOF

# Save config
cat > /usr/local/afterlifevpn/hysteria-config.txt <<EOF
Hysteria 2 Configuration:
Server: $DOMAIN
$DISPLAY_PORTS
Password: $PASSWORD
Protocol: UDP

Client Configuration:
- Server: $DOMAIN
- Auth: $PASSWORD
- Protocol: hysteria2
- TLS: Enabled
EOF

systemctl daemon-reload
systemctl start hysteria
systemctl enable hysteria

echo "Hysteria 2 installed - $DISPLAY_PORTS"
echo "Password: $PASSWORD"
