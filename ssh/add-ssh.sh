#!/bin/bash

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Load configuration for Domain if it exists
if [ -f /usr/local/afterlifevpn/config.conf ]; then
    source /usr/local/afterlifevpn/config.conf
fi

# Detect Public IP and assign SERVER_HOST fallback
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "N/A")
SERVER_HOST="${DOMAIN:-$PUBLIC_IP}"
WS_PORT=$(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo 443)

clear
echo -e "${GREEN}=== Create SSH Account ===${NC}"
echo ""

# Input Prompts
read -p "Username: " username
if [[ -z "$username" ]]; then 
    echo -e "${RED}Error: Username cannot be empty!${NC}"
    exit 1
fi

read -p "Password: " password
read -p "Expiry (days): " days

# Added prompts to match your new detailed output
read -p "Max Devices (default 2): " devices
devices=${devices:-2}
read -p "Data Quota (default Unlimited): " quota
quota=${quota:-Unlimited}

# Check if user exists
if id "$username" &>/dev/null; then
    echo -e "${RED}User $username already exists!${NC}"
    exit 1
fi

# Calculate expiry date
exp_date=$(date -d "+$days days" +"%Y-%m-%d")

# Create user
useradd -e $exp_date -s /bin/false -M "$username"
echo "$username:$password" | chpasswd

# Save to database (appending devices and quota for future-proofing)
mkdir -p /usr/local/afterlifevpn/data
echo "$username|$password|$exp_date|$(date +%Y-%m-%d)|$devices|$quota" >> /usr/local/afterlifevpn/data/ssh-users.txt

# Display exact beautiful formatted info
clear
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e "         🔐 ${WHITE}AFTERLIFE VPN — SSH ACCOUNT${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo -e " 👤 ${WHITE}ACCOUNT${NC}"
echo -e "   Username    : ${GREEN}$username${NC}"
echo -e "   Password    : ${GREEN}$password${NC}"
echo -e "   Expires     : ${RED}$exp_date${NC}"
echo -e "   Devices     : ${YELLOW}$devices${NC}"
echo -e "   Data Quota  : ${YELLOW}$quota${NC}"
echo -e "   ${CYAN}══════════════════════════════${NC}"
echo -e " 🌐 ${WHITE}SERVER${NC}"
echo -e "   Host        : ${GREEN}$SERVER_HOST${NC}"
echo -e "   WS Ports    : ${YELLOW}80 / $WS_PORT${NC}"
echo -e "   SSL Ports   : ${YELLOW}443 / 777${NC}"
echo -e "   UDP-Custom  : ${YELLOW}port 36712 (same login)${NC}"
echo -e "   ${CYAN}══════════════════════════════${NC}"
echo -e " 📡 ${WHITE}HTTP CUSTOM PAYLOADS${NC}"
echo -e "   ① Port 80 — WebSocket"
echo -e "   ${YELLOW}GET / HTTP/1.1[crlf]Host: $SERVER_HOST[crlf]Upgrade: websocket[crlf][crlf]${NC}"
echo -e "   ${CYAN}══════════════════════════════${NC}"
echo -e "   ② Port 443 — WebSocket TLS (WSS)"
echo -e "   ${YELLOW}GET wss://$SERVER_HOST/ HTTP/1.1[crlf]Host: $SERVER_HOST[crlf]Upgrade: websocket[crlf][crlf]${NC}"
echo -e "   ${CYAN}══════════════════════════════${NC}"
echo -e "   ③ CONNECT (proxy / injector)"
echo -e "   ${YELLOW}CONNECT $SERVER_HOST:80 HTTP/1.1[crlf]Host: $SERVER_HOST[crlf][crlf]${NC}"
echo -e "   ${CYAN}══════════════════════════════${NC}"
echo -e "   ④ Front-Inject — replace [bug] with your bug host"
echo -e "   ${YELLOW}GET http://[bug]/ HTTP/1.1[crlf]Host: $SERVER_HOST[crlf]Upgrade: websocket[crlf][crlf]${NC}"
echo -e "   ${CYAN}══════════════════════════════${NC}"
echo -e "   ⑤ Header-Spoof (X-Online-Host)"
echo -e "   ${YELLOW}GET / HTTP/1.1[crlf]Host: $SERVER_HOST[crlf]X-Online-Host: $SERVER_HOST[crlf]X-Forward-Host: $SERVER_HOST[crlf]Upgrade: websocket[crlf][crlf]${NC}"
echo -e "${CYAN}════════════════════════════════════════════${NC}"
echo ""
