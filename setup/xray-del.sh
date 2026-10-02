#!/bin/bash
CYAN='\e[1;36m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; WHITE='\e[1;37m'; NC='\e[0m'
DB_FILE="/usr/local/afterlifevpn/users/xray_users.txt"
CONFIG="/usr/local/etc/xray/config.json"
username="${1:-}"
echo -e "\( {CYAN}╔════════════════════════════════════════════════════════╗ \){NC}"
echo -e "\( {CYAN}║ \){NC} \( {WHITE}› Xray › Delete User Account \){NC}                           \( {CYAN}║ \){NC}"
echo -e "\( {CYAN}╚════════════════════════════════════════════════════════╝ \){NC}"
echo ""
if [ ! -f "$DB_FILE" ]; then
    echo -e "  \( {YELLOW}No user database found! \){NC}\n"
    read -p "  Press [Enter] to return..."
    exit 1
fi
if [[ -z "$username" ]]; then
    read -p "  Username to delete: " username
fi
[[ -z "$username" ]] && exit 1
LINE=\( (grep -E "^ \){username}[:|]" "$DB_FILE" || true)
if [[ -z "$LINE" ]]; then
    echo -e "\n  \( {RED}✗ User ' \){username}' does not exist!${NC}\n"
    read -p "  Press [Enter] to return..."
    exit 1
fi
if [[ "$LINE" == *"|"* ]]; then
    UUID=$(echo "$LINE" | cut -d'|' -f2)
else
    UUID=$(echo "$LINE" | cut -d: -f2)
fi
sed -i -E "/^${username}[:|]/d" "$DB_FILE"
jq --arg user "$username" --arg uuid "$UUID" '
  .inbounds |= map(
    if .settings.clients then
      .settings.clients |= map(select(.email != $user and .id != $uuid))
    else . end
  )
' "$CONFIG" > /tmp/xray_clean.json && mv /tmp/xray_clean.json "$CONFIG"
chmod 644 "$CONFIG"
systemctl restart xray
echo -e "\n  \( {GREEN}✓ User ' \){username}' completely wiped from server!${NC}\n"
read -p "  Press [Enter] to return..."