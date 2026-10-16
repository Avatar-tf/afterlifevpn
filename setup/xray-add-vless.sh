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
echo -e "${CYAN}║${NC}${WHITE}› Xray › Create VLess (WS) Account${NC}                     ${CYAN}║${NC}"
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
UUID=$(uuidgen)
EXP_DATE=$(date -d "+$days days" +"%Y-%m-%d")
CREATED=$(date +"%Y-%m-%d")

# Add to Database
echo "$username|$UUID|$EXP_DATE|$CREATED" >> /usr/local/afterlifevpn/users/xray_users.txt

# Inject into Xray Config (assumes you have a VLESS WS inbound)
jq --arg uuid "$UUID" --arg user "$username" '
  (.inbounds[] | select(.protocol == "vless" and .streamSettings.network == "ws") | .settings.clients) += [{"id": $uuid, "email": $user}]
' /usr/local/etc/xray/config.json > /tmp/x_tmp.json && mv /tmp/x_tmp.json /usr/local/etc/xray/config.json
if ! xray run -test -config /usr/local/etc/xray/config.json || ! systemctl restart xray; then
    echo "Xray could not apply the new VLESS account; inspect its config and service logs."
    exit 1
fi

VLESS_LINK="vless://${UUID}@${DOMAIN_HOST}:443?encryption=none&security=tls&sni=${DOMAIN_HOST}&type=ws&host=${DOMAIN_HOST}&path=%2Fvless#${username}-AFTERLIFE"

clear
echo -e "${CYAN}╭────────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${CYAN}│${NC}                       ${WHITE}VLESS ACCOUNT CREATED${NC}                        ${CYAN}│${NC}"
echo -e "${CYAN}╰────────────────────────────────────────────────────────────────────╯${NC}"
echo -e " ${WHITE}Username${NC}     :${GREEN}$username${NC}"
echo -e " ${WHITE}UUID${NC}         :${GREEN}$UUID${NC}"
echo -e " ${WHITE}Expires${NC}      :${RED}$EXP_DATE${NC}"
echo -e " ${CYAN}────────────────────────────────────────────────────────${NC}"
echo -e " ${WHITE}Protocol${NC}     : ${CYAN}VLESS${NC}"
echo -e " ${WHITE}Transport${NC}    : ${CYAN}WebSocket (WS)${NC}"
echo -e " ${WHITE}Encryption${NC}   : ${CYAN}TLS via Nginx (WSS)${NC}"
echo -e " ${WHITE}Port${NC}         : ${CYAN}443${NC}"
echo -e " ${WHITE}WS Path${NC}      : ${CYAN}/vless${NC}"
echo -e " ${WHITE}SNI / WS Host${NC}: ${CYAN}$DOMAIN_HOST${NC}"
echo -e " ⚡ ${WHITE}VLESS • WSS / TLS LINK${NC}"
echo -e "   ${YELLOW}$VLESS_LINK${NC}\n"

if command -v qrencode &> /dev/null; then
    echo -e " ${WHITE}[QR CODE]${NC}"
    qrencode -t ANSIUTF8 "$VLESS_LINK"
fi

read -p "  Press [Enter] to return..."
