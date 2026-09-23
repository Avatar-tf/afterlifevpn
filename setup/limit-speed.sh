#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Bandwidth Limiter${NC}"
echo ""
echo "1. Set global bandwidth limit"
echo "2. Set per-user bandwidth limit"
echo "3. Remove bandwidth limits"
echo "4. Show current limits"
echo ""
read -p "Select option: " option

case $option in
    1)
        read -p "Enter download limit (Mbps): " download
        read -p "Enter upload limit (Mbps): " upload
        
        # Install wondershaper if not installed
        apt install -y wondershaper
        
        # Get primary interface
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        
        # Apply limits
        wondershaper -a $INTERFACE -d $((download * 1024)) -u $((upload * 1024))
        
        echo -e "${GREEN}Global bandwidth limit applied!${NC}"
        echo "Interface: $INTERFACE"
        echo "Download: ${download}Mbps"
        echo "Upload: ${upload}Mbps"
        ;;
    2)
        read -p "Enter username: " username
        read -p "Enter download limit (Mbps): " download
        read -p "Enter upload limit (Mbps): " upload
        
        # This requires more complex tc (traffic control) setup
        echo -e "${YELLOW}Per-user limiting requires advanced tc configuration${NC}"
        echo "This feature will be added in future updates"
        ;;
    3)
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        wondershaper -c -a $INTERFACE
        echo -e "${GREEN}Bandwidth limits removed!${NC}"
        ;;
    4)
        tc -s qdisc show
        ;;
esac
