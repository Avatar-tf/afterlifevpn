#!/bin/bash
# AFTERLIFE - Domain / Host / Nameserver Management

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

if [ -f "$CONFIG" ]; then
    source "$CONFIG"
fi

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "UNKNOWN")

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

        # Stop nginx briefly if standalone cert is used (port 80 must be free)
        systemctl stop nginx 2>/dev/null

        ~/.acme.sh/acme.sh --issue -d "$new_domain" --standalone --accountemail "$email"
        issue_ok=$?

        systemctl start nginx 2>/dev/null

        if [ $issue_ok -ne 0 ]; then
            echo -e "${RED}Failed to issue certificate. Make sure the domain points to this server.${NC}"
            read -p "Press enter to continue..."
            exit 1
        fi

        mkdir -p /etc/afterlifevpn/cert/$new_domain
        ~/.acme.sh/acme.sh --installcert -d "$new_domain" \
            --key-file /etc/afterlifevpn/cert/$new_domain/private.key \
            --fullchain-file /etc/afterlifevpn/cert/$new_domain/fullchain.crt

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
                rm -rf /etc/afterlifevpn/cert/$domain
                sed -i "${num}d" "$DOMAINS_FILE"
                echo -e "${GREEN}Domain $domain removed!${NC}"
            else
                echo -e "${RED}Invalid selection${NC}"
            fi
        else
            echo "No additional domains configured"
        fi
        ;;
    4)
        clear
        echo -e "${YELLOW}Set Primary Domain${NC}"
        echo ""
        if [ -f "$DOMAINS_FILE" ] && [ -s "$DOMAINS_FILE" ]; then
            nl -w2 -s'. ' "$DOMAINS_FILE"
            echo ""
            read -p "Enter domain number to set as primary: " num
            domain=$(sed -n "${num}p" "$DOMAINS_FILE")

            if [ -n "$domain" ]; then
                if grep -q "^DOMAIN=" "$CONFIG" 2>/dev/null; then
                    sed -i "s/^DOMAIN=.*/DOMAIN=$domain/" "$CONFIG"
                else
                    echo "DOMAIN=$domain" >> "$CONFIG"
                fi
                echo -e "${GREEN}Primary domain set to: $domain${NC}"
                echo -e "${YELLOW}Restart services to apply changes${NC}"
            else
                echo -e "${RED}Invalid selection${NC}"
            fi
        else
            echo "No additional domains configured"
        fi
        ;;
    5)
        clear
        echo -e "${CYAN}================================${NC}"
        echo -e "${GREEN}   Nameserver Setup (SlowDNS)${NC}"
        echo -e "${CYAN}================================${NC}"
        echo ""
        echo -e "Current domain : ${YELLOW}${DOMAIN:-Not set}${NC}"
        echo -e "Server IP      : ${YELLOW}$PUBLIC_IP${NC}"
        echo ""
        echo "Suggested nameserver host:"
        echo -e "  ${GREEN}ns.${DOMAIN:-yourdomain.com}${NC}"
        echo ""
        read -p "Enter nameserver host [default ns.${DOMAIN}]: " ns_host
        ns_host=${ns_host:-ns.${DOMAIN}}

        if [[ -z "$DOMAIN" || -z "$ns_host" ]]; then
            echo -e "${RED}Domain / nameserver cannot be empty.${NC}"
            read -p "Press enter to continue..."
            exit 1
        fi

        cat > "$NS_FILE" <<EOF
NS_HOST=$ns_host
NS_IP=$PUBLIC_IP
DOMAIN=$DOMAIN
EOF

        echo ""
        echo -e "${GREEN}Saved nameserver config.${NC}"
        echo ""
        echo -e "${YELLOW}Add these DNS records at your domain registrar:${NC}"
        echo ""
        echo "  Type : A"
        echo "  Name : $ns_host"
        echo "  Value: $PUBLIC_IP"
        echo "  TTL  : 300"
        echo ""
        echo "  Type : NS"
        echo "  Name : sl (or any SlowDNS prefix you want)"
        echo "  Value: $ns_host"
        echo ""
        echo "Example SlowDNS target later:"
        echo -e "  ${GREEN}sl.${DOMAIN}${NC}"
        echo ""
        echo -e "${YELLOW}Note:${NC} dnstt itself is not installed by this step."
        echo "This only stores the nameserver info for the Port 53 menu."
        ;;
    6)
        clear
        echo -e "${YELLOW}Nameserver Info${NC}"
        echo ""
        if [ -f "$NS_FILE" ]; then
            source "$NS_FILE"
            echo -e " Nameserver : ${GREEN}${NS_HOST}${NC}"
            echo -e " Points to  : ${GREEN}${NS_IP}${NC}"
            echo -e " Domain     : ${GREEN}${DOMAIN}${NC}"
        else
            echo -e "${RED}No nameserver configured yet.${NC}"
            echo "Use option 5 first."
        fi
        echo ""
        ;;
    0)
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        ;;
esac

read -p "Press enter to continue..."
