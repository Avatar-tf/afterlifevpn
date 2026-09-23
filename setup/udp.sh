#!/bin/bash

# Install badvpn-udpgw
wget -O /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw64"
chmod +x /usr/bin/badvpn-udpgw

# Create systemd service
cat > /etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=UDP Custom Port 53
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start udp-custom
systemctl enable udp-custom

# Configure iptables for port 53
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 7300
iptables-save > /etc/iptables/rules.v4

echo "UDP Custom installed on port 53"
