#!/bin/bash

# Enforce Root Privileges
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[0;31mError: This script must be run as root.\033[0m"
   exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Load configuration
if [ -f /usr/local/afterlifevpn/config.conf ]; then
    source /usr/local/afterlifevpn/config.conf
fi

# Get system information
get_system_info() {
    HOSTNAME=$(hostname)
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "N/A")
    OS_VERSION=$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
    UPTIME=$(uptime -p | sed 's/up //')
    CPU_CORES=$(nproc)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    CPU_USAGE_INT=${CPU_USAGE%.*}
    
    read TOTAL_RAM USED_RAM <<< $(free -m | awk 'NR==2{print $2, $3}')
    RAM_PERCENT=$((USED_RAM * 100 / TOTAL_RAM))
    
    read TOTAL_DISK USED_DISK DISK_PERCENT <<< $(df -h / | awk 'NR==2{print $2, $3, $5}' | tr -d '%')
}

# Create progress bar
create_bar() {
    local percent=$1
    local width=12
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    local fill_bar=""
    local empty_bar=""
    
    if [[ $filled -gt 0 ]]; then printf -v fill_bar "%${filled}s" ""; fi
    if [[ $empty -gt 0 ]]; then printf -v empty_bar "%${empty}s" ""; fi
    
    fill_bar=${fill_bar// /█}
    empty_bar=${empty_bar// /░}
    
    printf "[%s%s]" "$fill_bar" "$empty_bar"
}

# Check service status
check_service() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        echo -e "${GREEN}●${NC}"
    else
        echo -e "${RED}○${NC}"
    fi
}

# Count total users
count_users() {
    local total=0
    
    if [ -f /usr/local/afterlifevpn/users/ssh_users.txt ]; then
        local ssh_users=$(wc -l < /usr/local/afterlifevpn/users/ssh_users.txt)
        total=$((total + ssh_users))
    fi
    
    if [ -f /usr/local/afterlifevpn/users/xray_users.txt ]; then
        local xray_users=$(wc -l < /usr/local/afterlifevpn/users/xray_users.txt)
        total=$((total + xray_users))
    fi
    
    if [ -f /usr/local/afterlifevpn/users/hysteria_users.txt ]; then
        local hyst_users=$(wc -l < /usr/local/afterlifevpn/users/hysteria_users.txt)
        total=$((total + hyst_users))
    fi
    
    echo $total
}

# Simple header for subpages
show_header() {
    local breadcrumb=$1
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${PURPLE}AFTERLIFE VPN${NC}                    ${YELLOW}${DOMAIN:-$PUBLIC_IP}${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
    printf "${CYAN}║${NC} ${WHITE}%-54s${NC}${CYAN}║${NC}\n" "$breadcrumb"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Display main dashboard
show_dashboard() {
    clear
    get_system_info
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${PURPLE}AFTERLIFE VPN${NC}                    ${YELLOW}${DOMAIN:-$PUBLIC_IP}${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}› AFTERLIFE › Core${NC}                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "  ${WHITE}Server:${NC} ${DOMAIN:-$HOSTNAME} ${CYAN}($PUBLIC_IP)${NC}"
    echo -e "  ${WHITE}OS:${NC}     $OS_VERSION"
    echo -e "  ${WHITE}Uptime:${NC} $UPTIME"
    
    echo -e "  ${WHITE}CPU:${NC}  $(create_bar $CPU_USAGE_INT) ${CPU_USAGE_INT}% ${CYAN}($CPU_CORES Core)${NC}"
    echo -e "  ${WHITE}RAM:${NC}  $(create_bar $RAM_PERCENT) ${RAM_PERCENT}% ${CYAN}(${USED_RAM}MB / ${TOTAL_RAM}MB)${NC}"
    echo -e "  ${WHITE}Disk:${NC} $(create_bar $DISK_PERCENT) ${DISK_PERCENT}% ${CYAN}($USED_DISK / $TOTAL_DISK)${NC}"
    
    echo -e "  ${WHITE}[ Active Services ]${NC}"
    echo -e "  $(check_service xray) ${WHITE}Xray${NC}   $(check_service nginx) ${WHITE}Nginx${NC}   $(check_service hysteria) ${WHITE}Hysteria2${NC}   $(check_service wg-quick@wg0) ${WHITE}WireGuard${NC}"
    echo -e "  $(check_service ssh) ${WHITE}SSH${NC}    $(check_service dropbear) ${WHITE}Dropbear${NC}   $(check_service squid) ${WHITE}Squid${NC}   $(check_service danted) ${WHITE}Dante${NC}"
    
    local user_count=$(count_users)
    echo -e "  ${WHITE}Registered Clients:${NC} ${GREEN}$user_count${NC} total across protocols"
    
    echo -e "${CYAN}╭────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}Protocol & System Management${NC}                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}1)${NC} SSH & Dropbear             ${GREEN}6)${NC} Subscriptions          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}2)${NC} Xray Core Protocols        ${GREEN}7)${NC} TCP BBR Booster        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}3)${NC} Hysteria 2 (QUIC)          ${GREEN}8)${NC} Settings & Logs        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}4)${NC} WireGuard VPN              ${GREEN}9)${NC} Bot & Backup           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}5)${NC} L2TP / IPsec VPN        ${GREEN}10)${NC} Domain & Cert            ${CYAN}│${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────╯${NC}"
    echo -e "  ${YELLOW}U)${NC} Update AFTERLIFE   ${YELLOW}V)${NC} Full Diagnostics   ${YELLOW}X)${NC} Exit"
    echo -e ""
}

# ============================================================================
# SSH & DROPBEAR MANAGEMENT
# ============================================================================
menu_ssh() {
    while true; do
        show_header "› SSH › Management"
        echo -e "  ${GREEN}1)${NC} Create SSH Account"
        echo -e "  ${GREEN}2)${NC} Delete SSH Account"
        echo -e "  ${GREEN}3)${NC} Extend SSH Account"
        echo -e "  ${GREEN}4)${NC} List All SSH Users"
        echo -e "  ${GREEN}5)${NC} Check User Login"
        echo -e "  ${GREEN}6)${NC} Change Dropbear Port"
        echo -e "  ${GREEN}7)${NC} Change SSH WebSocket Port"
        echo -e "  ${GREEN}8)${NC} Monitor Active Connections"
        echo -e "  ${GREEN}9)${NC} Edit SSH Banner"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
        read -p "  Select option: " ssh_option
        
        case $ssh_option in
            1) create_ssh_user ;;
            2) delete_ssh_user ;;
            3) extend_ssh_user ;;
            4) list_ssh_users ;;
            5) check_user_login ;;
            6) change_dropbear_port ;;
            7) change_websocket_port ;;
            8) monitor_connections ;;
            9) edit_ssh_banner ;;
            0) break ;;
            *) ;;
        esac
    done
}

create_ssh_user() {
    show_header "› SSH › Create Account"
    local username password days devices quota
    read -p "  Username: " username
    if [[ -z "$username" ]]; then echo -e "\n  ${RED}✗ Username cannot be empty!${NC}\n"; read -p "  Press enter..."; return; fi
    read -p "  Password: " password
    read -p "  Expiry (days): " days
    read -p "  Max Login (devices) [default 2]: " devices
    devices=${devices:-2}
    read -p "  Data Quota [default Unlimited]: " quota
    quota=${quota:-Unlimited}
    
    if id "$username" &>/dev/null; then
        echo -e "\n  ${RED}✗ User already exists!${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    useradd -M -s /bin/false -e $(date -d "+$days days" +%Y-%m-%d) "$username"
    echo "$username:$password" | chpasswd
    
    if command -v htpasswd &> /dev/null; then
        htpasswd -b /etc/squid/passwd "$username" "$password" 2>/dev/null
    fi
    
    mkdir -p /usr/local/afterlifevpn/users
    echo "$username|$password|$(date -d "+$days days" +%Y-%m-%d)|$(date +%Y-%m-%d)|$devices|$quota" >> /usr/local/afterlifevpn/users/ssh_users.txt
    
    get_system_info
    local SERVER_HOST="${DOMAIN:-$PUBLIC_IP}"
    local EXPIRY_DATE=$(date -d "+$days days" +"%Y-%m-%d")
    local WS_PORT=$(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo "443")
    
    clear
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "         🔐 ${WHITE}AFTERLIFE PREMIUM — SSH ACCOUNT${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e " 👤 ${WHITE}ACCOUNT${NC}"
    echo -e "   Username    : ${GREEN}$username${NC}"
    echo -e "   Password    : ${GREEN}$password${NC}"
    echo -e "   Expires     : ${RED}$EXPIRY_DATE${NC}"
    echo -e "   Devices     : ${YELLOW}$devices${NC}"
    echo -e "   ${CYAN}══════════════════════════════${NC}"
    echo -e " 🌐 ${WHITE}SERVER${NC}"
    echo -e "   Host        : ${GREEN}$SERVER_HOST${NC}"
    echo -e "   WS Ports    : ${YELLOW}80 / $WS_PORT${NC}"
    echo -e "   SSL Ports   : ${YELLOW}443 / 777${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    
    local CONNECTION_STRING="ssh://$username:$password@$SERVER_HOST:22"
    if command -v qrencode &> /dev/null; then
        echo -e "\n ${WHITE}[QR CODE - SSH Connection]${NC}"
        qrencode -t ANSIUTF8 "$CONNECTION_STRING"
    fi
    
    echo -e "\n  ${GREEN}✓ Account created successfully!${NC}\n"
    read -p "  Press enter to continue..."
}

delete_ssh_user() {
    show_header "› SSH › Delete Account"
    local username
    read -p "  Username to delete: " username
    if [[ -z "$username" ]]; then return; fi
    
    if ! id "$username" &>/dev/null; then
        echo -e "\n  ${RED}✗ User does not exist!${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    pkill -u "$username" 2>/dev/null
    userdel -r "$username" 2>/dev/null
    sed -i "/^$username|/d" /usr/local/afterlifevpn/users/ssh_users.txt 2>/dev/null
    
    if [ -f /etc/squid/passwd ]; then
        htpasswd -D /etc/squid/passwd "$username" 2>/dev/null
    fi
    
    echo -e "\n  ${GREEN}✓ User '$username' deleted successfully!${NC}\n"
    read -p "  Press enter to continue..."
}

extend_ssh_user() {
    show_header "› SSH › Extend Account"
    local username days
    read -p "  Username: " username
    if [[ -z "$username" ]]; then return; fi
    
    if ! id "$username" &>/dev/null; then
        echo -e "\n  ${RED}✗ User does not exist!${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    read -p "  Add days: " days
    chage -E $(date -d "+$days days" +%Y-%m-%d) "$username"
    
    echo -e "\n  ${GREEN}✓ Account extended by $days days!${NC}"
    echo -e "  ${WHITE}New expiry:${NC} $(date -d "+$days days" +"%Y-%m-%d")\n"
    read -p "  Press enter to continue..."
}

list_ssh_users() {
    show_header "› SSH › User List"
    if [ ! -f /usr/local/afterlifevpn/users/ssh_users.txt ]; then
        echo -e "  ${YELLOW}No users found${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    echo -e "  ${WHITE}Username${NC}     ${WHITE}Created${NC}        ${WHITE}Expires${NC}        ${WHITE}Status${NC}"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"
    while IFS='|' read -r user pass expiry created max_login; do
        local status="${GREEN}Active${NC}"
        if [[ $(date -d "$expiry" +%s) -lt $(date +%s) ]]; then
            status="${RED}Expired${NC}"
        fi
        printf "  %-12s %-14s %-14s %b\n" "$user" "$created" "$expiry" "$status"
    done < /usr/local/afterlifevpn/users/ssh_users.txt
    echo ""
    read -p "  Press enter to continue..."
}

check_user_login() {
    show_header "› SSH › User Login Status"
    local username
    read -p "  Username: " username
    if [[ -z "$username" ]]; then return; fi
    
    if ! id "$username" &>/dev/null; then
        echo -e "\n  ${RED}✗ User does not exist!${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    echo -e "\n  ${WHITE}Checking login for:${NC} $username"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"
    if who | grep -q "^$username "; then
        echo -e "  ${GREEN}● User is currently logged in${NC}\n"
        who | grep "^$username " | while read line; do echo -e "  $line"; done
    else
        echo -e "  ${YELLOW}○ User is not logged in${NC}"
    fi
    echo ""
    read -p "  Press enter to continue..."
}

change_dropbear_port() {
    show_header "› SSH › Change Dropbear Port"
    local current_port=$(grep DROPBEAR_PORT /etc/default/dropbear 2>/dev/null | cut -d'=' -f2 || echo "442")
    local new_port
    echo -e "  ${WHITE}Current port:${NC} $current_port\n"
    read -p "  Enter new port: " new_port
    
    new_port=${new_port:-$current_port}
    if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then echo -e "\n  ${RED}✗ Invalid port!${NC}\n"; read -p "  Press enter..."; return; fi
    
    sed -i "s/DROPBEAR_PORT=.*/DROPBEAR_PORT=$new_port/" /etc/default/dropbear
    sed -i "s/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"-p $new_port\"/" /etc/default/dropbear
    systemctl restart dropbear
    
    echo -e "\n  ${GREEN}✓ Dropbear port changed to $new_port${NC}\n"
    read -p "  Press enter to continue..."
}

change_websocket_port() {
    show_header "› SSH › Change WebSocket Port"
    local current_port=$(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo "443")
    local new_port
    echo -e "  ${WHITE}Current port:${NC} $current_port\n"
    read -p "  Enter new port: " new_port
    
    new_port=${new_port:-$current_port}
    if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then echo -e "\n  ${RED}✗ Invalid port!${NC}\n"; read -p "  Press enter..."; return; fi
    
    sed -i "s/start_server = websockets.serve(proxy, \"0.0.0.0\", .*/start_server = websockets.serve(proxy, \"0.0.0.0\", $new_port, ssl=ssl_context)/" /usr/local/bin/ws-ssh.py
    echo "$new_port" > /usr/local/afterlifevpn/ws-port.conf
    systemctl restart ws-ssh
    
    echo -e "\n  ${GREEN}✓ WebSocket port changed to $new_port${NC}"
    echo -e "  ${YELLOW}⚠ Update your firewall rules!${NC}\n"
    read -p "  Press enter to continue..."
}

monitor_connections() {
    show_header "› SSH › Active Connections"
    echo -e "  ${YELLOW}SSH Connections:${NC}"
    local ssh_count=$(netstat -tnp 2>/dev/null | grep ':22' | grep ESTABLISHED | wc -l)
    echo -e "  Total: $ssh_count"
    netstat -tnp 2>/dev/null | grep ':22' | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10
    
    echo -e "\n  ${YELLOW}Dropbear Connections:${NC}"
    local drop_count=$(netstat -tnp 2>/dev/null | grep dropbear | grep ESTABLISHED | wc -l)
    echo -e "  Total: $drop_count"
    netstat -tnp 2>/dev/null | grep dropbear | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10
    
    echo -e "\n  ${YELLOW}Logged in Users:${NC}"
    who
    echo ""
    read -p "  Press enter to continue..."
}

edit_ssh_banner() {
    show_header "› SSH › Banner"
    echo -e "  ${WHITE}Current Banner (/etc/issue.net):${NC}"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"
    cat /etc/issue.net 2>/dev/null || echo "  No banner set"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}\n"
    echo -e "  ${GREEN}1)${NC} Edit Banner with Nano"
    echo -e "  ${GREEN}2)${NC} Reset to Default AFTERLIFE Banner"
    echo -e "  ${GREEN}3)${NC} Disable Banner\n"
    read -p "  Select [1-3] or [Enter to return]: " banner_choice
    
    case $banner_choice in
        1) nano /etc/issue.net; systemctl restart dropbear ssh; echo -e "\n  ${GREEN}✓ Banner updated!${NC}"; sleep 2 ;;
        2)
            cat > /etc/issue.net <<'EOF'
════════════════════════════════════════
        AFTERLIFE VPN Server
════════════════════════════════════════
 No DDOS | No Torrent | No Mining
 No Hacking | No Spam
════════════════════════════════════════
EOF
            systemctl restart dropbear ssh; echo -e "\n  ${GREEN}✓ Banner reset to default!${NC}"; sleep 2 ;;
        3) echo "" > /etc/issue.net; systemctl restart dropbear ssh; echo -e "\n  ${GREEN}✓ Banner disabled!${NC}"; sleep 2 ;;
    esac
}

# ============================================================================
# XRAY MANAGEMENT (KUROVPN STYLE)
# ============================================================================
menu_xray() {
    while true; do
        clear
        local SERVER_HOST="${DOMAIN:-$PUBLIC_IP}"
        echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
        printf "${CYAN}║ ${WHITE}AFTERLIFE VPN                            ${YELLOW}%-17s${CYAN} ║\n${NC}" "$SERVER_HOST"
        echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
        echo -e "${CYAN}║ ${YELLOW}› Main › Xray${CYAN}                                          ║\n${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
        echo -e ""
        echo -e " ${CYAN}╭────────────────────────────────────────────────────────╮${NC}"
        echo -e " ${CYAN}│${WHITE} Create Accounts                                        ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC}                                                        ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC}  ${GREEN}1)${NC} VMess (WS / gRPC)                                  ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC}  ${GREEN}2)${NC} VLess (WS / gRPC / NTLS)                           ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC}  ${GREEN}3)${NC} VLess Reality (Vision)                             ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC}  ${GREEN}4)${NC} Trojan (WS / gRPC)                                 ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC}  ${GREEN}5)${NC} Shadowsocks-2022                                   ${CYAN}│${NC}"
        echo -e " ${CYAN}╰────────────────────────────────────────────────────────╯${NC}"
        echo -e ""
        echo -e " ${CYAN}╭────────────────────────────────────────────────────────╮${NC}"
        echo -e " ${CYAN}│${WHITE} Management                                             ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC}                                                        ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC}  ${GREEN}6)${NC} List All Xray Users                                ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC}  ${GREEN}7)${NC} Renew User Account                                 ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC}  ${GREEN}8)${NC} Delete User Account                                ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC}  ${GREEN}9)${NC} Check Online Users                                 ${CYAN}│${NC}"
        echo -e " ${CYAN}│${NC} ${GREEN}10)${NC} Service Status                                     ${CYAN}│${NC}"
        echo -e " ${CYAN}╰────────────────────────────────────────────────────────╯${NC}"
        echo -e ""
        echo -e "  ${RED}X${NC} Back  · ${WHITE}$SERVER_HOST${NC}"
        echo -e ""
        read -p "  Select Option [1-10]: " sub_opt
        case $sub_opt in
            1) create_vmess_user ;;
            2) bash /usr/local/afterlifevpn/setup/xray-add-vless.sh ;;
            3) bash /usr/local/afterlifevpn/setup/xray-user.sh ;;
            4) bash /usr/local/afterlifevpn/setup/xray-add-trojan.sh ;;
            5) bash /usr/local/afterlifevpn/setup/xray-user.sh ;;
            6) list_vmess_users ;;
            7) bash /usr/local/afterlifevpn/setup/xray-renew.sh ;;
            8) delete_vmess_user ;;
            9) bash /usr/local/afterlifevpn/setup/xray-online.sh ;;
            10) clear; echo -e "\n  ${YELLOW}Xray Status:${NC}"; systemctl status xray --no-pager | grep -E "Active|Started"; echo ""; read -p "  Press [Enter] to return..." ;;
            X|x|0) break ;;
            *) continue ;;
        esac
    done
}

create_vmess_user() {
    show_header "› Xray › Create VMess Account"
    local username days
    read -p "  Username: " username
    if [[ -z "$username" ]]; then echo -e "\n  ${RED}✗ Username cannot be empty!${NC}\n"; read -p "  Press enter..."; return; fi
    read -p "  Expiry (days): " days
    
    if grep -q "^$username|" /usr/local/afterlifevpn/users/xray_users.txt 2>/dev/null; then
        echo -e "\n  ${RED}✗ User already exists!${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    local UUID=$(bash /usr/local/afterlifevpn/setup/xray-user.sh add "$username" "$days")
    get_system_info
    local SERVER_HOST="${DOMAIN:-$PUBLIC_IP}"
    local EXPIRY_DATE=$(date -d "+$days days" +"%b %d, %Y")
    
    local VMESS_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "${username}-AFTERLIFE",
  "add": "${SERVER_HOST}",
  "port": "443",
  "id": "${UUID}",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "${SERVER_HOST}",
  "path": "/vmess",
  "tls": "tls",
  "sni": "${SERVER_HOST}",
  "alpn": ""
}
EOF
)
    local VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)"
    
    clear
    echo -e "${CYAN}╭────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                       ${WHITE}VMESS ACCOUNT CREATED${NC}                        ${CYAN}│${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────────────────╯${NC}"
    echo -e " ${WHITE}Username${NC}     : ${GREEN}$username${NC}"
    echo -e " ${WHITE}UUID${NC}         : ${GREEN}$UUID${NC}"
    echo -e " ${WHITE}Expired On${NC}   : ${RED}$EXPIRY_DATE${NC}"
    echo -e " ${WHITE}Server${NC}       : ${CYAN}$SERVER_HOST${NC}"
    echo -e " ${WHITE}Port${NC}         : ${CYAN}443${NC}"
    echo -e " ${WHITE}Network${NC}      : ${CYAN}ws (TLS)${NC}"
    echo -e " ${WHITE}Path${NC}         : ${CYAN}/vmess${NC}"
    echo -e " ${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e " ⚡ ${WHITE}STANDARD LINK${NC}"
    echo -e "   ${YELLOW}$VMESS_LINK${NC}"
    
    if command -v qrencode &> /dev/null; then
        echo -e "\n ${WHITE}[QR CODE - VMess Connection]${NC}"
        qrencode -t ANSIUTF8 "$VMESS_LINK"
    fi
    
    echo -e "\n ${GREEN}✓ VMess account created successfully!${NC}\n"
    read -p "  Press enter to continue..."
}

delete_vmess_user() {
    show_header "› Xray › Delete VMess Account"
    local username
    read -p "  Username to delete: " username
    if [[ -z "$username" ]]; then return; fi
    
    if ! grep -q "^$username|" /usr/local/afterlifevpn/users/xray_users.txt 2>/dev/null; then
        echo -e "\n  ${RED}✗ User does not exist!${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    bash /usr/local/afterlifevpn/setup/xray-del.sh "$username"
    read -p "  Press enter to continue..."
}

list_vmess_users() {
    show_header "› Xray › VMess User List"
    if [ ! -f /usr/local/afterlifevpn/users/xray_users.txt ]; then
        echo -e "  ${YELLOW}No users found${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    echo -e "  ${WHITE}Username${NC}     ${WHITE}UUID${NC}                                   ${WHITE}Expires${NC}"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────────────────────${NC}"
    while IFS='|' read -r user uuid expiry created; do
        printf "  %-12s %-38s %s\n" "$user" "$uuid" "$expiry"
    done < /usr/local/afterlifevpn/users/xray_users.txt
    echo ""
    read -p "  Press enter to continue..."
}

# ============================================================================
# HYSTERIA 2 MANAGEMENT (KUROVPN STYLE)
# ============================================================================
menu_hysteria() {
    while true; do
        clear
        local SERVER_HOST="${DOMAIN:-$PUBLIC_IP}"
        echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
        printf "${CYAN}║ ${WHITE}AFTERLIFE VPN                            ${YELLOW}%-17s${CYAN} ║\n${NC}" "$SERVER_HOST"
        echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
        echo -e "${CYAN}║ ${YELLOW}› Main › Hysteria 2${CYAN}                                    ║\n${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
        echo -e ""
        echo -e "    ${GREEN}1)${NC}  Create Account"
        echo -e "    ${GREEN}2)${NC}  List Accounts"
        echo -e "    ${GREEN}3)${NC}  Renew Account"
        echo -e "    ${GREEN}4)${NC}  Delete Account"
        echo -e "    ${GREEN}5)${NC}  Change Port Mode (Single/Hopping)"
        echo -e "    ${GREEN}6)${NC}  Service Status"
        echo -e ""
        echo -e "  ${RED}X${NC} Back  · ${WHITE}$SERVER_HOST${NC}"
        echo -e ""
        read -p "  Select [1-6]: " sub_opt
        case $sub_opt in
            1) create_hysteria_user ;;
            2) list_hysteria_users ;;
            3) bash /usr/local/afterlifevpn/setup/hys-renew.sh ;;
            4) delete_hysteria_user ;;
            5) change_hysteria_mode ;;
            6) clear; echo -e "\n  ${YELLOW}Hysteria Status:${NC}"; systemctl status hysteria-server.service --no-pager | grep -E "Active|Started"; echo ""; read -p "  Press [Enter] to return..." ;;
            X|x|0) break ;;
            *) continue ;;
        esac
    done
}

create_hysteria_user() {
    show_header "› Hysteria › Create Account"
    local username days
    read -p "  Username: " username
    if [[ -z "$username" ]]; then echo -e "\n  ${RED}✗ Username cannot be empty!${NC}\n"; read -p "  Press enter..."; return; fi
    read -p "  Expiry (days): " days
    
    if grep -q "^$username|" /usr/local/afterlifevpn/users/hysteria_users.txt 2>/dev/null; then
        echo -e "\n  ${RED}✗ User already exists!${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    local PASSWORD=$(bash /usr/local/afterlifevpn/setup/hysteria-user.sh add "$username" "$days")
    get_system_info
    local SERVER_HOST="${DOMAIN:-$PUBLIC_IP}"
    local EXPIRY_DATE=$(date -d "+$days days" +"%b %d, %Y")
    local LISTEN_PORTS=$(grep "listen:" /etc/hysteria/config.yaml 2>/dev/null | awk '{print $2}' | sed 's/://')
    local STANDARD_PORT HOPPING_PORTS LINK_STANDARD LINK_HOPPING
    
    if [[ "$LISTEN_PORTS" == *","* ]]; then
        STANDARD_PORT=$(echo "$LISTEN_PORTS" | cut -d',' -f1)
        HOPPING_PORTS="$LISTEN_PORTS"
    else
        STANDARD_PORT="$LISTEN_PORTS"
        HOPPING_PORTS="N/A"
    fi
    
    LINK_STANDARD="hy2://${username}:${PASSWORD}@${PUBLIC_IP}:${STANDARD_PORT}?insecure=1&sni=${SERVER_HOST}#${username}-Hy2"
    if [[ "$HOPPING_PORTS" != "N/A" ]]; then
        LINK_HOPPING="hy2://${username}:${PASSWORD}@${PUBLIC_IP}:${HOPPING_PORTS}?insecure=1&sni=${SERVER_HOST}#${username}-Hy2-Hop"
    fi
    
    clear
    echo -e "${CYAN}╭────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                      ${WHITE}HYSTERIA 2 ACCOUNT CREATED${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────────────────╯${NC}"
    echo -e " ${WHITE}Username${NC}     : ${GREEN}$username${NC}"
    echo -e " ${WHITE}Password${NC}     : ${GREEN}$PASSWORD${NC}"
    echo -e " ${WHITE}Expired On${NC}   : ${RED}$EXPIRY_DATE${NC}"
    echo -e " ${WHITE}Server${NC}       : ${CYAN}$SERVER_HOST${NC}"
    echo -e " ${WHITE}Protocol${NC}     : ${CYAN}UDP (QUIC)${NC}"
    echo -e " ${WHITE}Active Ports${NC} : ${CYAN}$LISTEN_PORTS${NC}"
    echo -e " ${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e " ⚡ ${WHITE}STANDARD LINK${NC}"
    echo -e "   ${YELLOW}$LINK_STANDARD${NC}"
    
    if [[ "$HOPPING_PORTS" != "N/A" ]]; then
        echo -e "   ${CYAN}══════════════════════════════${NC}"
        echo -e " 🔀 ${WHITE}PORT-HOPPING LINK (harder to block)${NC}"
        echo -e "   ${YELLOW}$LINK_HOPPING${NC}"
    fi
    
    if command -v qrencode &> /dev/null; then
        echo -e "\n ${WHITE}[QR CODE - Hysteria Standard Connection]${NC}"
        qrencode -t ANSIUTF8 "$LINK_STANDARD"
    fi
    
    echo -e "\n ${GREEN}✓ Hysteria 2 account created successfully!${NC}\n"
    read -p "  Press enter to continue..."
}

delete_hysteria_user() {
    show_header "› Hysteria › Delete Account"
    local username
    read -p "  Username to delete: " username
    if [[ -z "$username" ]]; then return; fi
    
    if ! grep -q "^$username|" /usr/local/afterlifevpn/users/hysteria_users.txt 2>/dev/null; then
        echo -e "\n  ${RED}✗ User does not exist!${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    bash /usr/local/afterlifevpn/setup/hysteria-user.sh delete "$username"
    echo -e "\n  ${GREEN}✓ User '$username' deleted successfully!${NC}\n"
    read -p "  Press enter to continue..."
}

list_hysteria_users() {
    show_header "› Hysteria › User List"
    if [ ! -f /usr/local/afterlifevpn/users/hysteria_users.txt ]; then
        echo -e "  ${YELLOW}No users found${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    echo -e "  ${WHITE}Username${NC}     ${WHITE}Password${NC}         ${WHITE}Created${NC}        ${WHITE}Expires${NC}"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────────────────${NC}"
    while IFS='|' read -r user pass expiry created; do
        printf "  %-12s %-16s %-14s %s\n" "$user" "$pass" "$created" "$expiry"
    done < /usr/local/afterlifevpn/users/hysteria_users.txt
    echo ""
    read -p "  Press enter to continue..."
}

change_hysteria_mode() {
    show_header "› Hysteria › Port Configuration"
    local mode_choice single_port port_range inc_53 listen_ports
    echo -e "  ${GREEN}1)${NC} Single Port Mode"
    echo -e "  ${GREEN}2)${NC} Port Hopping Mode\n"
    read -p "  Select mode: " mode_choice
    
    if [[ $mode_choice == "1" ]]; then
        read -p "  Enter port (default 443): " single_port
        single_port=${single_port:-443}
        
        cat > /etc/hysteria/config.yaml <<EOF
listen: :$single_port

tls:
  cert: /etc/afterlifevpn/cert/fullchain.crt
  key: /etc/afterlifevpn/cert/private.key

auth:
  type: command
  command: /etc/hysteria/auth.sh

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
        echo -e "\n  ${GREEN}✓ Hysteria set to single port: $single_port${NC}"
        
    elif [[ $mode_choice == "2" ]]; then
        read -p "  Enter port range (e.g., 20000-40000): " port_range
        read -p "  Include port 53? (y/n): " inc_53
        
        if [[ $inc_53 == "y" ]]; then listen_ports="53,$port_range"
        else listen_ports="$port_range"; fi
        
        cat > /etc/hysteria/config.yaml <<EOF
listen: :$listen_ports

tls:
  cert: /etc/afterlifevpn/cert/fullchain.crt
  key: /etc/afterlifevpn/cert/private.key

auth:
  type: command
  command: /etc/hysteria/auth.sh

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
        echo -e "\n  ${GREEN}✓ Hysteria set to port hopping: $listen_ports${NC}"
    fi
    echo ""
    read -p "  Press enter to continue..."
}

# ============================================================================
# SYSTEM SETTINGS & UTILS
# ============================================================================
menu_wireguard() { show_header "› WireGuard"; echo -e "  ${YELLOW}Coming Soon!${NC}\n"; read -p "  Press enter..."; }
menu_l2tp() { show_header "› L2TP / IPsec"; echo -e "  ${YELLOW}Coming Soon!${NC}\n"; read -p "  Press enter..."; }
menu_subscriptions() { show_header "› Subscriptions"; echo -e "  ${YELLOW}Coming Soon!${NC}\n"; read -p "  Press enter..."; }

menu_bbr() {
    show_header "› System › TCP BBR Status"
    local bbr_status=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ $bbr_status == "bbr" ]]; then
        echo -e "  ${GREEN}✓ TCP BBR is ENABLED${NC}"
    else
        echo -e "  ${RED}✗ TCP BBR is DISABLED${NC}"
        echo -e "  ${YELLOW}Current algorithm: $bbr_status${NC}"
    fi
    echo ""
    read -p "  Press enter to continue..."
}

menu_settings() {
    while true; do
        show_header "› Settings › Management"
        echo -e "  ${GREEN}1)${NC} Clear System Logs"
        echo -e "  ${GREEN}2)${NC} View Service Logs"
        echo -e "  ${GREEN}3)${NC} Restart All Services"
        echo -e "  ${GREEN}4)${NC} Check Service Status"
        echo -e "  ${GREEN}5)${NC} Bandwidth Limiter"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu\n"
        read -p "  Select option: " settings_option
        
        case $settings_option in
            1) clear_logs ;;
            2) view_logs ;;
            3) restart_all_services ;;
            4) check_all_services ;;
            5) bandwidth_limiter ;;
            0) break ;;
            *) ;;
        esac
    done
}

clear_logs() {
    show_header "› Settings › Clear Logs"
    echo -e "  ${YELLOW}Clearing system logs...${NC}"
    journalctl --vacuum-time=1d
    journalctl --vacuum-size=50M
    echo "" > /var/log/syslog 2>/dev/null
    echo "" > /var/log/auth.log 2>/dev/null
    echo -e "\n  ${GREEN}✓ Logs cleared!${NC}\n"
    read -p "  Press enter to continue..."
}

view_logs() {
    show_header "› Settings › Service Logs"
    echo -e "  ${GREEN}1)${NC} SSH WebSocket\n  ${GREEN}2)${NC} Xray (VMess)\n  ${GREEN}3)${NC} Hysteria 2\n  ${GREEN}4)${NC} Dropbear\n"
    read -p "  Select service: " log_choice
    clear
    case $log_choice in
        1) journalctl -u ws-ssh -n 50 --no-pager ;;
        2) journalctl -u xray -n 50 --no-pager ;;
        3) journalctl -u hysteria -n 50 --no-pager ;;
        4) journalctl -u dropbear -n 50 --no-pager ;;
    esac
    echo ""
    read -p "  Press enter to continue..."
}

restart_all_services() {
    show_header "› Settings › Restart Services"
    echo -e "  ${YELLOW}Restarting all services...${NC}"
    systemctl restart ws-ssh xray hysteria udp-custom dropbear
    echo -e "\n  ${GREEN}✓ All services restarted!${NC}\n"
    read -p "  Press enter to continue..."
}

check_all_services() {
    show_header "› Settings › Service Status"
    local services=("ws-ssh" "xray" "hysteria" "udp-custom" "dropbear")
    local names=("SSH WebSocket" "Xray (VMess)" "Hysteria 2" "UDP Custom" "Dropbear")
    
    for i in "${!services[@]}"; do
        if systemctl is-active --quiet "${services[$i]}"; then
            echo -e "  ${GREEN}●${NC} ${names[$i]}: ${GREEN}Running${NC}"
        else
            echo -e "  ${RED}○${NC} ${names[$i]}: ${RED}Stopped${NC}"
        fi
    done
    echo ""
    read -p "  Press enter to continue..."
}

bandwidth_limiter() { show_header "› Bandwidth"; echo -e "  ${YELLOW}Coming soon...${NC}\n"; read -p "  Press enter..."; }

menu_backup() {
    while true; do
        show_header "› Backup › Management"
        echo -e "  ${GREEN}1)${NC} Backup Configuration"
        echo -e "  ${GREEN}2)${NC} Restore Configuration"
        echo -e "  ${GREEN}3)${NC} List Backups"
        echo -e "  ${GREEN}4)${NC} Telegram Bot (Coming Soon)"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu\n"
        read -p "  Select option: " backup_option
        
        case $backup_option in
            1) create_backup ;;
            2) restore_backup ;;
            3) list_backups ;;
            4) echo "Telegram Bot - Coming Soon!"; sleep 2 ;;
            0) break ;;
            *) ;;
        esac
    done
}

create_backup() {
    show_header "› Backup › Create"
    echo -e "  ${YELLOW}Creating backup...${NC}"
    
    local BACKUP_DIR="/root/afterlifevpn-backup"
    local BACKUP_FILE="afterlifevpn-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    mkdir -p "$BACKUP_DIR"
    local TEMP_BACKUP="/tmp/afterlifevpn-backup-temp"
    mkdir -p "$TEMP_BACKUP"
    
    cp -r /usr/local/afterlifevpn "$TEMP_BACKUP/" 2>/dev/null
    cp -r /etc/afterlifevpn "$TEMP_BACKUP/" 2>/dev/null
    cp -r /etc/hysteria "$TEMP_BACKUP/" 2>/dev/null
    cp /usr/local/etc/xray/config.json "$TEMP_BACKUP/" 2>/dev/null
    
    cd /tmp
    tar -czf "$BACKUP_DIR/$BACKUP_FILE" afterlifevpn-backup-temp/
    rm -rf "$TEMP_BACKUP"
    
    echo -e "\n  ${GREEN}✓ Backup completed!${NC}"
    echo -e "  ${WHITE}Saved to:${NC} $BACKUP_DIR/$BACKUP_FILE"
    echo -e "  ${WHITE}Size:${NC} $(du -h $BACKUP_DIR/$BACKUP_FILE | awk '{print $1}')\n"
    read -p "  Press enter to continue..."
}

restore_backup() { show_header "› Restore"; echo -e "  ${YELLOW}Coming soon...${NC}\n"; read -p "  Press enter..."; }

list_backups() {
    show_header "› Backup › List"
    if [ -d /root/afterlifevpn-backup ] && [ "$(ls -A /root/afterlifevpn-backup 2>/dev/null)" ]; then
        ls -lh /root/afterlifevpn-backup/*.tar.gz 2>/dev/null | awk '{print "  "$9" ("$5")"}'
    else
        echo -e "  ${YELLOW}No backups found${NC}"
    fi
    echo ""
    read -p "  Press enter to continue..."
}

menu_domain() {
    while true; do
        show_header "› Domain › Management"
        echo -e "  ${GREEN}1)${NC} Renew SSL Certificate"
        echo -e "  ${GREEN}2)${NC} Change Domain"
        echo -e "  ${GREEN}3)${NC} View Certificate Info"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu\n"
        read -p "  Select option: " domain_option
        
        case $domain_option in
            1) renew_certificate ;;
            2) echo "Feature coming soon..."; sleep 2 ;;
            3) view_certificate ;;
            0) break ;;
            *) ;;
        esac
    done
}

renew_certificate() {
    show_header "› Domain › Renew Certificate"
    echo -e "  ${YELLOW}Renewing SSL certificate...${NC}"
    source /usr/local/afterlifevpn/config.conf
    ~/.acme.sh/acme.sh --renew -d "$DOMAIN" --force
    systemctl restart ws-ssh xray hysteria
    echo -e "\n  ${GREEN}✓ Certificate renewed!${NC}\n"
    read -p "  Press enter to continue..."
}

view_certificate() {
    show_header "› Domain › Certificate Info"
    if [ -f /etc/afterlifevpn/cert/fullchain.crt ]; then
        openssl x509 -in /etc/afterlifevpn/cert/fullchain.crt -noout -text | grep -E "Subject:|Issuer:|Not Before|Not After"
    else
        echo -e "  ${RED}No certificate found${NC}"
    fi
    echo ""
    read -p "  Press enter to continue..."
}

update_script() {
    show_header "› System › Update"
    echo -e "  ${YELLOW}Checking for updates from GitHub...${NC}\n"
    
    local REPO_URL="https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main"
    local SUCCESS=true
    
    # Create temporary directory for downloads
    mkdir -p /tmp/afterlife-update
    
    echo -e "  ${WHITE}Pulling menu system...${NC}"
    wget -q -O /tmp/afterlife-update/menu.sh "$REPO_URL/menu/menu.sh" || SUCCESS=false
    
    echo -e "  ${WHITE}Pulling setup & user scripts...${NC}"
    wget -q -O /tmp/afterlife-update/xray-user.sh "$REPO_URL/setup/xray-user.sh" || SUCCESS=false
    wget -q -O /tmp/afterlife-update/hysteria-user.sh "$REPO_URL/setup/hysteria-user.sh" || SUCCESS=false
    wget -q -O /tmp/afterlife-update/add-ssh.sh "$REPO_URL/setup/add-ssh.sh" 2>/dev/null
    
    # NEW: KUROVPN backend scripts
    wget -q -O /tmp/afterlife-update/xray-add-vless.sh "$REPO_URL/setup/xray-add-vless.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/xray-add-trojan.sh "$REPO_URL/setup/xray-add-trojan.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/xray-online.sh "$REPO_URL/setup/xray-online.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/xray-renew.sh "$REPO_URL/setup/xray-renew.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/xray-del.sh "$REPO_URL/setup/xray-del.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/user-expire.sh "$REPO_URL/setup/user-expire.sh" 2>/dev/null
    
    if [ "$SUCCESS" = true ]; then
        # Apply updates to the system directories
        cp /tmp/afterlife-update/menu.sh /usr/local/afterlifevpn/menu/menu.sh
        cp /tmp/afterlife-update/xray-user.sh /usr/local/afterlifevpn/setup/xray-user.sh
        cp /tmp/afterlife-update/hysteria-user.sh /usr/local/afterlifevpn/setup/hysteria-user.sh
        
        # Copy the new KUROVPN scripts if they downloaded successfully
        cp /tmp/afterlife-update/xray-add-vless.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/xray-add-trojan.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/xray-online.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/xray-renew.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/xray-del.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/user-expire.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        
        # Only copy SSH script if it exists in the repo
        if [ -s /tmp/afterlife-update/add-ssh.sh ]; then
            cp /tmp/afterlife-update/add-ssh.sh /usr/local/afterlifevpn/setup/add-ssh.sh
            chmod +x /usr/local/afterlifevpn/setup/add-ssh.sh
        fi
        
        # Set execution permissions globally for all setup scripts
        chmod +x /usr/local/afterlifevpn/menu/menu.sh
        chmod +x /usr/local/afterlifevpn/setup/*.sh
        
        # Create global shortcuts
        ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/menu
        ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/afterlife
        
        # Cleanup
        rm -rf /tmp/afterlife-update
        
        echo -e "\n  ${GREEN}✓ All AFTERLIFE scripts updated successfully!${NC}"
        echo -e "  ${YELLOW}⚠ Global shortcuts activated: Type 'menu' or 'afterlife' to launch.${NC}"
        echo -e "  ${YELLOW}⚠ Restart menu to apply changes.${NC}"
    else
        echo -e "\n  ${RED}✗ Update failed! Could not reach GitHub or critical files are missing.${NC}"
    fi
    
    echo ""
    read -p "  Press enter to continue..."
}

full_diagnostics() {
    clear
    get_system_info
    
    local passed=0
    local failed=0
    local warnings=0
    
    # Helper function for printing checks
    print_check() {
        local status=$1
        local text=$2
        if [ "$status" == "PASS" ]; then
            echo -e "  ${GREEN}[PASS]${NC} $text"
            ((passed++))
        elif [ "$status" == "WARN" ]; then
            echo -e "  ${YELLOW}[WARN]${NC} $text"
            ((warnings++))
        else
            echo -e "  ${RED}[FAIL]${NC} $text"
            ((failed++))
        fi
    }
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${PURPLE}AFTERLIFE VPN${NC}                    ${YELLOW}${DOMAIN:-$PUBLIC_IP}${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}› Diagnostics${NC}                                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e " ${WHITE}[ Services ]${NC}"
    for srv in nginx xray dropbear ssh ws-ssh badvpn hysteria squid danted; do
        if systemctl is-active --quiet "$srv" 2>/dev/null; then
            print_check "PASS" "$srv is running"
        else
            print_check "FAIL" "$srv is stopped/missing"
        fi
    done

    echo ""
    echo -e " ${WHITE}[ Configuration ]${NC}"
    if [ -f /usr/local/etc/xray/config.json ]; then print_check "PASS" "xray config valid"; else print_check "FAIL" "xray config missing"; fi
    if command -v xray &> /dev/null; then print_check "PASS" "xray binary"; else print_check "FAIL" "xray binary missing"; fi
    if [ -d /etc/nginx/sites-enabled ]; then print_check "PASS" "nginx config"; else print_check "FAIL" "nginx config missing"; fi
    if [ -n "$DOMAIN" ]; then print_check "PASS" "domain set"; else print_check "WARN" "domain not configured"; fi
    if [ -f /etc/afterlifevpn/cert/fullchain.crt ]; then 
        print_check "PASS" "TLS cert exists"
        if openssl x509 -checkend 86400 -noout -in /etc/afterlifevpn/cert/fullchain.crt &>/dev/null; then
            print_check "PASS" "TLS cert not expired"
        else
            print_check "WARN" "TLS cert expiring soon or expired"
        fi
    else
        print_check "FAIL" "TLS cert missing"
        print_check "FAIL" "TLS cert not expired"
    fi
    if [ -f /etc/hysteria/config.yaml ]; then print_check "PASS" "hysteria config"; else print_check "FAIL" "hysteria config missing"; fi

    echo ""
    echo -e " ${WHITE}[ Ports ]${NC}"
    check_port() {
        if netstat -tuln 2>/dev/null | grep -q ":$1 "; then
            print_check "PASS" "port $1 ($2)"
        else
            print_check "FAIL" "port $1 ($2)"
        fi
    }
    
    check_port 443 "nginx"
    check_port 80  "nginx"
    check_port 22  "ssh"
    check_port 109 "dropbear"
    check_port 7300 "badvpn"
    check_port 2048 "wg"
    check_port 8443 "reality"
    check_port 10010 "ss2022"
    
    if netstat -uln 2>/dev/null | grep -E -q ":(443) "; then
        print_check "PASS" "port 443/udp (hysteria)"
    else
        print_check "FAIL" "port 443/udp (hysteria)"
    fi
    
    if iptables-save 2>/dev/null | grep -q "dport 53"; then
        print_check "PASS" "port 53/udp (hysteria red)"
    else
        print_check "FAIL" "port 53/udp (hysteria red)"
    fi
    
    echo ""
    echo -e " ${WHITE}[ Management ]${NC}"
    for cmd in menu wget qrencode tar nano; do
        if command -v "$cmd" &> /dev/null || [ "$cmd" == "menu" -a -f "/usr/local/afterlifevpn/menu/menu.sh" ]; then
            print_check "PASS" "$cmd command"
        else
            print_check "FAIL" "$cmd command missing"
        fi
    done
    
    if grep -q "AFTERLIFE" /etc/issue.net 2>/dev/null; then 
        print_check "PASS" "ssh banner"
    else 
        print_check "WARN" "ssh banner not standard"
    fi
    
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════${NC}"
    echo -e "  Results: ${GREEN}$passed passed${NC}, ${YELLOW}$warnings warnings${NC}, ${RED}$failed failed${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e " Domain : ${YELLOW}${DOMAIN:-$PUBLIC_IP}${NC}"
    if command -v xray &> /dev/null; then
        echo -e " Xray   : $(xray version | head -n 1)"
    fi
    echo ""
    
    if [ "$failed" -eq 0 ]; then
        echo -e " ${GREEN}All critical checks passed.${NC} ($warnings non-critical warnings)"
    else
        echo -e " ${RED}Warning: $failed critical checks failed.${NC} Please review the logs."
    fi
    
    echo ""
    read -p "  Press [Enter] to continue..."
}

# Main loop
while true; do
    show_dashboard
    read -p "  Select Option [1-10 / U / V / X]: " option
    
    case $option in
        1) menu_ssh ;;
        2) menu_xray ;;
        3) menu_hysteria ;;
        4) menu_wireguard ;;
        5) menu_l2tp ;;
        6) menu_subscriptions ;;
        7) menu_bbr ;;
        8) menu_settings ;;
        9) menu_backup ;;
        10) menu_domain ;;
        U|u) update_script ;;
        V|v) full_diagnostics ;;
        X|x) clear; echo -e "${CYAN}Thank you for using AFTERLIFE VPN!${NC}"; exit 0 ;;
        *) ;;
    esac
done
