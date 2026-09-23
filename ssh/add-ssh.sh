#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${GREEN}=== Create SSH Account ===${NC}"
echo ""

# Input
read -p "Username: " username
read -p "Password: " password
read -p "Expiry (days): " days

# Check if user exists
if id "$username" &>/dev/null; then
    echo -e "${RED}User $username already exists!${NC}"
    exit 1
fi

# Calculate expiry date
exp_date=$(date -d "+$days days" +"%Y-%m-%d")

# Create user
useradd -e $exp_date -s /bin/false -M $username
echo "$username:$password" | chpasswd

# Save to database
mkdir -p /usr/local/afterlifevpn/data
echo "$username|$password|$exp_date|$(date +%Y-%m-%d)" >> /usr/local/afterlifevpn/data/ssh-users.txt

# Display info
clear
echo -e "${GREEN}=== SSH Account Created ===${NC}"
echo ""
echo "Username   : $username"
echo "Password   : $password"
echo "Expired    : $exp_date"
echo ""
echo "Connection Info:"
echo "Host       : $(curl -s ifconfig.me)"
echo "Port SSH   : 22"
echo "Port Dropbear: 442"
echo "Port WS    : $(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo 443)"
echo "Port WS SSL: $(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo 443)"
echo ""
