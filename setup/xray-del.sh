#!/bin/bash
CYAN='\e[1;36m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'
NC='\e[0m'
DB_FILE="/usr/local/afterlifevpn/users/xray_users.txt"
CONFIG="/usr/local/etc/xray/config.json"
username="${1:-}"
echo -e "${CYAN}=== Delete VMess user ===${NC}"
if [ ! -f "$DB_FILE" ]; then
    echo "No user database found"
    exit 1
fi
if [ -z "$username" ]; then
    read -r -p "Username to delete: " username
fi
if [ -z "$username" ]; then
    exit 1
fi
LINE=$(grep -E "^${username}[:|]" "$DB_FILE" || true)
if [ -z "$LINE" ]; then
    echo "User ${username} does not exist"
    exit 1
fi
if echo "$LINE" | grep -q '|'; then
    UUID=$(echo "$LINE" | cut -d'|' -f2)
else
    UUID=$(echo "$LINE" | cut -d: -f2)
fi
sed -i -E "/^${username}[:|]/d" "$DB_FILE"
if [ -f "$CONFIG" ]; then
    jq --arg user "$username" --arg uuid "$UUID" '
      .inbounds |= map(
        if .settings.clients then
          .settings.clients |= map(select(.email != $user and .id != $uuid))
        else . end
      )
    ' "$CONFIG" > /tmp/xray_clean.json && mv /tmp/xray_clean.json "$CONFIG"
    chmod 644 "$CONFIG"
fi
systemctl restart xray
echo "Deleted ${username}"
