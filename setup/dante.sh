#!/bin/bash

# Install Dante
apt install -y dante-server

# Get primary interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

# Backup original config
cp /etc/danted.conf /etc/danted.conf.bak 2>/dev/null

# Configure Dante
cat > /etc/danted.conf <<EOF
logoutput: syslog
internal: 0.0.0.0 port = 1080
external: $INTERFACE

socksmethod: username
user.privileged: root
user.unprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}
EOF

# Restart Dante
systemctl restart danted
systemctl enable danted

echo "Dante SOCKS5 Proxy installed on port 1080"
