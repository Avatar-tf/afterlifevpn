#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${GREEN}=== Renew SSH Account ===${NC}"
echo ""

# Show existing users
echo "Existing SSH accounts:"
cat /usr/local/afterlifevpn/data/ssh-users.txt 2>/dev/null | awk -F'|' '{print $1" (Expires: "$3")"}' | nl
echo ""

read -p "Enter username to renew: " username
read -p "Add days: " days

# Check if user exists
if ! id "$username" &>/dev/null; then
    echo -e "${RED}User $username not found!${NC}"
    exit 1
fi

# Calculate new expiry
current_exp=$(chage -l $username | grep "Account expires" | awk -F': ' '{print $2}')
if [[ "$current_exp" == "never" ]]; then
    new_exp=$(date -d "+$days days" +"%Y-%m-%d")
else
    new_exp=$(date -d "$current_exp +$days days" +"%Y-%m-%d")
fi

# Update expiry
chage -E $new_exp $username

# Update database
sed -i "s/^$username|.*|.*|/$username|$(grep "^$username|" /usr/local/afterlifevpn/data/ssh-users.txt | cut -d'|' -f2)|$new_exp|/" /usr/local/afterlifevpn/data/ssh-users.txt

echo -e "${GREEN}Account renewed!${NC}"
echo "Username: $username"
echo "New expiry: $new_exp"
