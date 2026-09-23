#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}   Active Connections Monitor${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# SSH Connections
echo -e "${YELLOW}SSH Connections:${NC}"
SSH_COUNT=$(netstat -tnp | grep ':22' | grep ESTABLISHED | wc -l)
echo "Total: $SSH_COUNT"
netstat -tnp | grep ':22' | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr
echo ""

# Dropbear Connections
echo -e "${YELLOW}Dropbear Connections:${NC}"
DROPBEAR_COUNT=$(netstat -tnp | grep dropbear | grep ESTABLISHED | wc -l)
echo "Total: $DROPBEAR_COUNT"
netstat -tnp | grep dropbear | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr
echo ""

# WebSocket Connections
echo -e "${YELLOW}WebSocket Connections:${NC}"
WS_PORT=$(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo "443")
WS_COUNT=$(netstat -tnp | grep ":$WS_PORT" | grep ESTABLISHED | wc -l)
echo "Total: $WS_COUNT"
echo ""

# Xray Connections
echo -e "${YELLOW}Xray (VMess) Connections:${NC}"
XRAY_COUNT=$(netstat -tnp | grep xray | grep ESTABLISHED | wc -l)
echo "Total: $XRAY_COUNT"
echo ""

# Hysteria Connections
echo -e "${YELLOW}Hysteria Connections:${NC}"
HYSTERIA_COUNT=$(netstat -unp | grep hysteria | wc -l)
echo "Total: $HYSTERIA_COUNT"
echo ""

# Logged in users
echo -e "${YELLOW}Logged in Users:${NC}"
who
echo ""

# Total bandwidth usage
echo -e "${YELLOW}Network Usage:${NC}"
vnstat -l 2>/dev/null || echo "Install vnstat for bandwidth monitoring: apt install vnstat"
