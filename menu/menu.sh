#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

while true; do
    clear
    echo -e "${BLUE}================================${NC}"
    echo -e "${GREEN}   AFTERLIFE VPN Management${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    echo -e "1. Show VMess Configuration"
    echo -e "2. Show Hysteria Configuration"
    echo -e "3. Create SSH Account"
    echo -e "4. Renew SSL Certificate"
    echo -e "5. Check Service Status"
    echo -e "6. Restart All Services"
    echo -e "7. Change Dropbear Port"
    echo -e "8. Change SSH WebSocket Port"
    echo -e "9. Change Hysteria Port/Mode"
    echo -e "10. View System Info"
    echo -e "11. Backup Configuration"
    echo -e "12. Restore Configuration"
    echo -e "13. Clear Logs"
    echo -e "14. Show Active Connections"
    echo -e "15. Bandwidth Limiter"
    echo -e "0. Exit"
    echo ""
    read -p "Select option: " option
    
    case $option in
        1)
            clear
            cat /usr/local/afterlifevpn/vmess-config.txt
            read -p "Press enter to continue..."
            ;;
        2)
            clear
            cat /usr/local/afterlifevpn/hysteria-config.txt
            read -p "Press enter to continue..."
            ;;
        3)
            clear
            read -p "Enter username: " username
            read -p "Enter password: " password
            read -p "Expiry days: " days
            
            useradd -M -s /bin/false -e $(date -d "+$days days" +%Y-%m-%d) $username
            echo "$username:$password" | chpasswd
            
            echo -e "${GREEN}SSH account created!${NC}"
            echo "Username: $username"
            echo "Password: $password"
            echo "Expires: $(date -d "+$days days" +%Y-%m-%d)"
            read -p "Press enter to continue..."
            ;;
        4)
            clear
            source /usr/local/afterlifevpn/config.conf
            ~/.acme.sh/acme.sh --renew -d "$DOMAIN" --force
            systemctl restart ws-ssh xray hysteria
            echo -e "${GREEN}SSL certificate renewed and services restarted!${NC}"
            read -p "Press enter to continue..."
            ;;
        5)
            clear
            echo "Service Status:"
            echo ""
            echo -n "SSH WebSocket: "
            systemctl is-active ws-ssh
            echo -n "Xray (VMess): "
            systemctl is-active xray
            echo -n "Hysteria 2: "
            systemctl is-active hysteria
            echo -n "UDP Custom: "
            systemctl is-active udp-custom
            echo -n "Dropbear: "
            systemctl is-active dropbear
            echo ""
            read -p "Press enter to continue..."
            ;;
        6)
            clear
            systemctl restart ws-ssh xray hysteria udp-custom dropbear
            echo -e "${GREEN}All services restarted!${NC}"
            read -p "Press enter to continue..."
            ;;
        7)
            clear
            read -p "Enter new Dropbear port: " port
            sed -i "s/DROPBEAR_PORT=.*/DROPBEAR_PORT=$port/" /etc/default/dropbear
            sed -i "s/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"-p $port\"/" /etc/default/dropbear
            systemctl restart dropbear
            echo -e "${GREEN}Dropbear port changed to $port${NC}"
            read -p "Press enter to continue..."
            ;;
        8)
            clear
            echo "Current SSH WebSocket port: $(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo 'unknown')"
            read -p "Enter new SSH WebSocket port: " new_port
            
            # Update Python script
            sed -i "s/start_server = websockets.serve(proxy, \"0.0.0.0\", .*/start_server = websockets.serve(proxy, \"0.0.0.0\", $new_port, ssl=ssl_context)/" /usr/local/bin/ws-ssh.py
            
            # Save new port
            echo "$new_port" > /usr/local/afterlifevpn/ws-port.conf
            
            # Update config
            sed -i "s/WS_PORT=.*/WS_PORT=$new_port/" /usr/local/afterlifevpn/config.conf
            
            # Restart service
            systemctl restart ws-ssh
            
            echo -e "${GREEN}SSH WebSocket port changed to $new_port${NC}"
            echo -e "${YELLOW}Make sure to update your firewall rules!${NC}"
            read -p "Press enter to continue..."
            ;;
        9)
            clear
            echo "Hysteria 2 Port Configuration"
            echo ""
            echo "1. Single Port Mode"
            echo "2. Port Hopping Mode"
            echo ""
            read -p "Select mode: " mode_choice
            
            if [[ $mode_choice == "1" ]]; then
                read -p "Enter port (default 443): " single_port
                single_port=${single_port:-443}
                
                # Get current password
                CURRENT_PASSWORD=$(grep "password:" /etc/hysteria/config.yaml | awk '{print $2}')
                
                # Update config
                cat > /etc/hysteria/config.yaml <<EOF
listen: :$single_port

tls:
  cert: /etc/afterlifevpn/cert/fullchain.crt
  key: /etc/afterlifevpn/cert/private.key

auth:
  type: password
  password: $CURRENT_PASSWORD

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
                echo -e "${GREEN}Hysteria 2 set to single port: $single_port${NC}"
                
            elif [[ $mode_choice == "2" ]]; then
                read -p "Enter port range (e.g., 20000-40000): " port_range
                read -p "Include port 53? (y/n): " inc_53
                
                if [[ $inc_53 == "y" ]]; then
                    listen_ports="53,$port_range"
                else
                    listen_ports="$port_range"
                fi
                
                # Get current password
                CURRENT_PASSWORD=$(grep "password:" /etc/hysteria/config.yaml | awk '{print $2}')
                
                # Update config
                cat > /etc/hysteria/config.yaml <<EOF
listen: :$listen_ports

tls:
  cert: /etc/afterlifevpn/cert/fullchain.crt
  key: /etc/afterlifevpn/cert/private.key

auth:
  type: password
  password: $CURRENT_PASSWORD

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
                [[ $inc_53 == "y" ]] && iptables -A INPUT -p udp --dport 53 -j ACCEPT
                iptables-save > /etc/iptables/rules.v4
                
                systemctl restart hysteria
                echo -e "${GREEN}Hysteria 2 set to port hopping: $listen_ports${NC}"
            fi
            
            read -p "Press enter to continue..."
            ;;
        10)
            clear
            echo "System Information:"
            echo ""
            echo "Hostname: $(hostname)"
            echo "IP Address: $(curl -s ifconfig.me)"
            echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
            echo "Kernel: $(uname -r)"
            echo "Uptime: $(uptime -p)"
            echo ""
            echo "Port Configuration:"
            echo "- SSH WebSocket: $(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo 'unknown')"
            echo "- VMess: 443"
            echo "- Hysteria: $(grep "listen:" /etc/hysteria/config.yaml | awk '{print $2}' | sed 's/://')"
            echo "- Dropbear: $(grep DROPBEAR_PORT /etc/default/dropbear | cut -d'=' -f2)"
            echo "- UDP Custom: 53"
            echo ""
            read -p "Press enter to continue..."
            ;;
        11)
            clear
            bash /usr/local/afterlifevpn/setup/backup.sh
            read -p "Press enter to continue..."
            ;;
        12)
            clear
            bash /usr/local/afterlifevpn/setup/restore.sh
            read -p "Press enter to continue..."
            ;;
        13)
            clear
            bash /usr/local/afterlifevpn/setup/clear-log.sh
            read -p "Press enter to continue..."
            ;;
        14)
            clear
            bash /usr/local/afterlifevpn/setup/running.sh
            read -p "Press enter to continue..."
            ;;
        15)
            clear
            bash /usr/local/afterlifevpn/setup/limit-speed.sh
            read -p "Press enter to continue..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 2
            ;;
    esac
done
