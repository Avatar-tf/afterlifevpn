#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}   Multi-Domain Management${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "1. Add New Domain"
echo "2. List All Domains"
echo "3. Remove Domain"
echo "4. Set Primary Domain"
echo "0. Back to Menu"
echo ""
read -p "Select option: " option

case $option in
    1)
        clear
        read -p "Enter new domain (e.g., vpn2.example.com): " new_domain
        read -p "Enter email for SSL: " email
        
        echo -e "${YELLOW}Adding domain: $new_domain${NC}"
        
        # Issue SSL certificate
        ~/.acme.sh/acme.sh --issue -d "$new_domain" --standalone
        
        # Install certificate
        mkdir -p /etc/afterlifevpn/cert/$new_domain
        ~/.acme.sh/acme.sh --installcert -d "$new_domain" \
            --key-file /etc/afterlifevpn/cert/$new_domain/private.key \
            --fullchain-file /etc/afterlifevpn/cert/$new_domain/fullchain.crt
        
        # Add to domain list
        echo "$new_domain" >> /usr/local/afterlifevpn/domains.txt
        
        echo -e "${GREEN}Domain added successfully!${NC}"
        echo "Certificate installed at: /etc/afterlifevpn/cert/$new_domain/"
        ;;
    2)
        clear
        echo -e "${YELLOW}Configured Domains:${NC}"
        echo ""
        if [ -f /usr/local/afterlifevpn/domains.txt ]; then
            cat /usr/local/afterlifevpn/domains.txt | nl
        else
            source /usr/local/afterlifevpn/config.conf
            echo "1. $DOMAIN (Primary)"
        fi
        echo ""
        ;;
    3)
        clear
        echo -e "${YELLOW}Remove Domain${NC}"
        echo ""
        if [ -f /usr/local/afterlifevpn/domains.txt ]; then
            cat /usr/local/afterlifevpn/domains.txt | nl
            echo ""
            read -p "Enter domain number to remove: " num
            domain=$(sed -n "${num}p" /usr/local/afterlifevpn/domains.txt)
            
            if [ -n "$domain" ]; then
                # Remove certificate
                ~/.acme.sh/acme.sh --remove -d "$domain"
                rm -rf /etc/afterlifevpn/cert/$domain
                
                # Remove from list
                sed -i "${num}d" /usr/local/afterlifevpn/domains.txt
                
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
        if [ -f /usr/local/afterlifevpn/domains.txt ]; then
            cat /usr/local/afterlifevpn/domains.txt | nl
            echo ""
            read -p "Enter domain number to set as primary: " num
            domain=$(sed -n "${num}p" /usr/local/afterlifevpn/domains.txt)
            
            if [ -n "$domain" ]; then
                sed -i "s/DOMAIN=.*/DOMAIN=$domain/" /usr/local/afterlifevpn/config.conf
                echo -e "${GREEN}Primary domain set to: $domain${NC}"
                echo -e "${YELLOW}Restart services to apply changes${NC}"
            else
                echo -e "${RED}Invalid selection${NC}"
            fi
        else
            echo "No additional domains configured"
        fi
        ;;
    0)
        exit 0
        ;;
esac

read -p "Press enter to continue..."
