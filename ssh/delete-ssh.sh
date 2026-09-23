#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${GREEN}=== Delete SSH Account ===${NC}"
echo ""

# Show existing users
echo "Existing SSH accounts:"
cat /usr/local/afterlifevpn/data/ssh-users.txt 2>/dev/null | cut -d'|' -f1 | nl
echo ""

read -p "Enter username to delete: " username

# Check if user exists
if ! id "$username" &>/dev/null; then
    echo -e "${RED}User $username not found!${NC}"
    exit 1
fi

# Delete user
userdel -f $username

# Remove from database
sed -i "/^$username|/d" /usr/local/afterlifevpn/data/ssh-users.txt

# Kill active sessions
pkill -u $username

echo -e "${GREEN}User $username deleted successfully!${NC}"
