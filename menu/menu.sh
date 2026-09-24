#!/bin/bash

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
    TOTAL_RAM=$(free -m | awk 'NR==2{print $2}')
    USED_RAM=$(free -m | awk 'NR==2{print $3}')
    RAM_PERCENT=$((USED_RAM * 100 / TOTAL_RAM))
    TOTAL_DISK=$(df -h / | awk 'NR==2{print $2}')
    USED_DISK=$(df -h / | awk 'NR==2{print $3}')
    DISK_PERCENT=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
}

# Create progress bar
create_bar() {
    local percent=$1
    local width=12
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]"
}

# Check service status
check_service() {
    if systemctl is-active --quiet $1 2>/dev/null; then
        echo -e "${GREEN}●${NC}"
    else
        echo -e "${RED}○${NC}"
    fi
}

# Count total users
count_users() {
    local total=0
    
    # Count SSH users
    if [ -f /usr/local/afterlifevpn/users/ssh_users.txt ]; then
        local ssh_users=$(wc -l < /usr/local/afterlifevpn/users/ssh_users.txt)
        total=$((total + ssh_users))
    fi
    
    # Count VMess users
    if [ -f /usr/local/afterlifevpn/users/xray_users.txt ]; then
        local xray_users=$(wc -l < /usr/local/afterlifevpn/users/xray_users.txt)
        total=$((total + xray_users))
    fi
    
    # Count Hysteria users
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
    
    # Header
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${PURPLE}AFTERLIFE VPN${NC}                    ${YELLOW}${DOMAIN:-$PUBLIC_IP}${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}› AFTERLIFE › Core${NC}                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    
    # Server Information
    echo -e "  ${WHITE}Server:${NC} ${DOMAIN:-$HOSTNAME} ${CYAN}($PUBLIC_IP)${NC}"
    echo -e "  ${WHITE}OS:${NC}     $OS_VERSION"
    echo -e "  ${WHITE}Uptime:${NC} $UPTIME"
    
    # System Resources
    echo -e "  ${WHITE}CPU:${NC}  $(create_bar $CPU_USAGE_INT) ${CPU_USAGE_INT}% ${CYAN}($CPU_CORES Core)${NC}"
    echo -e "  ${WHITE}RAM:${NC}  $(create_bar $RAM_PERCENT) ${RAM_PERCENT}% ${CYAN}(${USED_RAM}MB / ${TOTAL_RAM}MB)${NC}"
    echo -e "  ${WHITE}Disk:${NC} $(create_bar $DISK_PERCENT) ${DISK_PERCENT}% ${CYAN}($USED_DISK / $TOTAL_DISK)${NC}"
    
    # Active Services
    echo -e "  ${WHITE}[ Active Services ]${NC}"
    echo -e "  $(check_service xray) ${WHITE}Xray${NC}   $(check_service nginx) ${WHITE}Nginx${NC}   $(check_service hysteria) ${WHITE}Hysteria2${NC}   $(check_service wg-quick@wg0) ${WHITE}WireGuard${NC}"
    echo -e "  $(check_service ssh) ${WHITE}SSH${NC}    $(check_service dropbear) ${WHITE}Dropbear${NC}   $(check_service squid) ${WHITE}Squid${NC}   $(check_service danted) ${WHITE}Dante${NC}"
    
    # User Count
    local user_count=$(count_users)
    echo -e "  ${WHITE}Registered Clients:${NC} ${GREEN}$user_count${NC} total across protocols"
    
    # Main Menu
    echo -e "${CYAN}╭────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}Protocol & System Management${NC}                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}1)${NC} SSH & Dropbear           ${GREEN}6)${NC} Subscriptions          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}2)${NC} Xray Core Protocols      ${GREEN}7)${NC} TCP BBR Booster        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}3)${NC} Hysteria 2 (QUIC)        ${GREEN}8)${NC} Settings & Logs        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}4)${NC} WireGuard VPN            ${GREEN}9)${NC} Bot & Backup           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}5)${NC} L2TP / IPsec VPN       ${GREEN}10)${NC} Domain & Cert           ${CYAN}│${NC}"
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
    
    read -p "  Username: " username
    read -p "  Password: " password
    read -p "  Expiry (days): " days
    read -p "  Max Login (devices): " max_login
    max_login=${max_login:-2}
    
    if id "$username" &>/dev/null; then
        echo ""
        echo -e "  ${RED}✗ User already exists!${NC}"
        echo ""
        read -p "  Press enter to continue..."
        return
    fi
    
    useradd -M -s /bin/false -e $(date -d "+$days days" +%Y-%m-%d) $username
    echo "$username:$password" | chpasswd
    
    # Add to proxy auth
    if command -v htpasswd &> /dev/null; then
        htpasswd -b /etc/squid/passwd $username $password 2>/dev/null
    fi
    
    mkdir -p /usr/local/afterlifevpn/users
    echo "$username|$password|$(date -d "+$days days" +%Y-%m-%d)|$(date +%Y-%m-%d)|$max_login" >> /usr/local/afterlifevpn/users/ssh_users.txt
    
    get_system_info
    SERVER_HOST="${DOMAIN:-$PUBLIC_IP}"
    EXPIRY_DATE=$(date -d "+$days days" +"%b %d, %Y")
    WS_PORT=$(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo "443")
    DROPBEAR_PORT=$(grep DROPBEAR_PORT /etc/default/dropbear 2>/dev/null | cut -d'=' -f2 || echo "442")
    PUBKEY=$(echo -n "$username$password" | sha256sum | awk '{print $1}')
    
    clear
    echo -e "${CYAN}╭────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                        ${WHITE}PREMIUM SSH WS ACCOUNT${NC}                      ${CYAN}│${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────────────────╯${NC}"
    echo -e " ${WHITE}Username${NC}     : ${GREEN}$username${NC}"
    echo -e " ${WHITE}Password${NC}     : ${GREEN}$password${NC}"
    echo -e " ${WHITE}Max Login${NC}    : ${YELLOW}$max_login Device(s)${NC}"
    echo -e " ${WHITE}Data Limit${NC}   : ${YELLOW}Unlimited${NC}"
    echo -e " ${WHITE}Expired On${NC}   : ${RED}$EXPIRY_DATE${NC}"
    echo -e " ${WHITE}Host${NC}         : ${CYAN}$SERVER_HOST${NC}"
    echo -e " ${WHITE}Nameserver${NC}   : ${CYAN}ns-$SERVER_HOST${NC}"
    echo -e " ${WHITE}PubKey${NC}       : ${PURPLE}$PUBKEY${NC}"
    echo -e " ${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}► HTTP & SOCKS PROXY:${NC}"
    echo -e " ${WHITE}HTTP Proxy${NC}   : ${CYAN}$SERVER_HOST:3128${NC} ${YELLOW}(Auth: $username:$password)${NC}"
    echo -e " ${WHITE}SOCKS5 Proxy${NC} : ${CYAN}$SERVER_HOST:1080:$username:$password${NC}"
    echo -e " ${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}► DIRECT CONNECTIONS:${NC}"
    echo -e " ${WHITE}TLS Ports${NC}    : ${GREEN}443, 2053, 2083, 2087, 2096, 8443${NC}"
    echo -e " ${WHITE}HTTP Ports${NC}   : ${GREEN}80, 8080, 2052, 2082, 2086, 2095${NC}"
    echo -e " ${WHITE}SSH Default${NC}  : ${CYAN}$SERVER_HOST:22@$username:$password${NC}"
    echo -e " ${WHITE}Dropbear${NC}     : ${CYAN}$SERVER_HOST:$DROPBEAR_PORT@$username:$password${NC}"
    echo -e " ${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}► WEBSOCKET PATHS:${NC}"
    echo -e " ${WHITE}OpenSSH Path${NC} : ${GREEN}/ssh${NC} ${YELLOW}(Port $WS_PORT)${NC}"
    echo -e " ${WHITE}Dropbear Path${NC}: ${GREEN}/dropbear${NC} ${YELLOW}(Port $WS_PORT)${NC}"
    echo -e " ${CYAN}────────────────────────────────────────────────────────${NC}"
    
    CONNECTION_STRING="ssh://$username:$password@$SERVER_HOST:22"
    
    if command -v qrencode &> /dev/null; then
        echo ""
        echo -e " ${WHITE}[QR CODE - SSH Connection]${NC}"
        qrencode -t ANSIUTF8 "$CONNECTION_STRING"
    else
        echo ""
        echo -e " ${YELLOW}[Install qrencode for QR code: apt install qrencode]${NC}"
    fi
    
    echo ""
    echo -e " ${GREEN}✓ Account created successfully!${NC}"
    echo -e " ${YELLOW}⚠ Save this information!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

delete_ssh_user() {
    show_header "› SSH › Delete Account"
    read -p "  Username to delete: " username
    
    if ! id "$username" &>/dev/null; then
        echo ""
        echo -e "  ${RED}✗ User does not exist!${NC}"
        echo ""
        read -p "  Press enter to continue..."
        return
    fi
    
    pkill -u $username 2>/dev/null
    userdel -r $username 2>/dev/null
    sed -i "/^$username|/d" /usr/local/afterlifevpn/users/ssh_users.txt 2>/dev/null
    
    # Remove from proxy auth
    if [ -f /etc/squid/passwd ]; then
        htpasswd -D /etc/squid/passwd $username 2>/dev/null
    fi
    
    echo ""
    echo -e "  ${GREEN}✓ User '$username' deleted successfully!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

extend_ssh_user() {
    show_header "› SSH › Extend Account"
    read -p "  Username: " username
    
    if ! id "$username" &>/dev/null; then
        echo ""
        echo -e "  ${RED}✗ User does not exist!${NC}"
        echo ""
        read -p "  Press enter to continue..."
        return
    fi
    
    read -p "  Add days: " days
    chage -E $(date -d "+$days days" +%Y-%m-%d) $username
    
    echo ""
    echo -e "  ${GREEN}✓ Account extended by $days days!${NC}"
    echo -e "  ${WHITE}New expiry:${NC} $(date -d "+$days days" +"%Y-%m-%d")"
    echo ""
    read -p "  Press enter to continue..."
}

list_ssh_users() {
    show_header "› SSH › User List"
    
    if [ ! -f /usr/local/afterlifevpn/users/ssh_users.txt ]; then
        echo -e "  ${YELLOW}No users found${NC}"
        echo ""
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

# Function: Check User Login (CLEAN VERSION)
check_user_login() {
    show_header "› SSH › User Login Status"
    
    read -p "  Username: " username
    
    if ! id "$username" &>/dev/null; then
        echo ""
        echo -e "  ${RED}✗ User does not exist!${NC}"
        echo ""
        read -p "  Press enter to continue..."
        return
    fi
    
    echo ""
    echo -e "  ${WHITE}Checking login for:${NC} $username"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"
    
    if who | grep -q "^$username "; then
        echo -e "  ${GREEN}● User is currently logged in${NC}"
        echo ""
        who | grep "^$username " | while read line; do
            echo -e "  $line"
        done
    else
        echo -e "  ${YELLOW}○ User is not logged in${NC}"
    fi
    
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Change Dropbear Port (CLEAN VERSION)
change_dropbear_port() {
    show_header "› SSH › Change Dropbear Port"
    
    local current_port=$(grep DROPBEAR_PORT /etc/default/dropbear 2>/dev/null | cut -d'=' -f2 || echo "442")
    echo -e "  ${WHITE}Current port:${NC} $current_port"
    echo ""
    read -p "  Enter new port: " new_port
    
    sed -i "s/DROPBEAR_PORT=.*/DROPBEAR_PORT=$new_port/" /etc/default/dropbear
    sed -i "s/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"-p $new_port\"/" /etc/default/dropbear
    systemctl restart dropbear
    
    echo ""
    echo -e "  ${GREEN}✓ Dropbear port changed to $new_port${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Change WebSocket Port (CLEAN VERSION)
change_websocket_port() {
    show_header "› SSH › Change WebSocket Port"
    
    local current_port=$(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo "443")
    echo -e "  ${WHITE}Current port:${NC} $current_port"
    echo ""
    read -p "  Enter new port: " new_port
    
    sed -i "s/start_server = websockets.serve(proxy, \"0.0.0.0\", .*/start_server = websockets.serve(proxy, \"0.0.0.0\", $new_port, ssl=ssl_context)/" /usr/local/bin/ws-ssh.py
    echo "$new_port" > /usr/local/afterlifevpn/ws-port.conf
    systemctl restart ws-ssh
    
    echo ""
    echo -e "  ${GREEN}✓ WebSocket port changed to $new_port${NC}"
    echo -e "  ${YELLOW}⚠ Update your firewall rules!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Monitor Connections (CLEAN VERSION)
monitor_connections() {
    show_header "› SSH › Active Connections"
    
    echo -e "  ${YELLOW}SSH Connections:${NC}"
    local ssh_count=$(netstat -tnp 2>/dev/null | grep ':22' | grep ESTABLISHED | wc -l)
    echo -e "  Total: $ssh_count"
    netstat -tnp 2>/dev/null | grep ':22' | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10
    
    echo ""
    echo -e "  ${YELLOW}Dropbear Connections:${NC}"
    local drop_count=$(netstat -tnp 2>/dev/null | grep dropbear | grep ESTABLISHED | wc -l)
    echo -e "  Total: $drop_count"
    netstat -tnp 2>/dev/null | grep dropbear | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10
    
    echo ""
    echo -e "  ${YELLOW}Logged in Users:${NC}"
    who
    
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Edit SSH Banner (CLEAN VERSION)
edit_ssh_banner() {
    show_header "› SSH › Banner"
    
    echo -e "  ${WHITE}Current Banner (/etc/issue.net):${NC}"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"
    cat /etc/issue.net 2>/dev/null || echo "  No banner set"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Edit Banner with Nano"
    echo -e "  ${GREEN}2)${NC} Reset to Default AFTERLIFE Banner"
    echo -e "  ${GREEN}3)${NC} Disable Banner"
    echo ""
    read -p "  Select [1-3] or [Enter to return]: " banner_choice
    
    case $banner_choice in
        1)
            nano /etc/issue.net
            systemctl restart dropbear ssh
            echo ""
            echo -e "  ${GREEN}✓ Banner updated!${NC}"
            sleep 2
            ;;
        2)
            cat > /etc/issue.net <<'EOF'
════════════════════════════════════════
        AFTERLIFE VPN Server
════════════════════════════════════════
 No DDOS | No Torrent | No Mining
 No Hacking | No Spam
════════════════════════════════════════
EOF
            systemctl restart dropbear ssh
            echo ""
            echo -e "  ${GREEN}✓ Banner reset to default!${NC}"
            sleep 2
            ;;
        3)
            echo "" > /etc/issue.net
            systemctl restart dropbear ssh
            echo ""
            echo -e "  ${GREEN}✓ Banner disabled!${NC}"
            sleep 2
            ;;
    esac
}

# Submenu: Xray Protocols (CLEAN VERSION)
menu_xray() {
    while true; do
        show_header "› Xray › Management"
        echo -e "  ${GREEN}1)${NC} Show VMess Configuration"
        echo -e "  ${GREEN}2)${NC} Create VMess Account"
        echo -e "  ${GREEN}3)${NC} Delete VMess Account"
        echo -e "  ${GREEN}4)${NC} List VMess Users"
        echo -e "  ${GREEN}5)${NC} Restart Xray Service"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
        read -p "  Select option: " xray_option
        
        case $xray_option in
            1) show_vmess_config ;;
            2) create_vmess_user ;;
            3) delete_vmess_user ;;
            4) list_vmess_users ;;
            5) systemctl restart xray; echo "  ${GREEN}✓ Xray restarted${NC}"; sleep 2 ;;
            0) break ;;
            *) ;;
        esac
    done
}

# Function: Show VMess Config (CLEAN VERSION)
show_vmess_config() {
    show_header "› Xray › VMess Configuration"
    
    if [ -f /usr/local/afterlifevpn/vmess-config.txt ]; then
        cat /usr/local/afterlifevpn/vmess-config.txt
    else
        echo -e "  ${YELLOW}No configuration found${NC}"
    fi
    
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Create VMess User
create_vmess_user() {
    show_header "› Xray › Create VMess Account"
    
    read -p "  Username: " username
    read -p "  Expiry (days): " days
    
    # Check if user exists
    if grep -q "^$username|" /usr/local/afterlifevpn/users/xray_users.txt 2>/dev/null; then
        echo ""
        echo -e "  ${RED}✗ User already exists!${NC}"
        echo ""
        read -p "  Press enter to continue..."
        return
    fi
    
    # Create user using helper script
    UUID=$(bash /usr/local/afterlifevpn/setup/xray-user.sh add "$username" "$days")
    
    # Get server info
    get_system_info
    SERVER_HOST="${DOMAIN:-$PUBLIC_IP}"
    EXPIRY_DATE=$(date -d "+$days days" +"%b %d, %Y")
    
    # Display account info
    clear
    echo -e "${CYAN}╭────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                        ${WHITE}VMESS ACCOUNT CREATED${NC}                       ${CYAN}│${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────────────────╯${NC}"
    echo -e " ${WHITE}Username${NC}     : ${GREEN}$username${NC}"
    echo -e " ${WHITE}UUID${NC}         : ${GREEN}$UUID${NC}"
    echo -e " ${WHITE}Expired On${NC}   : ${RED}$EXPIRY_DATE${NC}"
    echo -e " ${WHITE}Host${NC}         : ${CYAN}$SERVER_HOST${NC}"
    echo -e " ${WHITE}Port${NC}         : ${CYAN}443${NC}"
    echo -e " ${WHITE}Network${NC}      : ${CYAN}ws${NC}"
    echo -e " ${WHITE}Path${NC}         : ${CYAN}/vmess${NC}"
    echo -e " ${WHITE}TLS${NC}          : ${GREEN}Enabled${NC}"
    echo -e " ${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}VMess Link${NC}   : ${YELLOW}vmess://$UUID@$SERVER_HOST:443${NC}"
    echo ""
    echo -e " ${GREEN}✓ VMess account created successfully!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Delete VMess User
delete_vmess_user() {
    show_header "› Xray › Delete VMess Account"
    
    read -p "  Username to delete: " username
    
    if ! grep -q "^$username|" /usr/local/afterlifevpn/users/xray_users.txt 2>/dev/null; then
        echo ""
        echo -e "  ${RED}✗ User does not exist!${NC}"
        echo ""
        read -p "  Press enter to continue..."
        return
    fi
    
    # Delete user
    bash /usr/local/afterlifevpn/setup/xray-user.sh delete "$username"
    
    echo ""
    echo -e "  ${GREEN}✓ User '$username' deleted successfully!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

# Function: List VMess Users
list_vmess_users() {
    show_header "› Xray › VMess User List"
    
    if [ ! -f /usr/local/afterlifevpn/users/xray_users.txt ]; then
        echo -e "  ${YELLOW}No users found${NC}"
        echo ""
        read -p "  Press enter to continue..."
        return
    fi
    
    echo -e "  ${WHITE}Username${NC}     ${WHITE}UUID${NC}                                  ${WHITE}Expires${NC}"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────────────────────${NC}"
    
    while IFS='|' read -r user uuid expiry created; do
        printf "  %-12s %-38s %s\n" "$user" "$uuid" "$expiry"
    done < /usr/local/afterlifevpn/users/xray_users.txt
    
    echo ""
    read -p "  Press enter to continue..."
}

# Submenu: Hysteria 2 (CLEAN VERSION)
menu_hysteria() {
    while true; do
        show_header "› Hysteria › Management"
        echo -e "  ${GREEN}1)${NC} Show Hysteria Configuration"
        echo -e "  ${GREEN}2)${NC} Create Hysteria Account"
        echo -e "  ${GREEN}3)${NC} Delete Hysteria Account"
        echo -e "  ${GREEN}4)${NC} List Hysteria Users"
        echo -e "  ${GREEN}5)${NC} Change Port Mode (Single/Hopping)"
        echo -e "  ${GREEN}6)${NC} Restart Hysteria Service"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
        read -p "  Select option: " hyst_option
        
        case $hyst_option in
            1) show_hysteria_config ;;
            2) create_hysteria_user ;;
            3) delete_hysteria_user ;;
            4) list_hysteria_users ;;
            5) change_hysteria_mode ;;
            6) systemctl restart hysteria; echo "  ${GREEN}✓ Hysteria restarted${NC}"; sleep 2 ;;
            0) break ;;
            *) ;;
        esac
    done
}

# Function: Show Hysteria Config (CLEAN VERSION)
show_hysteria_config() {
    show_header "› Hysteria › Configuration"
    
    if [ -f /usr/local/afterlifevpn/hysteria-config.txt ]; then
        cat /usr/local/afterlifevpn/hysteria-config.txt
    else
        echo -e "  ${YELLOW}No configuration found${NC}"
    fi
    
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Create Hysteria User
create_hysteria_user() {
    show_header "› Hysteria › Create Account"
    
    read -p "  Username: " username
    read -p "  Expiry (days): " days
    
    # Check if user exists
    if grep -q "^$username|" /usr/local/afterlifevpn/users/hysteria_users.txt 2>/dev/null; then
        echo ""
        echo -e "  ${RED}✗ User already exists!${NC}"
        echo ""
        read -p "  Press enter to continue..."
        return
    fi
    
    # Create user
    PASSWORD=$(bash /usr/local/afterlifevpn/setup/hysteria-user.sh add "$username" "$days")
    
    # Get server info
    get_system_info
    SERVER_HOST="${DOMAIN:-$PUBLIC_IP}"
    EXPIRY_DATE=$(date -d "+$days days" +"%b %d, %Y")
    
    # Display account info
    clear
    echo -e "${CYAN}╭────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${NC}                      ${WHITE}HYSTERIA 2 ACCOUNT CREATED${NC}                   ${CYAN}│${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────────────────╯${NC}"
    echo -e " ${WHITE}Username${NC}     : ${GREEN}$username${NC}"
    echo -e " ${WHITE}Password${NC}     : ${GREEN}$PASSWORD${NC}"
    echo -e " ${WHITE}Expired On${NC}   : ${RED}$EXPIRY_DATE${NC}"
    echo -e " ${WHITE}Server${NC}       : ${CYAN}$SERVER_HOST${NC}"
    echo -e " ${WHITE}Protocol${NC}     : ${CYAN}UDP (QUIC)${NC}"
    echo -e " ${WHITE}Ports${NC}        : ${CYAN}$(grep "listen:" /etc/hysteria/config.yaml | awk '{print $2}' | sed 's/://')${NC}"
    echo -e " ${CYAN}────────────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}Connection${NC}   : ${YELLOW}hysteria2://$username:$PASSWORD@$PUBLIC_IP:443${NC}"
    echo ""
    echo -e " ${GREEN}✓ Hysteria 2 account created successfully!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Delete Hysteria User
delete_hysteria_user() {
    show_header "› Hysteria › Delete Account"
    
    read -p "  Username to delete: " username
    
    if ! grep -q "^$username|" /usr/local/afterlifevpn/users/hysteria_users.txt 2>/dev/null; then
        echo ""
        echo -e "  ${RED}✗ User does not exist!${NC}"
        echo ""
        read -p "  Press enter to continue..."
        return
    fi
    
    # Delete user
    bash /usr/local/afterlifevpn/setup/hysteria-user.sh delete "$username"
    
    echo ""
    echo -e "  ${GREEN}✓ User '$username' deleted successfully!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

# Function: List Hysteria Users
list_hysteria_users() {
    show_header "› Hysteria › User List"
    
    if [ ! -f /usr/local/afterlifevpn/users/hysteria_users.txt ]; then
        echo -e "  ${YELLOW}No users found${NC}"
        echo ""
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

# Function: Change Hysteria Mode (CLEAN VERSION)
change_hysteria_mode() {
    show_header "› Hysteria › Port Configuration"
    
    echo -e "  ${GREEN}1)${NC} Single Port Mode"
    echo -e "  ${GREEN}2)${NC} Port Hopping Mode"
    echo ""
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
  type: password
  password: $(grep "password:" /etc/hysteria/config.yaml 2>/dev/null | awk '{print $2}' || openssl rand -base64 16)

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
        echo ""
        echo -e "  ${GREEN}✓ Hysteria set to single port: $single_port${NC}"
        
    elif [[ $mode_choice == "2" ]]; then
        
        read -p "  Enter port range (e.g., 20000-40000): " port_range
        read -p "  Include port 53? (y/n): " inc_53
        
        if [[ $inc_53 == "y" ]]; then
            listen_ports="53,$port_range"
        else
            listen_ports="$port_range"
        fi
        
        cat > /etc/hysteria/config.yaml <<EOF
listen: :$listen_ports

tls:
  cert: /etc/afterlifevpn/cert/fullchain.crt
  key: /etc/afterlifevpn/cert/private.key

auth:
  type: password
  password: $(grep "password:" /etc/hysteria/config.yaml 2>/dev/null | awk '{print $2}' || openssl rand -base64 16)

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
        echo ""
        echo -e "  ${GREEN}✓ Hysteria set to port hopping: $listen_ports${NC}"
    fi
    
    echo ""
    read -p "  Press enter to continue..."
}

# Placeholder menus
menu_wireguard() {
    show_header "› WireGuard › Management"
    echo -e "  ${YELLOW}WireGuard VPN - Coming Soon!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

menu_l2tp() {
    show_header "› L2TP › Management"
    echo -e "  ${YELLOW}L2TP/IPsec VPN - Coming Soon!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

menu_subscriptions() {
    show_header "› Subscriptions › Management"
    echo -e "  ${YELLOW}Subscription Management - Coming Soon!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

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
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
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

# Function: Clear Logs
clear_logs() {
    show_header "› Settings › Clear Logs"
    echo -e "  ${YELLOW}Clearing system logs...${NC}"
    journalctl --vacuum-time=1d
    journalctl --vacuum-size=50M
    echo "" > /var/log/syslog 2>/dev/null
    echo "" > /var/log/auth.log 2>/dev/null
    echo ""
    echo -e "  ${GREEN}✓ Logs cleared!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

# Function: View Logs
view_logs() {
    show_header "› Settings › Service Logs"
    echo -e "  ${GREEN}1)${NC} SSH WebSocket"
    echo -e "  ${GREEN}2)${NC} Xray (VMess)"
    echo -e "  ${GREEN}3)${NC} Hysteria 2"
    echo -e "  ${GREEN}4)${NC} Dropbear"
    echo ""
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

# Function: Restart All Services
restart_all_services() {
    show_header "› Settings › Restart Services"
    echo -e "  ${YELLOW}Restarting all services...${NC}"
    systemctl restart ws-ssh xray hysteria udp-custom dropbear
    echo ""
    echo -e "  ${GREEN}✓ All services restarted!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Check All Services
check_all_services() {
    show_header "› Settings › Service Status"
    
    services=("ws-ssh" "xray" "hysteria" "udp-custom" "dropbear")
    names=("SSH WebSocket" "Xray (VMess)" "Hysteria 2" "UDP Custom" "Dropbear")
    
    for i in "${!services[@]}"; do
        if systemctl is-active --quiet ${services[$i]}; then
            echo -e "  ${GREEN}●${NC} ${names[$i]}: ${GREEN}Running${NC}"
        else
            echo -e "  ${RED}○${NC} ${names[$i]}: ${RED}Stopped${NC}"
        fi
    done
    
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Bandwidth Limiter
bandwidth_limiter() {
    show_header "› Settings › Bandwidth Limiter"
    echo -e "  ${YELLOW}Feature coming soon...${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

menu_backup() {
    while true; do
        show_header "› Backup › Management"
        echo -e "  ${GREEN}1)${NC} Backup Configuration"
        echo -e "  ${GREEN}2)${NC} Restore Configuration"
        echo -e "  ${GREEN}3)${NC} List Backups"
        echo -e "  ${GREEN}4)${NC} Telegram Bot (Coming Soon)"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
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

# Function: Create Backup
create_backup() {
    show_header "› Backup › Create"
    echo -e "  ${YELLOW}Creating backup...${NC}"
    
    BACKUP_DIR="/root/afterlifevpn-backup"
    BACKUP_FILE="afterlifevpn-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    mkdir -p $BACKUP_DIR
    TEMP_BACKUP="/tmp/afterlifevpn-backup-temp"
    mkdir -p $TEMP_BACKUP
    
    cp -r /usr/local/afterlifevpn $TEMP_BACKUP/ 2>/dev/null
    cp -r /etc/afterlifevpn $TEMP_BACKUP/ 2>/dev/null
    cp -r /etc/hysteria $TEMP_BACKUP/ 2>/dev/null
    cp /usr/local/etc/xray/config.json $TEMP_BACKUP/ 2>/dev/null
    
    cd /tmp
    tar -czf $BACKUP_DIR/$BACKUP_FILE afterlifevpn-backup-temp/
    rm -rf $TEMP_BACKUP
    
    echo ""
    echo -e "  ${GREEN}✓ Backup completed!${NC}"
    echo -e "  ${WHITE}Saved to:${NC} $BACKUP_DIR/$BACKUP_FILE"
    echo -e "  ${WHITE}Size:${NC} $(du -h $BACKUP_DIR/$BACKUP_FILE | awk '{print $1}')"
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Restore Backup
restore_backup() {
    show_header "› Backup › Restore"
    echo -e "  ${YELLOW}Feature coming soon...${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

# Function: List Backups
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
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu"
        echo ""
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

# Function: Renew Certificate
renew_certificate() {
    show_header "› Domain › Renew Certificate"
    echo -e "  ${YELLOW}Renewing SSL certificate...${NC}"
    source /usr/local/afterlifevpn/config.conf
    ~/.acme.sh/acme.sh --renew -d "$DOMAIN" --force
    systemctl restart ws-ssh xray hysteria
    echo ""
    echo -e "  ${GREEN}✓ Certificate renewed!${NC}"
    echo ""
    read -p "  Press enter to continue..."
}

# Function: View Certificate
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

# Function: Update Script
update_script() {
    show_header "› System › Update"
    echo -e "  ${YELLOW}Checking for updates...${NC}"
    
   wget -q -O /tmp/menu.sh "https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main/menu/menu.sh"
    
    if [ $? -eq 0 ]; then
        cp /tmp/menu.sh /usr/local/afterlifevpn/menu/menu.sh
        chmod +x /usr/local/afterlifevpn/menu/menu.sh
        echo ""
        echo -e "  ${GREEN}✓ Menu updated successfully!${NC}"
        echo -e "  ${YELLOW}⚠ Restart menu to apply changes${NC}"
    else
        echo ""
        echo -e "  ${RED}✗ Update failed!${NC}"
    fi
    
    echo ""
    read -p "  Press enter to continue..."
}

# Function: Full Diagnostics
full_diagnostics() {
    show_header "› System › Full Diagnostics"
    
    get_system_info
    
    echo -e "  ${WHITE}[System Information]${NC}"
    echo -e "  Hostname: $HOSTNAME"
    echo -e "  Public IP: $PUBLIC_IP"
    echo -e "  OS: $OS_VERSION"
    echo -e "  Kernel: $(uname -r)"
    echo -e "  Uptime: $UPTIME"
    echo ""
    
    echo -e "  ${WHITE}[Resource Usage]${NC}"
    echo -e "  CPU: ${CPU_USAGE}% (${CPU_CORES} cores)"
    echo -e "  RAM: ${USED_RAM}MB / ${TOTAL_RAM}MB (${RAM_PERCENT}%)"
    echo -e "  Disk: ${USED_DISK} / ${TOTAL_DISK} (${DISK_PERCENT}%)"
    echo ""
    
    echo -e "  ${WHITE}[Services]${NC}"
    services=("ws-ssh" "xray" "hysteria" "udp-custom" "dropbear")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet $service; then
            echo -e "  ${GREEN}●${NC} $service: Running"
        else
            echo -e "  ${RED}○${NC} $service: Stopped"
        fi
    done
    echo ""
    
    echo -e "  ${WHITE}[Users]${NC}"
    echo -e "  Total registered: $(count_users)"
    echo -e "  Currently online: $(who | wc -l)"
    echo ""
    
    read -p "  Press enter to continue..."
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
