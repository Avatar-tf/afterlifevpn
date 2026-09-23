#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}   Bandwidth Limiter${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "1. Set Global Bandwidth Limit"
echo "2. Set Per-User Limit (SSH)"
echo "3. Remove All Limits"
echo "4. Show Current Limits"
echo "5. Show Bandwidth Usage"
echo "0. Back to Menu"
echo ""
read -p "Select option: " option

case $option in
    1)
        clear
        echo -e "${YELLOW}Global Bandwidth Limit${NC}"
        echo ""
        read -p "Enter download limit in Mbps (e.g., 100): " download
        read -p "Enter upload limit in Mbps (e.g., 50): " upload
        
        # Install wondershaper if not installed
        if ! command -v wondershaper &> /dev/null; then
            echo "Installing wondershaper..."
            apt install -y wondershaper
        fi
        
        # Get primary interface
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        
        # Apply limits (convert Mbps to Kbps)
        wondershaper -a $INTERFACE -d $((download * 1024)) -u $((upload * 1024))
        
        # Save configuration
        cat > /etc/systemd/system/wondershaper.service <<EOF
[Unit]
Description=Wondershaper Bandwidth Limiter
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/wondershaper -a $INTERFACE -d $((download * 1024)) -u $((upload * 1024))
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable wondershaper
        
        echo -e "${GREEN}Global bandwidth limit applied!${NC}"
        echo "Interface: $INTERFACE"
        echo "Download: ${download} Mbps"
        echo "Upload: ${upload} Mbps"
        ;;
    2)
        clear
        echo -e "${YELLOW}Per-User Bandwidth Limit${NC}"
        echo ""
        echo "Active SSH users:"
        who | awk '{print $1}' | sort | uniq
        echo ""
        read -p "Enter username: " username
        read -p "Enter speed limit in KB/s (e.g., 1024 = 1MB/s): " limit
        
        # Create user limit using cgroups
        if [ ! -d /sys/fs/cgroup/net_cls ]; then
            echo "Setting up cgroups..."
            mkdir -p /sys/fs/cgroup/net_cls
            mount -t cgroup -o net_cls none /sys/fs/cgroup/net_cls
        fi
        
        # Create user group
        mkdir -p /sys/fs/cgroup/net_cls/$username
        echo 0x00100001 > /sys/fs/cgroup/net_cls/$username/net_cls.classid
        
        # Apply tc rules
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        tc qdisc add dev $INTERFACE root handle 1: htb default 30
        tc class add dev $INTERFACE parent 1: classid 1:1 htb rate ${limit}kbit
        tc filter add dev $INTERFACE protocol ip parent 1:0 prio 1 handle 1: cgroup
        
        echo -e "${GREEN}Bandwidth limit set for user: $username${NC}"
        echo "Speed limit: ${limit} KB/s"
        ;;
    3)
        clear
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        
        # Remove wondershaper
        wondershaper -c -a $INTERFACE 2>/dev/null
        systemctl disable wondershaper 2>/dev/null
        rm -f /etc/systemd/system/wondershaper.service
        
        # Remove tc rules
        tc qdisc del dev $INTERFACE root 2>/dev/null
        
        echo -e "${GREEN}All bandwidth limits removed!${NC}"
        ;;
    4)
        clear
        echo -e "${YELLOW}Current Bandwidth Limits:${NC}"
        echo ""
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        echo "Interface: $INTERFACE"
        echo ""
        tc -s qdisc show dev $INTERFACE
        echo ""
        tc -s class show dev $INTERFACE
        ;;
    5)
        clear
        echo -e "${YELLOW}Bandwidth Usage:${NC}"
        echo ""
        
        # Install vnstat if not available
        if ! command -v vnstat &> /dev/null; then
            echo "Installing vnstat..."
            apt install -y vnstat
            systemctl enable vnstat
            systemctl start vnstat
            sleep 2
        fi
        
        vnstat -i $(ip route | grep default | awk '{print $5}' | head -n1)
        ;;
    0)
        exit 0
        ;;
esac

read -p "Press enter to continue..."
