#!/bin/bash
clear

# Colors
CYAN='\e[1;36m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'
NC='\e[0m'

DB_FILE="/usr/local/afterlifevpn/users/xray_users.txt"
CONFIG="/usr/local/etc/xray/config.json"

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC} ${WHITE}› Xray › Delete User Account${NC}                           ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ ! -f "$DB_FILE" ]; then
    echo -e "  ${YELLOW}No user database found!${NC}\n"
    read -p "  Press [Enter] to return..."
    exit 1
fi

read -p "  Username to delete: " username
if [[ -z "$username" ]]; then exit 1; fi

if ! grep -q "^${username}|" "$DB_FILE"; then
    echo -e "\n  ${RED}✗ User '${username}' does not exist!${NC}\n"
    read -p "  Press [Enter] to return..."
    exit 1
fi

# 1. Extract the UUID before we delete the record
UUID=$(grep "^${username}|" "$DB_FILE" | cut -d'|' -f2)

# 2. Delete the user from the local flat-file database
sed -i "/^${username}|/d" "$DB_FILE"

# 3. Surgically rip the user out of the live Xray configuration
# This jq command safely removes the client if their email OR id matches
jq --arg user "$username" --arg uuid "$UUID" '
  .inbounds |= map(
    if .settings.clients then
      .settings.clients |= map(select(.email != $user and .id != $uuid))
    else
      .
    end
  )
' "$CONFIG" > /tmp/xray_clean.json && mv /tmp/xray_clean.json "$CONFIG"

# 4. Restart the engine to instantly kill their active connection
systemctl restart xray

echo -e "\n  ${GREEN}✓ User '${username}' completely wiped from server!${NC}\n"
read -p "  Press [Enter] to return..."
