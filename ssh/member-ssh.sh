#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}=== SSH Account List ===${NC}"
echo ""

if [ ! -f /usr/local/afterlifevpn/data/ssh-users.txt ]; then
    echo -e "${YELLOW}No SSH accounts found${NC}"
    exit 0
fi

echo "Username | Expiry Date | Status"
echo "---------|-------------|--------"

while IFS='|' read -r username password expiry created; do
    # Check if expired
    if [[ $(date -d "$expiry" +%s) -lt $(date +%s) ]]; then
        status="${RED}EXPIRED${NC}"
    else
        days_left=$(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 ))
        status="${GREEN}Active ($days_left days)${NC}"
    fi
    
    echo -e "$username | $expiry | $status"
done < /usr/local/afterlifevpn/data/ssh-users.txt

echo ""
echo "Total accounts: $(wc -l < /usr/local/afterlifevpn/data/ssh-users.txt)"
