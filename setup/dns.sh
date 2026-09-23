#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}   DNS Configuration${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "1. Use Cloudflare DNS (1.1.1.1)"
echo "2. Use Google DNS (8.8.8.8)"
echo "3. Use Quad9 DNS (9.9.9.9)"
echo "4. Use OpenDNS (208.67.222.222)"
echo "5. Custom DNS"
echo "6. Show Current DNS"
echo "7. Test DNS Resolution"
echo "0. Back to Menu"
echo ""
read -p "Select option: " option

set_dns() {
    DNS1=$1
    DNS2=$2
    NAME=$3
    
    # Backup current resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.backup
    
    # Set new DNS
    cat > /etc/resolv.conf <<EOF
# AFTERLIFE VPN - $NAME
nameserver $DNS1
nameserver $DNS2
EOF
    
    # Make it immutable (prevent overwriting)
    chattr +i /etc/resolv.conf
    
    echo -e "${GREEN}DNS changed to $NAME${NC}"
    echo "Primary: $DNS1"
    echo "Secondary: $DNS2"
}

case $option in
    1)
        clear
        set_dns "1.1.1.1" "1.0.0.1" "Cloudflare DNS"
        ;;
    2)
        clear
        set_dns "8.8.8.8" "8.8.4.4" "Google DNS"
        ;;
    3)
        clear
        set_dns "9.9.9.9" "149.112.112.112" "Quad9 DNS"
        ;;
    4)
        clear
        set_dns "208.67.222.222" "208.67.220.220" "OpenDNS"
        ;;
    5)
        clear
        read -p "Enter primary DNS: " dns1
        read -p "Enter secondary DNS: " dns2
        set_dns "$dns1" "$dns2" "Custom DNS"
        ;;
    6)
        clear
        echo -e "${YELLOW}Current DNS Configuration:${NC}"
        echo ""
        cat /etc/resolv.conf
        echo ""
        echo -e "${YELLOW}Active DNS Servers:${NC}"
        systemd-resolve --status | grep "DNS Servers" -A 2
        ;;
    7)
        clear
        echo -e "${YELLOW}Testing DNS Resolution...${NC}"
        echo ""
        
        echo "Testing google.com:"
        dig google.com +short
        echo ""
        
        echo "Testing cloudflare.com:"
        dig cloudflare.com +short
        echo ""
        
        echo "DNS Response Time:"
        for dns in 1.1.1.1 8.8.8.8 9.9.9.9; do
            echo -n "$dns: "
            dig @$dns google.com | grep "Query time"
        done
        ;;
    0)
        exit 0
        ;;
esac

read -p "Press enter to continue..."
