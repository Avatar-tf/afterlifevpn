#!/bin/bash

# Install Dropbear
apt install -y dropbear

# Configure Dropbear
systemctl stop dropbear
systemctl disable dropbear

# Create custom config
cat > /etc/default/dropbear <<EOF
NO_START=0
DROPBEAR_PORT=442
DROPBEAR_EXTRA_ARGS="-p 442"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

# Create banner
cat > /etc/issue.net <<EOF
================================
   Welcome to AFTERLIFE VPN
================================
Unauthorized access is prohibited
EOF

# Start Dropbear
systemctl start dropbear
systemctl enable dropbear

echo "Dropbear SSH installed on port 442"
