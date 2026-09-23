#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

while true; do
    clear
    echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${GREEN}     AFTERLIFE VPN Management      ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}━━━ Configuration ━━━${NC}"
    echo -e "  1. Show VMess Configuration"
    echo -e "  2. Show Hysteria Configuration"
    echo -e "  3. Renew SSL Certificate"
    echo ""
    echo -e "${CYAN}━━━ User Management ━━━${NC}"
    echo -e "  4. Create SSH Account"
    echo -e "  5. Delete SSH Account"
    echo -e "  6. List SSH Accounts"
    echo ""
    echo -e "${CYAN}━━━ Service Management ━━━${NC}"
    echo -e "  7. Check Service Status"
    echo -e "  8. Restart All Services"
    echo -e "  9. Stop All Services"
    echo -e " 10. Start All Services"
    echo ""
    echo -e "${CYAN}━━━ Port Configuration ━━━${NC}"
    echo -e " 11. Change SSH WebSocket Port"
    echo -e " 12. Change Hysteria Port/Mode"
    echo -e " 13. Change Dropbear Port"
    echo -e " 14. Change VMess Port"
    echo ""
    echo -e "${CYAN}━━━ Monitoring & Maintenance ━━━${NC}"
    echo -e " 15. Show Active Connections"
    echo -e " 16. View System Information"
    echo -e " 17. Clear System Logs"
    echo -e " 18. Bandwidth Limiter"
    echo ""
    echo -e "${CYAN}━━━ Backup & Restore ━━━${NC}"
    echo -e " 19. Backup Configuration"
    echo -e " 20. Restore Configuration"
    echo ""
    echo -e "${CYAN}━━━ Advanced ━━━${NC}"
    echo -e " 21. Speedtest"
    echo -e " 22. Update Script"
    echo ""
    echo -e "  0. Exit"
    echo ""
    echo -e "${BLUE}════════════════════════════════════${NC}"
    read -p "Select option: " option
    
    case $option in
        1)
            clear
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo -e "${GREEN}      VMess Configuration${NC}"
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo ""
            if [ -f /usr/local/afterlifevpn/vmess-config.txt ]; then
                cat /usr/local/afterlifevpn/vmess-config.txt
            else
                echo -e "${RED}VMess configuration not found${NC}"
            fi
            echo ""
            read -p "Press enter to continue..."
            ;;
        2)
            clear
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo -e "${GREEN}    Hysteria 2 Configuration${NC}"
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo ""
            if [ -f /usr/local/afterlifevpn/hysteria-config.txt ]; then
                cat /usr/local/afterlifevpn/hysteria-config.txt
            else
                echo -e "${RED}Hysteria configuration not found${NC}"
            fi
            echo ""
            read -p "Press enter to continue..."
            ;;
        3)
            clear
            echo -e "${YELLOW}Renewing SSL Certificate...${NC}"
            if [ -f /usr/local/afterlifevpn/config.conf ]; then
                source /usr/local/afterlifevpn/config.conf
                ~/.acme.sh/acme.sh --renew -d "$DOMAIN" --force
                systemctl restart ws-ssh xray hysteria
                echo -e "${GREEN}SSL certificate renewed and services restarted!${NC}"
            else
                echo -e "${RED}Configuration file not found${NC}"
            fi
            read -p "Press enter to continue..."
            ;;
        4)
            clear
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo -e "${GREEN}       Create SSH Account${NC}"
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo ""
            read -p "Enter username: " username
            read -p "Enter password: " password
            read -p "Expiry days (0 for no expiry): " days
            
            # Check if user exists
            if id "$username" &>/dev/null; then
                echo -e "${RED}User $username already exists!${NC}"
            else
                if [ "$days" -eq 0 ]; then
                    useradd -M -s /bin/false $username
                    EXPIRY="Never"
                else
                    useradd -M -s /bin/false -e $(date -d "+$days days" +%Y-%m-%d) $username
                    EXPIRY=$(date -d "+$days days" +%Y-%m-%d)
                fi
                echo "$username:$password" | chpasswd
                
                echo ""
                echo -e "${GREEN}✓ SSH account created successfully!${NC}"
                echo -e "${BLUE}════════════════════════════════════${NC}"
                echo "Username: $username"
                echo "Password: $password"
                echo "Expires: $EXPIRY"
                echo -e "${BLUE}════════════════════════════════════${NC}"
            fi
            read -p "Press enter to continue..."
            ;;
        5)
            clear
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo -e "${GREEN}       Delete SSH Account${NC}"
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo ""
            read -p "Enter username to delete: " username
            
            if id "$username" &>/dev/null; then
                userdel -f $username 2>/dev/null
                echo -e "${GREEN}User $username deleted successfully!${NC}"
            else
                echo -e "${RED}User $username not found!${NC}"
            fi
            read -p "Press enter to continue..."
            ;;
        6)
            clear
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo -e "${GREEN}         SSH User Accounts${NC}"
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo ""
            echo -e "${YELLOW}Username${NC}          ${YELLOW}Expiry Date${NC}"
            echo "────────────────────────────────────"
            
            # List users with UID >= 1000 (non-system users)
            while IFS=: read -r username _ uid _ _ _ _; do
                if [ "$uid" -ge 1000 ] && [ "$username" != "nobody" ]; then
                    expiry=$(chage -l "$username" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
                    printf "%-15s %s\n" "$username" "$expiry"
                fi
            done < /etc/passwd
            
            echo ""
            read -p "Press enter to continue..."
            ;;
        7)
            clear
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo -e "${GREEN}         Service Status${NC}"
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo ""
            
            services=("ws-ssh:SSH WebSocket" "xray:VMess/Xray" "hysteria:Hysteria 2" "udp-custom:UDP Custom" "dropbear:Dropbear SSH")
            
            for service_info in "${services[@]}"; do
                IFS=':' read -r service_name display_name <<< "$service_info"
                status=$(systemctl is-active $service_name 2>/dev/null)
                if [ "$status" == "active" ]; then
                    echo -e "${display_name}: ${GREEN}● Running${NC}"
                else
                    echo -e "${display_name}: ${RED}● Stopped${NC}"
                fi
            done
            
            echo ""
            read -p "Press enter to continue..."
            ;;
        8)
            clear
            echo -e "${YELLOW}Restarting all services...${NC}"
            systemctl restart ws-ssh xray hysteria udp-custom dropbear
            echo -e "${GREEN}✓ All services restarted successfully!${NC}"
            sleep 2
            ;;
        9)
            clear
            echo -e "${YELLOW}Stopping all services...${NC}"
            systemctl stop ws-ssh xray hysteria udp-custom dropbear
            echo -e "${GREEN}✓ All services stopped!${NC}"
            sleep 2
            ;;
        10)
            clear
            echo -e "${YELLOW}Starting all services...${NC}"
            systemctl start ws-ssh xray hysteria udp-custom dropbear
            echo -e "${GREEN}✓ All services started!${NC}"
            sleep 2
            ;;
        11)
            clear
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo -e "${GREEN}   Change SSH WebSocket Port${NC}"
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo ""
            current_port=$(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo "unknown")
            echo "Current port: $current_port"
            echo ""
            read -p "Enter new SSH WebSocket port: " new_port
            
            # Validate port number
            if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
                echo -e "${RED}Invalid port number!${NC}"
            else
                # Update Python script
                sed -i "s/start_server = websockets.serve(proxy, \"0.0.0.0\", .*/start_server = websockets.serve(proxy, \"0.0.0.0\", $new_port, ssl=ssl_context)/" /usr/local/bin/ws-ssh.py
                
                # Save new port
                echo "$new_port" > /usr/local/afterlifevpn/ws-port.conf
                
                # Update config
                sed -i "s/WS_PORT=.*/WS_PORT=$new_port/" /usr/local/afterlifevpn/config.conf
                
                # Restart service
                systemctl restart ws-ssh
                
                echo -e "${GREEN}✓ SSH WebSocket port changed to $new_port${NC}"
                echo -e "${YELLOW}⚠ Update your firewall rules if needed!${NC}"
            fi
            read -p "Press enter to continue..."
            ;;
        12)
            clear
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo -e "${GREEN}   Hysteria Port Configuration${NC}"
            echo -e "${BLUE}════════════════════════════════════${NC}"
            echo ""
            echo "1. Single Port Mode"
            echo "2. Port Hopping Mode"
            echo ""
            read -p "Select mode: " mode_choice
            
            # Get current password
            current_password=$(grep "password:" /etc/hysteria/config.yaml 2>/dev/null | awk '{print $2}')
            
            if [[ $mode_choice == "1" ]]; then
                read -p "Enter port (default 443): " single_port
                single_port=${single_port:-443}
                
                # Update config
                cat > /etc/hysteria/config.yaml <<EOF
listen: :$single_port

tls:
  cert: /etc/afterlifevpn/cert/fullchain.crt
  key: /etc/afterlifevpn/cert/private.key

auth:
  type: password
  password: $current_password

masquerade:
  type: proxy
  proxy:
    url: https://www.google.com
    rewriteHost: true

quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432
EOF
                
                systemctl restart hysteria
                echo -e "${GREEN}✓ Hysteria 2 set to single port: $single_port${NC}"
                
            elif [[ $mode_choice == "2" ]]; then
                read -p "Enter port range (e.g., 20000-40000): " port_range
                read -p "Include port 53? (y/n): " inc_53
                
                if [[ $inc_53 == "y" ]]; then
                    listen_ports="53,$port_range"
                else
                    listen_ports="$port_range"
                fi
                
                # Update config
                cat > /etc/hysteria/config.yaml <<EOF
listen: :$listen_ports

tls:
  cert: /etc/afterlifevpn/cert/fullchain.crt
  key: /etc/afterlifevpn/cert/private.key

auth:
  type: password
  password: $current_password

masquerade:
  type: proxy
  proxy:
    url: https://www.google.com
    rewriteHost: true

quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432
EOF
                
                # Update firewall
                IFS='-' read -ra RANGE <<< "$port_range"
                START_PORT=${RANGE[0]}
                END_PORT=${RANGE[1]:-$START_PORT}
                
                iptables -A INPUT -p udp --dport $START_PORT:$END_PORT -j ACCEPT
                [
