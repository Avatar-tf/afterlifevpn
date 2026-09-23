#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}   Network Optimization${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "1. Apply All Optimizations (Recommended)"
echo "2. Enable TCP Fast Open"
echo "3. Optimize Network Buffers"
echo "4. Enable IP Forwarding"
echo "5. Optimize Connection Tracking"
echo "6. Show Current Settings"
echo "7. Reset to Default"
echo "0. Back to Menu"
echo ""
read -p "Select option: " option

apply_all_optimizations() {
    echo -e "${YELLOW}Applying network optimizations...${NC}"
    
    # Backup current sysctl
    cp /etc/sysctl.conf /etc/sysctl.conf.backup
    
    # Apply optimizations
    cat >> /etc/sysctl.conf <<EOF

# AFTERLIFE VPN Network Optimizations
# TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Increase TCP buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Enable IP forwarding
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Increase connection tracking
net.netfilter.nf_conntrack_max = 1000000
net.nf_conntrack_max = 1000000

# TCP optimization
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_frto = 0
net.ipv4.tcp_mtu_probing = 0
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10

# Increase max connections
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535

# Security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# File descriptors
fs.file-max = 1000000
EOF
    
    # Apply settings
