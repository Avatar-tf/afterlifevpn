#!/bin/bash
clear
source /usr/local/afterlifevpn/config.conf
DOMAIN_HOST=${DOMAIN:-"$(curl -s ifconfig.me)"}

CYAN='\e[1;36m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'
NC='\e[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}${WHITE}› Xray › Create Trojan Account${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

read -p "  Username: " username
if [[ -z "$username" ]]; then exit 1; fi

if grep -q "^$username|" /usr/local/afterlifevpn/users/xray_users.txt 2>/dev/null; then
    echo -e "\n  ${RED}✗ User already exists!${NC}\n"
    read -p "  Press [Enter] to return..."
    exit 1
fi

read -p "  Expiry (days): " days
# Generate a secure password string for Trojan
PASS=$(opensslLet's close the loop on your Xray ecosystem. 

These three scripts mirror the logic and UI formatting of your VMess setup, ensuring they write to the same master database (`/etc/xray/xray_users.txt`) and seamlessly inject into your `config.json`.

<Image src="image_agent_tag_18298518930278516265" alt="Terminal windows showing server logs and active connections" caption="System logs and active connection tracking" />

---

<Sequence>
  <Step title="xray-add-vless.sh" subtitle="Generates UUIDs and injects into VLESS WS">
    This script specifically targets a VLESS inbound using WebSockets. Create `setup/xray-add-vless.sh`:
