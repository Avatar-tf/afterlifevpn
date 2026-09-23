#!/bin/bash

# Enable TCP BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# Verify BBR is enabled
if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
    echo "✓ TCP BBR enabled successfully"
else
    echo "✗ Failed to enable TCP BBR"
fi
