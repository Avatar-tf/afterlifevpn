#!/bin/bash

# Install Squid
apt install -y squid apache2-utils

# Backup original config
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

# Configure Squid
cat > /etc/squid/squid.conf <<'EOF'
http_port 3128

# Authentication
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm AFTERLIFE VPN Proxy
auth_param basic credentialsttl 2 hours

# ACL
acl authenticated proxy_auth REQUIRED
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 1025-65535
acl CONNECT method CONNECT

# Access rules
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow authenticated
http_access deny all

# Logging
access_log /var/log/squid/access.log
cache_log /var/log/squid/cache.log

# Cache
cache deny all
EOF

# Create password file
touch /etc/squid/passwd
chmod 640 /etc/squid/passwd
chown proxy:proxy /etc/squid/passwd

# Restart Squid
systemctl restart squid
systemctl enable squid

echo "Squid HTTP Proxy installed on port 3128"
