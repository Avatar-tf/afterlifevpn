#!/bin/bash
# Enforce Root Privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31mError: This script must be run as root.\033[0m"
    exit 1
fi

# Exit instead of spinning when the terminal disappears
trap 'exit 0' HUP TERM
read() {
    builtin read "$@" && return 0
    local rc=$? a
    for a in "$@"; do [[ $a == -*p* ]] && exit 0; done
    return $rc
}
export -f read

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Load configuration and Nameserver
if [ -f /usr/local/afterlifevpn/config.conf ]; then
    source /usr/local/afterlifevpn/config.conf
fi
ACTIVE_NS=""
if [ -f /usr/local/afterlifevpn/nameserver.conf ]; then
    ACTIVE_NS=$(grep -E "^NS_HOST=" /usr/local/afterlifevpn/nameserver.conf | cut -d'"' -f2 | cut -d"'" -f2)
fi

# Smart Iptables Wrapper (Forces legacy over nftables for Azure compatibility)
ipt_cmd() {
    if command -v iptables-legacy >/dev/null 2>&1; then
        iptables-legacy "$@"
    else
        iptables "$@"
    fi
}
ipt_save_cmd() {
    if command -v iptables-legacy-save >/dev/null 2>&1; then
        iptables-legacy-save "$@"
    else
        iptables-save "$@"
    fi
}

# Get system information
get_system_info() {
    HOSTNAME=$(hostname)
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "N/A")
    OS_VERSION=$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
    UPTIME=$(uptime -p | sed 's/up //')
    CPU_CORES=$(nproc)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    CPU_USAGE_INT=${CPU_USAGE%.*}
    read -r TOTAL_RAM USED_RAM <<< $(free -m | awk 'NR==2{print $2, $3}')
    RAM_PERCENT=$((USED_RAM * 100 / TOTAL_RAM))
    read -r TOTAL_DISK USED_DISK DISK_PERCENT <<< $(df -h / | awk 'NR==2{print $2, $3, $5}' | tr -d '%')
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
    if [[ -n "$ACTIVE_NS" ]]; then
        echo -e "${CYAN}║${NC} ${CYAN}Nameserver:${NC}                      ${GREEN}${ACTIVE_NS}${NC} ${CYAN}║${NC}"
    fi
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
    if [[ -n "$ACTIVE_NS" ]]; then
        echo -e "${CYAN}║${NC} ${CYAN}Nameserver:${NC}                      ${GREEN}${ACTIVE_NS}${NC} ${CYAN}║${NC}"
    fi
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
    echo -e "${CYAN}│${NC} ${GREEN}11)${NC} Port 53 Toggle (SlowDNS / Hysteria)                 ${CYAN}│${NC}"
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
    local username password days devices quota exp_date SERVER_HOST WS_PORT PUB_KEY
    read -p "  Username: " username
    if [[ -z "$username" ]]; then echo -e "\n  ${RED}✗ Username cannot be empty!${NC}\n"; read -p "  Press enter..."; return; fi
    read -p "  Password: " password
    read -p "  Expiry (days): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "\n  ${RED}✗ Expiry must be a number of days!${NC}\n"; read -p "  Press enter..."; return; fi
    read -p "  Max Devices (default 2): " devices
    devices=${devices:-2}
    read -p "  Data Quota (default Unlimited): " quota
    quota=${quota:-Unlimited}
    
    if id "$username" &>/dev/null; then
        echo -e "\n  ${RED}✗ User already exists!${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    
    exp_date=$(date -d "+$days days" +"%Y-%m-%d")
    useradd -e "$exp_date" -s /bin/false -M "$username"
    echo "$username:$password" | chpasswd
    if command -v htpasswd &> /dev/null && [ -f /etc/squid/passwd ]; then
        htpasswd -b /etc/squid/passwd "$username" "$password" 2>/dev/null
    fi
    
    mkdir -p /usr/local/afterlifevpn/users
    echo "$username|$password|$exp_date|$(date +%Y-%m-%d)|$devices|$quota" >> /usr/local/afterlifevpn/users/ssh_users.txt
    
    SERVER_HOST="${DOMAIN:-$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "N/A")}"
    WS_PORT=$(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo 443)
    
    # Locate SlowDNS Public Key dynamically
    PUB_KEY="Not Installed"
    for path in /etc/slowdns/server.pub /usr/local/afterlifevpn/server.pub /etc/afterlifevpn/slowdns/server.pub; do
        if [[ -f "$path" ]]; then
            PUB_KEY=$(cat "$path")
            break
        fi
    done

    # Silently map UDP 36712 to the 7300 backend for HTTP Custom compatibility
    if ! ipt_cmd -t nat -C PREROUTING -p udp --dport 36712 -j REDIRECT --to-ports 7300 2>/dev/null; then
        ipt_cmd -t nat -A PREROUTING -p udp --dport 36712 -j REDIRECT --to-ports 7300 2>/dev/null
        command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1
    fi

    clear
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "         🔐 ${WHITE}AFTERLIFE VPN — SSH ACCOUNT${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e " 👤 ${WHITE}ACCOUNT${NC}"
    echo -e "   Username    : ${GREEN}$username${NC}"
    echo -e "   Password    : ${GREEN}$password${NC}"
    echo -e "   Expires     : ${RED}$exp_date${NC}"
    echo -e "   Devices     : ${YELLOW}$devices${NC}"
    echo -e "   Data Quota  : ${YELLOW}$quota${NC}"
    echo -e "   ${CYAN}══════════════════════════════${NC}"
    echo -e " 🌐 ${WHITE}SERVER${NC}"
    echo -e "   Host        : ${GREEN}$SERVER_HOST${NC}"
    echo -e "   Nameserver  : ${GREEN}${ACTIVE_NS:-Not Configured}${NC}"
    echo -e "   SlowDNS     : ${YELLOW}${PUB_KEY}${NC}"
    echo -e "   WS Ports    : ${YELLOW}80 / $WS_PORT${NC}"
    echo -e "   SSL Ports   : ${YELLOW}443 / 777${NC}"
    echo -e "   SlowDNS Port: ${YELLOW}53${NC}"
    echo -e "   UDP-Custom  : ${YELLOW}port 53 or 36712 (same login)${NC}"
    echo -e "   ${CYAN}══════════════════════════════${NC}"
    echo -e " 📡 ${WHITE}HTTP CUSTOM PAYLOADS${NC}"
    echo -e "   ① Port 80 — WebSocket"
    echo -e "   ${YELLOW}GET / HTTP/1.1[crlf]Host: $SERVER_HOST[crlf]Upgrade: websocket[crlf][crlf]${NC}"
    echo -e "   ${CYAN}══════════════════════════════${NC}"
    echo -e "   ② Port 443 — WebSocket TLS (WSS)"
    echo -e "   ${YELLOW}GET wss://$SERVER_HOST/ HTTP/1.1[crlf]Host: $SERVER_HOST[crlf]Upgrade: websocket[crlf][crlf]${NC}"
    echo -e "   ${CYAN}══════════════════════════════${NC}"
    echo -e "   ③ CONNECT (proxy / injector)"
    echo -e "   ${YELLOW}CONNECT $SERVER_HOST:80 HTTP/1.1[crlf]Host: $SERVER_HOST[crlf][crlf]${NC}"
    echo -e "   ${CYAN}══════════════════════════════${NC}"
    echo -e "   ④ Front-Inject — replace [bug] with your bug host"
    echo -e "   ${YELLOW}GET http://[bug]/ HTTP/1.1[crlf]Host: $SERVER_HOST[crlf]Upgrade: websocket[crlf][crlf]${NC}"
    echo -e "   ${CYAN}══════════════════════════════${NC}"
    echo -e "   ⑤ Header-Spoof (X-Online-Host)"
    echo -e "   ${YELLOW}GET / HTTP/1.1[crlf]Host: $SERVER_HOST[crlf]X-Online-Host: $SERVER_HOST[crlf]X-Forward-Host: $SERVER_HOST[crlf]Upgrade: websocket[crlf][crlf]${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
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
    local current_port
    current_port=$(grep -E "^DROPBEAR_PORT=" /etc/default/dropbear 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "109")
    echo -e "  ${WHITE}Current Dropbear Port:${NC} ${GREEN}$current_port${NC}"
    echo ""
    read -p "  Enter new port (1024-65535): " new_port
    if [[ -z "$new_port" ]]; then echo -e "\n  ${YELLOW}No change made.${NC}"; read -p "  Press enter..."; return; fi
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "\n  ${RED}✗ Invalid port! Please use a number between 1024 and 65535.${NC}"; read -p "  Press enter..."; return; fi
    if ss -tuln | grep -q ":$new_port "; then echo -e "\n  ${RED}✗ Port $new_port is already in use!${NC}"; read -p "  Press enter..."; return; fi
    sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$new_port/" /etc/default/dropbear
    sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"-p $new_port\"/" /etc/default/dropbear
    grep -q "^DROPBEAR_PORT=" /etc/default/dropbear || echo "DROPBEAR_PORT=$new_port" >> /etc/default/dropbear
    grep -q "^DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear || echo "DROPBEAR_EXTRA_ARGS=\"-p $new_port\"" >> /etc/default/dropbear
    ipt_cmd -I INPUT -p tcp --dport $new_port -j ACCEPT 2>/dev/null
    netfilter-persistent save >/dev/null 2>&1 || true
    systemctl restart dropbear
    echo -e "\n  ${GREEN}✓ Dropbear port changed to $new_port${NC}"
    read -p "  Press enter to continue..."
}
change_websocket_port() {
    show_header "› SSH › Change WebSocket Port"
    local current_port=$(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo "8880")
    local new_port
    echo -e "  ${WHITE}Current port:${NC} $current_port\n"
    read -p "  Enter new port: " new_port
    new_port=${new_port:-$current_port}
    if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then echo -e "\n  ${RED}✗ Invalid port!${NC}\n"; read -p "  Press enter..."; return; fi
    echo "$new_port" > /usr/local/afterlifevpn/ws-port.conf
    systemctl restart ws-ssh
    echo -e "\n  ${GREEN}✓ WebSocket port changed to $new_port${NC}"
    read -p "  Press enter to continue..."
}
monitor_connections() {
    show_header "› SSH › Active Connections"
    echo -e "  ${YELLOW}SSH Connections:${NC}"
    local ssh_count=$(ss -tnp 2>/dev/null | grep ':22' | grep ESTAB | wc -l)
    echo -e "  Total: $ssh_count"
    echo -e "\n  ${YELLOW}Dropbear Connections:${NC}"
    local drop_count=$(ss -tnp 2>/dev/null | grep dropbear | grep ESTAB | wc -l)
    echo -e "  Total: $drop_count"
    echo -e "\n  ${YELLOW}Logged in Users:${NC}"
    who
    echo ""
    read -p "  Press enter to continue..."
}
edit_ssh_banner() {
    show_header "› SSH › Banner"
    echo -e "  ${WHITE}Current Banner (/etc/issue.net):${NC}"
    cat /etc/issue.net 2>/dev/null || echo "  No banner set"
    echo -e "\n  ${GREEN}1)${NC} Edit Banner with Nano"
    echo -e "  ${GREEN}2)${NC} Reset Default Banner"
    echo -e "  ${GREEN}3)${NC} Disable Banner\n"
    read -p "  Select [1-3] or [Enter to return]: " banner_choice
    case $banner_choice in
        1) nano /etc/issue.net; systemctl restart dropbear ssh; ;;
        2) cat > /etc/issue.net <<'EOF'
════════════════════════════════════════
        AFTERLIFE VPN Server
════════════════════════════════════════
EOF
           systemctl restart dropbear ssh; ;;
        3) echo "" > /etc/issue.net; systemctl restart dropbear ssh; ;;
    esac
}

# ============================================================================
# XRAY MANAGEMENT
# ============================================================================
menu_xray() {
    while true; do
        clear
        local SERVER_HOST="${DOMAIN:-$PUBLIC_IP}"
        echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
        printf "${CYAN}║ ${WHITE}AFTERLIFE VPN                                    ${YELLOW}%-17s${CYAN} ║\n${NC}" "$SERVER_HOST"
        echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
        echo -e "${CYAN}║ ${YELLOW}› Main › Xray${CYAN}                                          ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
        echo -e "\n  ${GREEN}1)${NC} Create VMess Account"
        echo -e "  ${GREEN}2)${NC} Create VLess Account"
        echo -e "  ${GREEN}3)${NC} Create Trojan Account"
        echo -e "  ${GREEN}4)${NC} List All Xray Users"
        echo -e "  ${GREEN}5)${NC} Check Online Users"
        echo -e "  ${GREEN}6)${NC} Service Status\n"
        echo -e "  ${RED}0)${NC} Back"
        echo -e ""
        read -p "  Select Option: " sub_opt
        case $sub_opt in
            1) create_vmess_user ;;
            2) bash /usr/local/afterlifevpn/setup/xray-add-vless.sh ;;
            3) bash /usr/local/afterlifevpn/setup/xray-add-trojan.sh ;;
            4) list_vmess_users ;;
            5) bash /usr/local/afterlifevpn/setup/xray-online.sh ;;
            6) clear; echo -e "\n  ${YELLOW}Xray Status:${NC}"; systemctl status xray --no-pager | grep -E "Active|Started"; echo ""; read -p "  Press [Enter] to return..." ;;
            0) break ;;
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
    if grep -qE "^${username}[:|]" /usr/local/afterlifevpn/users/xray_users.txt 2>/dev/null; then
        echo -e "\n  ${RED}✗ User already exists!${NC}\n"; read -p "  Press enter..."; return; fi
    local XRAY_OUT UUID
    XRAY_OUT=$(bash /usr/local/afterlifevpn/setup/xray-user.sh add "$username" "$days" 2>&1)
    UUID=$(grep -oEi '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<< "$XRAY_OUT" | head -n 1)
    if [[ -z "$UUID" ]]; then echo -e "\n  ${RED}✗ Could not create the account.${NC}\n"; read -p "  Press enter..."; return; fi
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
    echo -e " ⚡ ${WHITE}STANDARD LINK${NC}"
    echo -e "   ${YELLOW}$VMESS_LINK${NC}"
    echo -e "\n ${GREEN}✓ VMess account created successfully!${NC}\n"
    read -p "  Press enter to continue..."
}
list_vmess_users() {
    show_header "› Xray › VMess User List"
    if [ ! -f /usr/local/afterlifevpn/users/xray_users.txt ]; then echo -e "  ${YELLOW}No users found${NC}\n"; read -p "  Press enter..."; return; fi
    echo -e "  ${WHITE}Username${NC}     ${WHITE}UUID${NC}                                   ${WHITE}Expires${NC}"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────────────────────${NC}"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        line=${line//|/:}
        user=${line%%:*}
        rest=${line#*:}
        uuid=${rest%%:*}
        expiry=${rest#*:}
        printf "  %-12s %-38s %s\n" "$user" "$uuid" "$expiry"
    done < /usr/local/afterlifevpn/users/xray_users.txt
    echo ""
    read -p "  Press enter to continue..."
}

# ============================================================================
# HYSTERIA 2 MANAGEMENT
# ============================================================================
menu_hysteria() {
    while true; do
        clear
        local SERVER_HOST="${DOMAIN:-$PUBLIC_IP}"
        echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
        printf "${CYAN}║ ${WHITE}AFTERLIFE VPN                                    ${YELLOW}%-17s${CYAN} ║\n${NC}" "$SERVER_HOST"
        echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
        echo -e "${CYAN}║ ${YELLOW}› Main › Hysteria 2${CYAN}                                      ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
        echo -e "\n    ${GREEN}1)${NC}  Manage Users (Add / Delete / List)"
        echo -e "    ${GREEN}2)${NC}  Reinstall Hysteria"
        echo -e "    ${GREEN}3)${NC}  Service Status"
        echo -e "    ${GREEN}4)${NC}  Restart Hysteria\n"
        echo -e "  ${RED}0)${NC} Back\n"
        read -p "  Select [0-4]: " sub_opt
        case $sub_opt in
            1) bash /usr/local/afterlifevpn/setup/hysteria-user.sh ;;
            2) bash /usr/local/afterlifevpn/setup/hysteria.sh ;;
            3) clear; echo -e "\n  ${YELLOW}Hysteria Status:${NC}"; systemctl status hysteria --no-pager -l; echo ""; read -p "  Press [Enter] to return..." ;;
            4) systemctl restart hysteria; echo -e "\n  ${GREEN}✓ Hysteria restarted${NC}"; sleep 1.5 ;;
            0) break ;;
            *) continue ;;
        esac
    done
}

# ============================================================================
# ADVANCED PORT 53 MULTIPLEXER (Cascading Demux Engine)
# ============================================================================
P53_BASE=/usr/local/afterlifevpn
P53_HY_CFG=/etc/hysteria/config.yaml
P53_HY_TXT=$P53_BASE/hysteria-config.txt
P53_STATE=$P53_BASE/port53-mode.conf
P53_NS_FILE=$P53_BASE/nameserver.conf
P53_CHAIN=AFTERLIFE_MUX
P53_SLOWDNS_PORT=5300
P53_UDPC_PORT=7300
P53_HY_PORT=4430
P53_OBFS_TAG='#AFTERLIFE-OBFS# '

p53_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | tail -n1 | tr -d "\"'"; }

p53_load_state() {
    P53_MODE=$(p53_kv "$P53_STATE" MODE); P53_MODE=${P53_MODE:-none}
    P53_NS=$(p53_kv "$P53_NS_FILE" NS_HOST)
    [[ -z "$P53_NS" ]] && P53_NS=$(p53_kv "$P53_NS_FILE" NS_DOMAIN)
}

p53_udp_listening() { ss -uln 2>/dev/null | awk -v p=":$1" '$4 ~ p"$" {f=1} END{exit !f}'; }
p53_yn() { if "$@" >/dev/null 2>&1; then echo -e "${GREEN}yes${NC}"; else echo -e "${RED}no${NC}"; fi; }
p53_mod_loaded() { modprobe "$1" 2>/dev/null; lsmod 2>/dev/null | grep -q "^$1"; }

p53_hy_listen() { awk '/^listen:/ {print $2}' "$P53_HY_CFG" 2>/dev/null; }
p53_hy_set_listen() { [[ -f $P53_HY_CFG ]] && sed -i "s/^listen: .*/listen: :$1/" "$P53_HY_CFG"; }
p53_hy_obfs_now() { grep -q '^obfs:' "$P53_HY_CFG" 2>/dev/null; }

p53_hy_obfs_off() {
    [[ -f $P53_HY_CFG ]] && p53_hy_obfs_now || return 0
    local tmp; tmp=$(mktemp)
    awk -v tag="$P53_OBFS_TAG" '
        /^obfs:/                 { inblk=1; print tag $0; next }
        inblk && /^[^ \t#]/      { inblk=0 }
        inblk && /^[ \t]+[^ \t]/ { print tag $0; next }
        { print }
    ' "$P53_HY_CFG" > "$tmp" && cat "$tmp" > "$P53_HY_CFG"
    rm -f "$tmp"
}

p53_hy_obfs_on() {
    [[ -f $P53_HY_CFG ]] || return 0
    sed -i "s/^${P53_OBFS_TAG}//" "$P53_HY_CFG"
    sed -i 's/^#obfs:/obfs:/; s/^#  type: salamander/  type: salamander/; s/^#  salamander:/  salamander/; s/^#    password:/    password:/' "$P53_HY_CFG"
}

p53_mux_clear() {
    command -v iptables-legacy >/dev/null 2>&1 || return 0
    while iptables-legacy -t nat -D PREROUTING -p udp --dport 53 -j "$P53_CHAIN" 2>/dev/null; do :; done
    iptables-legacy -t nat -F "$P53_CHAIN" 2>/dev/null
    iptables-legacy -t nat -X "$P53_CHAIN" 2>/dev/null
}

p53_mux_apply() {
    local mode=$1
    p53_mux_clear
    [[ $mode == none || $mode == hysteria ]] && return 0
    
    modprobe xt_u32 2>/dev/null

    iptables-legacy -t nat -N "$P53_CHAIN" || return 1
    iptables-legacy -t nat -I PREROUTING 1 -p udp --dport 53 -j "$P53_CHAIN" || { p53_mux_clear; return 1; }

    if [[ $mode == slowdns ]]; then
        iptables-legacy -t nat -A "$P53_CHAIN" -p udp -j REDIRECT --to-ports "$P53_SLOWDNS_PORT"
    else
        iptables-legacy -t nat -A "$P53_CHAIN" -p udp -m u32 --u32 "0>>22&0x3C@2&0xFFFF=0x0100" -j REDIRECT --to-ports "$P53_SLOWDNS_PORT"
        case $mode in
            shared_hy)
                iptables-legacy -t nat -A "$P53_CHAIN" -p udp -j REDIRECT --to-ports "$P53_HY_PORT" ;;
            shared_udp)
                iptables-legacy -t nat -A "$P53_CHAIN" -p udp -j REDIRECT --to-ports "$P53_UDPC_PORT" ;;
            shared_all)
                iptables-legacy -t nat -A "$P53_CHAIN" -p udp -m u32 --u32 "0>>22&0x3C@8>>24&0xF0=0xC0 && 0>>22&0x3C@9=0x00000001" -j REDIRECT --to-ports "$P53_HY_PORT"
                iptables-legacy -t nat -A "$P53_CHAIN" -p udp -j REDIRECT --to-ports "$P53_UDPC_PORT" ;;
        esac
    fi
    netfilter-persistent save >/dev/null 2>&1
}

p53_finish() {
    echo "MODE=$1" > "$P53_STATE"
    if [[ $1 == hysteria || $1 == shared_hy || $1 == shared_all ]]; then
        echo "PORT=53" > "$P53_HY_TXT"
    else
        echo "PORT=$P53_HY_PORT" > "$P53_HY_TXT"
    fi
    systemctl is-active --quiet hysteria || echo -e "  ${RED}[!] Hysteria service issue detected.${NC}"
    echo -e "  ${GREEN}✓ Routing architecture '$1' successfully compiled.${NC}"
}

p53_set_mode() {
    local mode=$1 confirm
    p53_load_state
    
    case $mode in
        slowdns)
            p53_mux_clear
            p53_hy_obfs_on; p53_hy_set_listen "$P53_HY_PORT"
            systemctl restart hysteria dnstt
            p53_mux_apply slowdns
            p53_finish slowdns ;;
        hysteria)
            p53_mux_clear
            systemctl stop dnstt 2>/dev/null
            p53_hy_obfs_on; p53_hy_set_listen 53
            systemctl restart hysteria
            p53_finish hysteria ;;
        shared_hy|shared_udp)
            p53_mux_clear
            p53_hy_obfs_on; p53_hy_set_listen "$P53_HY_PORT"
            systemctl restart hysteria dnstt
            p53_mux_apply "$mode"
            p53_finish "$mode" ;;
        shared_all)
            echo -e "\n  ${YELLOW}[!] EXPERIMENTAL: Shared ALL disables Hysteria Obfuscation (Salamander)${NC}"
            read -rp "  Type YES to proceed: " confirm
            [[ $confirm == YES ]] || return 1
            p53_mux_clear
            p53_hy_obfs_off; p53_hy_set_listen "$P53_HY_PORT"
            systemctl restart hysteria dnstt
            p53_mux_apply shared_all
            p53_finish shared_all ;;
        reset)
            p53_mux_clear
            p53_hy_obfs_on; p53_hy_set_listen "$P53_HY_PORT"
            systemctl restart hysteria
            p53_finish none ;;
    esac
}

menu_port53() {
    local opt
    while true; do
        p53_load_state
        modprobe xt_u32 2>/dev/null
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
        printf "${CYAN}║ ${WHITE}AFTERLIFE VPN                                    ${YELLOW}%-17s${CYAN} ║\n${NC}" "${DOMAIN:-$(hostname)}"
        echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
        echo -e "${CYAN}║ ${YELLOW}› Advanced Routing › Port 53 Demultiplexer${CYAN}             ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
        echo -e "\n  ${WHITE}--- MULTIPLEXER ENGINE STATUS ---${NC}"
        echo -e "  Engine State : ${GREEN}${P53_MODE}${NC}"
        echo -e "  Tunnel NS    : ${YELLOW}${P53_NS:-Not Configured}${NC}"
        echo -e "  Hysteria     : bind ${YELLOW}$(p53_hy_listen)${NC} | obfs: $(p53_yn p53_hy_obfs_now)"
        echo -e "  xt_u32 module: $(p53_yn p53_mod_loaded xt_u32)\n"
        echo -e "  ${WHITE}[ CASCADING ROUTING MODES ]${NC}"
        echo -e "  ${GREEN}1)${NC} SlowDNS only    ${CYAN}- dnstt on 53, Hysteria on $P53_HY_PORT${NC}"
        echo -e "  ${GREEN}2)${NC} Hysteria only   ${CYAN}- Hysteria on 53, SlowDNS stopped${NC}"
        echo -e "  ${GREEN}3)${NC} Shared HY       ${CYAN}- dnstt + Hysteria on 53 ${YELLOW}(obfs ON)${NC}"
        echo -e "  ${GREEN}4)${NC} Shared UDP      ${CYAN}- dnstt + udp-custom on 53${NC}"
        echo -e "  ${GREEN}5)${NC} Shared ALL      ${CYAN}- dnstt + Hysteria + udp-custom on 53 ${RED}(obfs OFF)${NC}"
        echo -e "  ${CYAN}────────────────────────────────────────────────────────${NC}"
        echo -e "  ${GREEN}6)${NC} Reset Engine    ${CYAN}- drop mux rules, reset bindings${NC}"
        echo -e "  ${GREEN}7)${NC} View Raw Demux Counters (Traffic Split Verify)\n"
        echo -e "  ${RED}0)${NC} Back\n"
        read -rp "  Select mode [0-7]: " opt
        case $opt in
            1) echo; p53_set_mode slowdns;    read -rp "  Press enter..." ;;
            2) echo; p53_set_mode hysteria;   read -rp "  Press enter..." ;;
            3) echo; p53_set_mode shared_hy;  read -rp "  Press enter..." ;;
            4) echo; p53_set_mode shared_udp; read -rp "  Press enter..." ;;
            5) echo; p53_set_mode shared_all; read -rp "  Press enter..." ;;
            6) echo; p53_set_mode reset;      read -rp "  Press enter..." ;;
            7) clear; echo -e "${YELLOW}--- Traffic Split Counters ---${NC}\n"; iptables-legacy -t nat -L "$P53_CHAIN" -v -n --line-numbers 2>/dev/null || echo -e "  ${RED}MUX engine not running.${NC}"; echo; read -rp "  Press enter to return..." ;;
            0) break ;;
            *) ;;
        esac
    done
}

# ============================================================================
# SYSTEM SETTINGS & UTILS
# ============================================================================
menu_wireguard() { show_header "› WireGuard"; echo -e "  ${YELLOW}Coming Soon!${NC}\n"; read -p "  Press enter..."; }
menu_l2tp() { show_header "› L2TP / IPsec"; echo -e "  ${YELLOW}Coming Soon!${NC}\n"; read -p "  Press enter..."; }
menu_subscriptions() { show_header "› Subscriptions"; echo -e "  ${YELLOW}Coming Soon!${NC}\n"; read -p "  Press enter..."; }
menu_bbr() {
    show_header "› System › TCP BBR Status"
    local bbr_status=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}' 2>/dev/null)
    if [[ $bbr_status == "bbr" ]]; then
        echo -e "  ${GREEN}✓ TCP BBR is ENABLED${NC}"
    else
        echo -e "  ${RED}✗ TCP BBR is DISABLED${NC}"
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
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu\n"
        read -p "  Select option: " settings_option
        case $settings_option in
            1) journalctl --vacuum-time=1d; echo -e "\n  ${GREEN}✓ Logs cleared!${NC}\n"; read -p "  Press enter..." ;;
            2) journalctl -u hysteria -n 50 --no-pager; read -p "  Press enter..." ;;
            3) systemctl restart ws-ssh xray hysteria dropbear nginx dnstt 2>/dev/null; echo -e "\n  ${GREEN}✓ Services restarted!${NC}\n"; read -p "  Press enter..." ;;
            4) check_all_services ;;
            0) break ;;
        esac
    done
}
check_all_services() {
    show_header "› Settings › Service Status"
    for srv in ws-ssh xray hysteria dropbear nginx dnstt; do
        if systemctl is-active --quiet "$srv"; then
            echo -e "  ${GREEN}●${NC} $srv: ${GREEN}Running${NC}"
        else
            echo -e "  ${RED}○${NC} $srv: ${RED}Stopped${NC}"
        fi
    done
    echo ""
    read -p "  Press enter to continue..."
}
menu_backup() { show_header "› Backup"; echo -e "  ${YELLOW}Coming soon...${NC}\n"; read -p "  Press enter..."; }
menu_domain() {
    while true; do
        show_header "› Domain › Management"
        echo -e "  ${GREEN}1)${NC} Renew SSL Certificate"
        echo -e "  ${GREEN}2)${NC} Multi-Domain / Nameserver Manager"
        echo -e "  ${GREEN}3)${NC} View Certificate Info"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu\n"
        read -p "  Select option: " domain_option
        case $domain_option in
            1) systemctl stop nginx 2>/dev/null; ~/.acme.sh/acme.sh --renew -d "${DOMAIN}" --force; systemctl start nginx 2>/dev/null; read -p "  Press enter..." ;;
            2) [[ -f /usr/local/afterlifevpn/setup/add-host.sh ]] && bash /usr/local/afterlifevpn/setup/add-host.sh ;;
            3) [ -f /etc/afterlifevpn/cert/fullchain.crt ] && openssl x509 -in /etc/afterlifevpn/cert/fullchain.crt -noout -text | grep -E "Subject:|Issuer:|Not Before|Not After"; read -p "  Press enter..." ;;
            0) break ;;
        esac
    done
}

update_script() {
    show_header "› System › Update"
    echo -e "  ${YELLOW}Checking for updates from GitHub...${NC}\n"

    local REPO="https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main"
    local FILES=(
        "menu/menu.sh"
        "setup/slowdns.sh"
        "setup/add-host.sh"
        "setup/hysteria-user.sh"
        "setup/hysteria.sh"
        "setup/xray-user.sh"
        "setup/xray-add-vless.sh"
        "setup/xray-add-trojan.sh"
    )

    local TMP_DIR="/tmp/afterlife_update"
    mkdir -p "$TMP_DIR/menu" "$TMP_DIR/setup"
    local HAS_ERROR=0

    for file in "${FILES[@]}"; do
        echo -en "  ${WHITE}Checking ${file}... ${NC}"
        if curl -f -sL "$REPO/$file" -o "$TMP_DIR/$file"; then
            if [[ -s "$TMP_DIR/$file" ]]; then
                echo -e "${GREEN}OK${NC}"
            else
                echo -e "${RED}Failed (Empty File)${NC}"
                HAS_ERROR=1
            fi
        else
            echo -e "${RED}Failed (Not Found on GitHub)${NC}"
            HAS_ERROR=1
        fi
    done

    echo -e "\n  ${CYAN}──────────────────────────────────────────────────────${NC}"

    if [[ $HAS_ERROR -eq 0 ]]; then
        echo -e "  ${YELLOW}Applying updates to system...${NC}"
        cp -f "$TMP_DIR"/menu/* /usr/local/afterlifevpn/menu/ 2>/dev/null
        cp -f "$TMP_DIR"/setup/* /usr/local/afterlifevpn/setup/ 2>/dev/null
        chmod +x /usr/local/afterlifevpn/menu/*.sh /usr/local/afterlifevpn/setup/*.sh
        echo -e "\n  ${GREEN}✓ Script now in latest version!${NC}\n"
    else
        echo -e "  ${RED}✗ Update aborted. Some files were missing on GitHub.${NC}"
        echo -e "  ${WHITE}Your current server files were not modified.${NC}\n"
    fi

    rm -rf "$TMP_DIR"
    read -p "  Press enter to restart menu..."
    exec /usr/local/afterlifevpn/menu/menu.sh "$@"
}

full_diagnostics() {
    clear
    get_system_info
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${PURPLE}AFTERLIFE VPN Diagnostics                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    for srv in nginx xray dropbear hysteria dnstt udp-custom; do
        if systemctl is-active --quiet "$srv" 2>/dev/null; then
            echo -e "  ${GREEN}[PASS]${NC} $srv is running"
        else
            echo -e "  ${RED}[FAIL]${NC} $srv is stopped"
        fi
    done
    echo ""
    read -p "  Press [Enter] to continue..."
}

case "$1" in
    --restore-p53)      p53_set_mode "$(p53_kv "$P53_STATE" MODE)"; exit 0 ;;
esac

while true; do
    show_dashboard
    read -p "  Select Option [1-11 / U / V / X]: " option
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
        11) menu_port53 ;;
        U|u) update_script ;;
        V|v) full_diagnostics ;;
        X|x) clear; echo -e "${CYAN}Thank you for using AFTERLIFE VPN!${NC}"; exit 0 ;;
        *) ;;
    esac
done
