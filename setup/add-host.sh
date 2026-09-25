#!/bin/bash
# AFTERLIFE - Domain / Host / Nameserver Management
# GitHub path: setup/add-host-ssh.sh

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG="/usr/local/afterlifevpn/config.conf"
DOMAINS_FILE="/usr/local/afterlifevpn/domains.txt"
NS_FILE="/usr/local/afterlifevpn/nameserver.conf"

mkdir -p /usr/local/afterlifevpn
mkdir -p /etc/afterlifevpn/cert

if [ ! -f "$CONFIG" ]; then
    echo -e "${RED}Error: Config file not found:${NC} $CONFIG"
    echo -e "${YELLOW}Run the main AFTERLIFE installer first.${NC}"
    echo ""
    read -p "Press enter to continue..."
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG"

if [ -z "$DOMAIN" ]; then
    echo -e "${YELLOW}Warning: DOMAIN is empty in $CONFIG${NC}"
    echo "Some options will be limited until a primary domain is set."
    echo ""
fi

PUBLIC_IP=$(curl -s --max-time 8 ifconfig.me 2>/dev/null || curl -s --max-time 8 icanhazip.com 2>/dev/null || echo "UNKNOWN")

clear
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}   Multi-Domain Management${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "1. Add New Domain"
echo "2. List All Domains"
echo "3. Remove Domain"
echo "4. Set Primary Domain"
echo "5. Setup Nameserver (for SlowDNS / dnstt)"
echo "6. View Nameserver Info"
echo "0. Back to Menu"
echo ""
read -p "Select option: " option

case $option in
    1)
        clear
        read -p "Enter new domain (e.g., vpn2.example.com): " new_domain
        read -p "Enter email for SSL: " email

        if [[ -z "$new_domain" ]]; then
            echo -e "${RED}Domain cannot be empty.${NC}"
            read -p "Press enter to continue..."
            exit 1
        fi

        echo -e "${YELLOW}Adding domain: $new_domain${NC}"

        systemctl stop nginx 2>/dev/null
        ~/.acme.sh/acme.sh --issue -d "$new_domain" --standalone --accountemail "$email"
        issue_ok=$?
        systemctl start nginx 2>/dev/null

        if [ $issue_ok -ne 0 ]; then
            echo -e "${RED}Failed to issue certificate.${NC}"
            echo "Make sure the domain A record points to this server and port 80 is free."
            read -p "Press enter to continue..."
            exit 1
        fi

        mkdir -p "/etc/afterlifevpn/cert/$new_domain"
        ~/.acme.sh/acme.sh --installcert -d "$new_domain" \
            --key-file "/etc/afterlifevpn/cert/$new_domain/private.key" \
            --fullchain-file "/etc/afterlifevpn/cert/$new_domain/fullchain.crt"

        touch "$DOMAINS_FILE"
        grep -qxF "$new_domain" "$DOMAINS_FILE" || echo "$new_domain" >> "$DOMAINS_FILE"

        echo -e "${GREEN}Domain added successfully!${NC}"
        echo "Certificate installed at: /etc/afterlifevpn/cert/$new_domain/"
        ;;
    2)
        clear
        echo -e "${YELLOW}Configured Domains:${NC}"
        echo ""
        echo -e "Primary : ${GREEN}${DOMAIN:-Not set}${NC}"
        echo ""
        if [ -f "$DOMAINS_FILE" ] && [ -s "$DOMAINS_FILE" ]; then
            nl -w2 -s'. ' "$DOMAINS_FILE"
        else
            echo "No extra domains configured."
        fi
        echo ""
        ;;
    3)
        clear
        echo -e "${YELLOW}Remove Domain${NC}"
        echo ""
        if [ -f "$DOMAINS_FILE" ] && [ -s "$DOMAINS_FILE" ]; then
            nl -w2 -s'. ' "$DOMAINS_FILE"
            echo ""
            read -p "Enter domain number to remove: " num
            domain=$(sed -n "${num}p" "$DOMAINS_FILE")

            if [ -n "$domain" ]; then
                ~/.acme.sh/acme.sh --remove -d "$domain" 2>/dev/null
                rm -rf "/etc/afterlifevpn/cert/$domain"
                sed -i "${num}d" "$DOMAINS_FILE"
                echo -e 
