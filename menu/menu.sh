#!/bin/bash
# Enforce Root Privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31mError: This script must be run as root.\033[0m"
    exit 1
fi
# Exit instead of spinning when the terminal disappears (prompt read gets EOF/EIO)
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
    echo -e "${CYAN}│${NC}  ${GREEN}11)${NC} Port 53 Toggle (SlowDNS / Hysteria)                 ${CYAN}│${NC}"
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
    local username password days devices quota exp_date SERVER_HOST WS_PORT IP
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
    SERVER_HOST="$DOMAIN"
    if [[ -z "$SERVER_HOST" ]]; then
        SERVER_HOST=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "N/A")
    fi
    WS_PORT=$(cat /usr/local/afterlifevpn/ws-port.conf 2>/dev/null || echo 443)
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
    echo -e "   WS Ports    : ${YELLOW}80 / $WS_PORT${NC}"
    echo -e "   SSL Ports   : ${YELLOW}443 / 777${NC}"
    echo -e "   UDP-Custom  : ${YELLOW}port 36712 (same login)${NC}"
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
    if [[ -z "$new_port" ]]; then
        echo -e "\n  ${YELLOW}No change made.${NC}"
        read -p "  Press enter to continue..."
        return
    fi
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "\n  ${RED}✗ Invalid port! Please use a number between 1024 and 65535.${NC}"
        read -p "  Press enter to continue..."
        return
    fi
    if ss -tuln | grep -q ":$new_port "; then
        echo -e "\n  ${RED}✗ Port $new_port is already in use!${NC}"
        read -p "  Press enter to continue..."
        return
    fi
    sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=$new_port/" /etc/default/dropbear
    sed -i "s/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=\"-p $new_port\"/" /etc/default/dropbear
    grep -q "^DROPBEAR_PORT=" /etc/default/dropbear || echo "DROPBEAR_PORT=$new_port" >> /etc/default/dropbear
    grep -q "^DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear || echo "DROPBEAR_EXTRA_ARGS=\"-p $new_port\"" >> /etc/default/dropbear
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow ${new_port}/tcp >/dev/null 2>&1
        echo -e "  ${GREEN}✓ Firewall (ufw) updated${NC}"
    else
        iptables -I INPUT -p tcp --dport $new_port -j ACCEPT 2>/dev/null
        netfilter-persistent save >/dev/null 2>&1 || true
        echo -e "  ${GREEN}✓ Firewall (iptables) updated${NC}"
    fi
    systemctl restart dropbear
    sleep 1
    if systemctl is-active --quiet dropbear; then
        echo -e "\n  ${GREEN}✓ Dropbear port successfully changed to $new_port${NC}"
        echo -e "  ${WHITE}Old port:${NC} $current_port → ${WHITE}New port:${NC} $new_port"
    else
        echo -e "\n  ${RED}✗ Failed to restart Dropbear. Please check the service.${NC}"
    fi
    echo ""
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
    echo -e "  ${YELLOW}⚠ Make sure nginx is proxying to the new port if needed.${NC}\n"
    read -p "  Press enter to continue..."
}
monitor_connections() {
    show_header "› SSH › Active Connections"
    echo -e "  ${YELLOW}SSH Connections:${NC}"
    local ssh_count=$(ss -tnp 2>/dev/null | grep ':22' | grep ESTAB | wc -l)
    echo -e "  Total: $ssh_count"
    ss -tnp 2>/dev/null | grep ':22' | grep ESTAB | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr | head -10
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
    if grep -qE "^${username}[:|]" /usr/local/afterlifevpn/users/xray_users.txt 2>/dev/null; then
        echo -e "\n  ${RED}✗ User already exists!${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    local XRAY_OUT UUID
    XRAY_OUT=$(bash /usr/local/afterlifevpn/setup/xray-user.sh add "$username" "$days" 2>&1)
    UUID=$(grep -oEi '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<< "$XRAY_OUT" | head -n 1)
    if [[ -z "$UUID" ]]; then
        echo -e "\n  ${RED}✗ Could not create the account. Output from xray-user.sh:${NC}\n"
        echo "$XRAY_OUT"
        echo ""
        read -p "  Press enter to continue..."
        return
    fi
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
    if ! grep -qE "^${username}[:|]" /usr/local/afterlifevpn/users/xray_users.txt 2>/dev/null; then
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
        echo -e ""
        echo -e "    ${GREEN}1)${NC}  Manage Users (Add / Delete / List / Links)"
        echo -e "    ${GREEN}2)${NC}  Reinstall / Change Mode (Single / Port 53 + Salamander)"
        echo -e "    ${GREEN}3)${NC}  Service Status"
        echo -e "    ${GREEN}4)${NC}  Restart Hysteria"
        echo -e ""
        echo -e "  ${RED}X${NC} Back  · ${WHITE}$SERVER_HOST${NC}"
        echo -e ""
        read -p "  Select [1-4]: " sub_opt
        case $sub_opt in
            1) bash /usr/local/afterlifevpn/setup/hysteria-user.sh ;;
            2) bash /usr/local/afterlifevpn/setup/hysteria.sh ;;
            3)
                clear
                echo -e "\n  ${YELLOW}Hysteria Status:${NC}"
                systemctl status hysteria --no-pager -l
                echo ""
                read -p "  Press [Enter] to return..."
                ;;
            4)
                systemctl restart hysteria
                echo -e "\n  ${GREEN}✓ Hysteria restarted${NC}"
                sleep 1.5
                ;;
            X|x|0) break ;;
            *) continue ;;
        esac
    done
}
# ============================================================================
# PORT 53 MULTIPLEXER (SlowDNS / Hysteria / UDP-Custom)
#
# One iptables chain (AFTERLIFE_MUX) sits in nat/PREROUTING for UDP/53 and
# sorts each new flow by its first packet (conntrack carries the rest):
#   1. query whose name ends in the tunnel NS host  -> dnstt     (5300)
#   2. QUIC v1 Initial packet  (shared_all only)    -> Hysteria  (443)
#   3. anything else                                -> Hysteria (shared_hy) or udp-custom (7300)
# The chosen mode is saved in port53-mode.conf and re-applied at boot by
# afterlife-p53.service, which runs:  menu.sh --restore-p53
# ============================================================================
P53_BASE=/usr/local/afterlifevpn
P53_HY_CFG=/etc/hysteria/config.yaml
P53_HY_TXT=$P53_BASE/hysteria-config.txt
P53_STATE=$P53_BASE/port53-mode.conf
P53_NS_FILE=$P53_BASE/nameserver.conf
P53_CHAIN=AFTERLIFE_MUX
P53_SLOWDNS_PORT=5300
P53_UDPC_PORT=7300
P53_HY_PORT=443
P53_OBFS_TAG='#AFTERLIFE-OBFS# '
P53_UNIT=/etc/systemd/system/afterlife-p53.service

p53_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | tail -n1 | tr -d "\"'"; }

p53_load_state() {
    P53_MODE=$(p53_kv "$P53_STATE" MODE); P53_MODE=${P53_MODE:-none}
    P53_NS=$(p53_kv "$P53_NS_FILE" NS_HOST)
}

p53_udp_listening() { ss -uln 2>/dev/null | awk -v p=":$1" '$4 ~ p"$" {f=1} END{exit !f}'; }
p53_yn() { if "$@" >/dev/null 2>&1; then echo -e "${GREEN}yes${NC}"; else echo -e "${RED}no${NC}"; fi; }
p53_mod_loaded() { modprobe "$1" 2>/dev/null; lsmod 2>/dev/null | grep -q "^$1"; }

# "ns1.example.com" -> "03 6e 73 31 07 65 78 61 6d 70 6c 65 03 63 6f 6d 00"
# DNS packets carry length-prefixed labels, never dots, so a plain-text match on a hostname can never hit.
p53_dns_hex() {
    local host=${1%.} out="" label
    host=${host,,}
    local IFS='.'
    local -a labels
    read -ra labels <<< "$host"
    for label in "${labels[@]}"; do
        out+=$(printf '%02x' "${#label}")
        out+=$(printf '%s' "$label" | od -An -tx1 | tr -d ' \n')
    done
    out+="00"
    echo "$out" | sed 's/../& /g; s/ $//'
}

p53_hy_listen() { awk '/^listen:/ {print $2}' "$P53_HY_CFG" 2>/dev/null; }
p53_hy_set_listen() { [[ -f $P53_HY_CFG ]] && sed -i "s/^listen: .*/listen: :$1/" "$P53_HY_CFG"; }
p53_hy_obfs_now() { grep -q '^obfs:' "$P53_HY_CFG" 2>/dev/null; }

# Comment out / restore only the "obfs:" block, tagged with a unique marker.
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
    # legacy format from the previous toggle
    sed -i 's/^#obfs:/obfs:/; s/^#  type: salamander/  type: salamander/; s/^#  salamander:/  salamander:/; s/^#    password:/    password:/' "$P53_HY_CFG"
}

p53_ensure_iptables() {
    command -v iptables >/dev/null 2>&1 && return 0
    echo -e "  ${YELLOW}[*] Installing iptables...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables >/dev/null 2>&1
    command -v iptables >/dev/null 2>&1 || { echo -e "  ${RED}[!] Could not install iptables.${NC}"; return 1; }
}

p53_mux_clear() {
    command -v iptables >/dev/null 2>&1 || return 0
    p53_hop_clear
    while iptables -t nat -D PREROUTING -p udp --dport 53 -j "$P53_CHAIN" 2>/dev/null; do :; done
    iptables -t nat -F "$P53_CHAIN" 2>/dev/null
    iptables -t nat -X "$P53_CHAIN" 2>/dev/null
    while iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports "$P53_SLOWDNS_PORT" 2>/dev/null; do :; done
}

# Optional Hysteria port hopping. Only applied in shared_hy, and only when $P53_HOP_FLAG exists.
# 36712 (udp-custom) lies inside 20000-40000, so it is excluded.
P53_HOP_FLAG=$P53_BASE/port-hop.enabled
P53_HOP_CHAIN=AFTERLIFE_HOP
p53_hop_clear() {
    command -v iptables >/dev/null 2>&1 || return 0
    while iptables -t nat -D PREROUTING -p udp -j "$P53_HOP_CHAIN" 2>/dev/null; do :; done
    iptables -t nat -F "$P53_HOP_CHAIN" 2>/dev/null
    iptables -t nat -X "$P53_HOP_CHAIN" 2>/dev/null
}
p53_hop_apply() {
    p53_hop_clear
    [[ -f $P53_HOP_FLAG ]] || return 0
    iptables -t nat -N "$P53_HOP_CHAIN" || return 1
    iptables -t nat -A "$P53_HOP_CHAIN" -p udp --dport 20000:36711 -j REDIRECT --to-ports "$P53_HY_PORT"
    iptables -t nat -A "$P53_HOP_CHAIN" -p udp --dport 36713:40000 -j REDIRECT --to-ports "$P53_HY_PORT"
    iptables -t nat -I PREROUTING 1 -p udp -m multiport --dports 20000:40000 -j "$P53_HOP_CHAIN" || { p53_hop_clear; return 1; }
}

# REDIRECT changes the destination port before the INPUT filter, so the target ports must be allowed.
p53_fw_open() {
    local p
    for p in "$@"; do
        if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw allow "${p}/udp" >/dev/null 2>&1
        elif iptables -S INPUT 2>/dev/null | head -n1 | grep -q 'DROP'; then
            iptables -C INPUT -p udp --dport "$p" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$p" -j ACCEPT
        fi
    done
}

p53_mux_apply() {
    local mode=$1 hex
    p53_mux_clear
    [[ $mode == none || $mode == hysteria ]] && return 0
    p53_ensure_iptables || return 1
    modprobe xt_string 2>/dev/null; modprobe xt_u32 2>/dev/null

    iptables -t nat -N "$P53_CHAIN" || return 1
    iptables -t nat -I PREROUTING 1 -p udp --dport 53 -j "$P53_CHAIN" || { p53_mux_clear; return 1; }

    if [[ $mode == slowdns ]]; then
        iptables -t nat -A "$P53_CHAIN" -p udp -j REDIRECT --to-ports "$P53_SLOWDNS_PORT" || { p53_mux_clear; return 1; }
        p53_fw_open "$P53_SLOWDNS_PORT"
        return 0
    fi

    hex=$(p53_dns_hex "$P53_NS")
    iptables -t nat -A "$P53_CHAIN" -p udp -m string --algo bm --icase --hex-string "|$hex|" -j REDIRECT --to-ports "$P53_SLOWDNS_PORT" 2>/dev/null \
      || iptables -t nat -A "$P53_CHAIN" -p udp -m string --algo bm --hex-string "|$hex|" -j REDIRECT --to-ports "$P53_SLOWDNS_PORT" \
      || { p53_mux_clear; return 1; }

    case $mode in
        shared_hy)
            iptables -t nat -A "$P53_CHAIN" -p udp -j REDIRECT --to-ports "$P53_HY_PORT" || { p53_mux_clear; return 1; }
            p53_fw_open "$P53_SLOWDNS_PORT" "$P53_HY_PORT"
            p53_hop_apply ;;
        shared_udp)
            iptables -t nat -A "$P53_CHAIN" -p udp -j REDIRECT --to-ports "$P53_UDPC_PORT" || { p53_mux_clear; return 1; }
            p53_fw_open "$P53_SLOWDNS_PORT" "$P53_UDPC_PORT" ;;
        shared_all)
            iptables -t nat -A "$P53_CHAIN" -p udp \
                -m u32 --u32 "0>>22&0x3C@8>>24&0xF0=0xC0 && 0>>22&0x3C@9=0x00000001" \
                -j REDIRECT --to-ports "$P53_HY_PORT" || { p53_mux_clear; return 1; }
            iptables -t nat -A "$P53_CHAIN" -p udp -j REDIRECT --to-ports "$P53_UDPC_PORT" || { p53_mux_clear; return 1; }
            p53_fw_open "$P53_SLOWDNS_PORT" "$P53_HY_PORT" "$P53_UDPC_PORT" ;;
    esac
}

p53_install_unit() {
    local tmp; tmp=$(mktemp)
    cat > "$tmp" <<EOF
[Unit]
Description=AFTERLIFE UDP/53 multiplexer rules
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash $P53_BASE/menu/menu.sh --restore-p53

[Install]
WantedBy=multi-user.target
EOF
    if ! cmp -s "$tmp" "$P53_UNIT"; then
        cp "$tmp" "$P53_UNIT"
        systemctl daemon-reload
    fi
    rm -f "$tmp"
    systemctl enable afterlife-p53.service >/dev/null 2>&1
}

# Called at boot by afterlife-p53.service (no UI)
p53_restore() {
    p53_load_state
    case $P53_MODE in
        slowdns|shared_hy|shared_udp|shared_all) p53_mux_apply "$P53_MODE" ;;
        *) p53_mux_clear ;;
    esac
}

# --- prerequisites: fix automatically where possible, otherwise explain exactly what is missing
p53_need_ns() {
    p53_load_state
    [[ -x /usr/local/bin/dnstt-server && -n $P53_NS ]] && return 0
    echo -e "  ${YELLOW}[!] SlowDNS (dnstt + tunnel nameserver) is not set up yet.${NC}"
    if [[ -f $P53_BASE/setup/slowdns.sh ]]; then
        read -rp "  Run the SlowDNS installer now? [Y/n]: " ans
        if [[ ! $ans =~ ^[Nn] ]]; then
            bash "$P53_BASE/setup/slowdns.sh"
            p53_load_state
        fi
    else
        echo -e "  ${RED}slowdns.sh is missing - run Update (U) from the main menu first.${NC}"
    fi
    [[ -x /usr/local/bin/dnstt-server && -n $P53_NS ]] && return 0
    echo -e "  ${RED}[!] SlowDNS still not ready (dnstt-server / NS_HOST in nameserver.conf).${NC}"
    return 1
}
p53_need_udpc() {
    p53_udp_listening "$P53_UDPC_PORT" && return 0
    echo -e "  ${RED}[!] udp-custom is not listening on UDP $P53_UDPC_PORT - start/install it first.${NC}"
    return 1
}
p53_need_mod() {
    p53_mod_loaded "$1" && return 0
    echo -e "  ${RED}[!] Kernel module $1 is not available on this server (some VPS/OpenVZ kernels lack it).${NC}"
    return 1
}
p53_need_hy() {
    [[ -f $P53_HY_CFG ]] && return 0
    echo -e "  ${RED}[!] Hysteria is not installed ($P53_HY_CFG missing) - use main menu option 3 first.${NC}"
    return 1
}

p53_finish() {  # <mode> <hysteria PORT value> <obfs changed 0/1>
    echo "MODE=$1" > "$P53_STATE"
    echo "PORT=$2" > "$P53_HY_TXT"
    p53_install_unit
    systemctl is-active --quiet hysteria || \
        echo -e "  ${RED}[!] Hysteria is not running - see: journalctl -u hysteria -n 30${NC}"
    echo -e "  ${GREEN}✓ Mode $1 active.${NC}"
    [[ $3 == 1 ]] && echo -e "  ${YELLOW}Hysteria obfs state changed - re-issue Hysteria links (Hysteria 2 > Manage Users).${NC}"
}

p53_set_mode() {
    local mode=$1 was_obfs=0 changed=0 holder confirm
    p53_load_state
    p53_ensure_iptables || return 1
    p53_hy_obfs_now && was_obfs=1

    case $mode in
        slowdns)
            p53_need_hy && p53_need_ns || return 1
            p53_mux_clear
            p53_hy_obfs_on; p53_hy_set_listen "$P53_HY_PORT"
            systemctl restart hysteria dnstt
            p53_mux_apply slowdns || { echo -e "  ${RED}iptables failed.${NC}"; return 1; }
            [[ $was_obfs == 0 ]] && changed=1
            p53_finish slowdns "$P53_HY_PORT" $changed
            echo -e "    SlowDNS clients : UDP 53 -> dnstt"
            echo -e "    Hysteria        : port $P53_HY_PORT (own port)" ;;
        hysteria)
            p53_need_hy || return 1
            p53_mux_clear
            systemctl stop dnstt 2>/dev/null
            systemctl stop hysteria 2>/dev/null
            holder=$(ss -ulnp 2>/dev/null | awk '$4 ~ /:53$/')
            if [[ -n $holder ]]; then
                echo -e "  ${RED}[!] Something else already owns UDP 53:${NC}\n$holder"
                if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
                    read -rp "  systemd-resolved is running. Disable its port-53 stub listener now? [Y/n]: " ans
                    if [[ ! $ans =~ ^[Nn] ]]; then
                        mkdir -p /etc/systemd/resolved.conf.d
                        printf '[Resolve]\nDNSStubListener=no\n' > /etc/systemd/resolved.conf.d/afterlife.conf
                        [[ -L /etc/resolv.conf ]] && ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
                        systemctl restart systemd-resolved
                        sleep 1
                        holder=$(ss -ulnp 2>/dev/null | awk '$4 ~ /:53$/')
                    fi
                fi
            fi
            if [[ -n $holder ]]; then
                echo -e "  ${RED}[!] UDP 53 is still busy - aborting.${NC}"
                p53_hy_set_listen "$P53_HY_PORT"; systemctl start hysteria
                return 1
            fi
            p53_hy_obfs_on; p53_hy_set_listen 53
            systemctl start hysteria
            [[ $was_obfs == 0 ]] && changed=1
            p53_finish hysteria 53 $changed
            echo -e "    Hysteria        : UDP 53 (native), SlowDNS stopped" ;;
        shared_hy|shared_udp)
            p53_need_hy && p53_need_ns && p53_need_mod xt_string || return 1
            [[ $mode == shared_udp ]] && { p53_need_udpc || return 1; }
            p53_mux_clear
            p53_hy_obfs_on; p53_hy_set_listen "$P53_HY_PORT"
            systemctl restart hysteria dnstt
            p53_mux_apply "$mode" || { echo -e "  ${RED}iptables failed.${NC}"; return 1; }
            [[ $was_obfs == 0 ]] && changed=1
            p53_finish "$mode" "$P53_HY_PORT" $changed
            echo -e "    SlowDNS clients : UDP 53 (query ends in $P53_NS) -> dnstt"
            if [[ $mode == shared_hy ]]; then
                echo -e "    Everything else : UDP 53 -> Hysteria ($P53_HY_PORT, obfs ON)"
            else
                echo -e "    Everything else : UDP 53 -> udp-custom ($P53_UDPC_PORT)"
                echo -e "    Hysteria        : port $P53_HY_PORT (own port)"
            fi ;;
        shared_all)
            p53_need_hy && p53_need_ns && p53_need_mod xt_string && p53_need_mod xt_u32 && p53_need_udpc || return 1
            echo -e "\n  ${YELLOW}[!] Shared ALL DISABLES Hysteria's salamander obfs.${NC}"
            echo -e "  - Existing Hysteria links stop working until re-issued."
            echo -e "  - Hysteria becomes plain QUIC on the wire (DPI can see it)."
            echo -e "  - Mode 4 (Shared UDP) keeps obfs and needs no re-issuing."
            read -rp "  Type YES to continue: " confirm
            [[ $confirm == YES ]] || { echo -e "  ${RED}Aborted.${NC}"; return 1; }
            p53_mux_clear
            p53_hy_obfs_off; p53_hy_set_listen "$P53_HY_PORT"
            systemctl restart hysteria dnstt
            p53_mux_apply shared_all || { echo -e "  ${RED}iptables failed.${NC}"; return 1; }
            [[ $was_obfs == 1 ]] && changed=1
            p53_finish shared_all "$P53_HY_PORT" $changed
            echo -e "    SlowDNS clients : UDP 53 (query ends in $P53_NS) -> dnstt"
            echo -e "    Hysteria clients: UDP 53 (QUIC v1 Initial) -> $P53_HY_PORT, obfs ${RED}OFF${NC}"
            echo -e "    udp-custom      : UDP 53 (anything else) -> $P53_UDPC_PORT" ;;
        reset)
            p53_mux_clear
            systemctl stop dnstt 2>/dev/null
            p53_hy_obfs_on; p53_hy_set_listen "$P53_HY_PORT"
            [[ -f $P53_HY_CFG ]] && systemctl restart hysteria
            [[ $was_obfs == 0 ]] && changed=1
            p53_finish none "$P53_HY_PORT" $changed
            echo -e "    UDP 53 is free; Hysteria on $P53_HY_PORT." ;;
    esac
}

p53_verify() {
    clear
    echo -e "${YELLOW}--- $P53_CHAIN packet counters ---${NC}\n"
    if iptables -t nat -L "$P53_CHAIN" -v -n --line-numbers 2>/dev/null; then
        echo -e "\n  Counters tick only on the FIRST packet of each flow (conntrack handles the rest)."
        echo -e "  Connect one client type at a time and watch which rule's 'pkts' climbs:"
        echo -e "   rule 1 = SlowDNS, QUIC rule (mode 5) = Hysteria, last rule = udp-custom / Hysteria."
    else
        echo -e "  ${RED}MUX chain not active (mode none/hysteria, or rules were lost).${NC}"
    fi
    echo
    read -rp "  Press enter to return..."
}

menu_port53() {
    local opt
    while true; do
        p53_load_state
        modprobe xt_u32 2>/dev/null; modprobe xt_string 2>/dev/null
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
        printf "${CYAN}║ ${WHITE}AFTERLIFE VPN                                    ${YELLOW}%-17s${CYAN} ║\n${NC}" "${DOMAIN:-$(hostname)}"
        echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
        echo -e "${CYAN}║ ${YELLOW}› Main › Port 53 Toggle${CYAN}                                ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
        echo -e "\n  ${WHITE}--- PORT 53 MODE (SLOWDNS / HYSTERIA / UDP-CUSTOM) ---${NC}"
        echo -e "  Current mode : ${GREEN}${P53_MODE}${NC}"
        echo -e "  Tunnel NS    : ${YELLOW}${P53_NS:-Not Configured}${NC}"
        echo -e "  Hysteria     : listen ${YELLOW}$(p53_hy_listen)${NC} | obfs: $(p53_yn p53_hy_obfs_now)"
        echo -e "  dnstt: $(p53_yn systemctl is-active --quiet dnstt)   udp-custom: $(p53_yn p53_udp_listening $P53_UDPC_PORT)   xt_string: $(p53_yn p53_mod_loaded xt_string)   xt_u32: $(p53_yn p53_mod_loaded xt_u32)\n"
        echo -e "  ${GREEN}1)${NC} SlowDNS only    ${CYAN}- UDP/53 -> dnstt, Hysteria on :$P53_HY_PORT${NC}"
        echo -e "  ${GREEN}2)${NC} Hysteria only   ${CYAN}- Hysteria binds :53, SlowDNS stopped${NC}"
        echo -e "  ${GREEN}3)${NC} Shared HY       ${CYAN}- DNS -> dnstt, rest -> Hysteria (obfs ON)${NC}"
        echo -e "  ${GREEN}4)${NC} Shared UDP      ${CYAN}- DNS -> dnstt, rest -> udp-custom :$P53_UDPC_PORT${NC}"
        echo -e "  ${GREEN}5)${NC} Shared ALL      ${CYAN}- DNS / QUIC / rest split ${YELLOW}(obfs OFF)${NC}"
        echo -e "  ${GREEN}6)${NC} Reset           ${CYAN}- drop mux, Hysteria back to :$P53_HY_PORT${NC}"
        echo -e "  ${GREEN}7)${NC} Install / Configure SlowDNS"
        echo -e "  ${GREEN}8)${NC} Verify split    ${CYAN}- show $P53_CHAIN counters${NC}\n"
        echo -e "  ${CYAN}3/4/5 need SlowDNS. 4/5 need udp-custom. 5 needs xt_u32.${NC}"
        echo -e "  ${CYAN}Switching to 1/2/3/4/6 turns obfs back ON.${NC}\n"
        echo -e "  ${RED}0)${NC} Back\n"
        read -rp "  Select mode [0-8]: " opt
        case $opt in
            1) echo; p53_set_mode slowdns;    read -rp "  Press enter to continue..." ;;
            2) echo; p53_set_mode hysteria;   read -rp "  Press enter to continue..." ;;
            3) echo; p53_set_mode shared_hy;  read -rp "  Press enter to continue..." ;;
            4) echo; p53_set_mode shared_udp; read -rp "  Press enter to continue..." ;;
            5) echo; p53_set_mode shared_all; read -rp "  Press enter to continue..." ;;
            6) echo; p53_set_mode reset;      read -rp "  Press enter to continue..." ;;
            7)
                if [[ -f $P53_BASE/setup/slowdns.sh ]]; then
                    bash "$P53_BASE/setup/slowdns.sh"
                else
                    echo -e "  ${RED}✗ slowdns.sh missing. Run Update (U) from the main menu first.${NC}"
                    sleep 2
                fi ;;
            8) p53_verify ;;
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
    echo -e "  ${GREEN}1)${NC} SSH WebSocket\n  ${GREEN}2)${NC} Xray\n  ${GREEN}3)${NC} Hysteria 2\n  ${GREEN}4)${NC} Dropbear\n"
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
    systemctl restart ws-ssh xray hysteria dropbear nginx 2>/dev/null
    # nginx/hysteria restarts do not touch iptables, but re-assert the port 53 rules anyway
    p53_restore 2>/dev/null
    echo -e "\n  ${GREEN}✓ All services restarted!${NC}\n"
    read -p "  Press enter to continue..."
}
check_all_services() {
    show_header "› Settings › Service Status"
    local services=("ws-ssh" "xray" "hysteria" "dropbear" "nginx")
    local names=("SSH WebSocket" "Xray" "Hysteria 2" "Dropbear" "Nginx")
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
# ============================================================================
# DOMAIN MANAGEMENT
# ============================================================================
run_add_host() {
    if [ -f /usr/local/afterlifevpn/setup/add-host.sh ]; then
        bash /usr/local/afterlifevpn/setup/add-host.sh
    else
        echo -e "  ${RED}Missing file:${NC} /usr/local/afterlifevpn/setup/add-host.sh"
        echo "  Push setup/add-host.sh to GitHub, then run menu option U."
        read -p "  Press enter..."
    fi
}
menu_domain() {
    while true; do
        show_header "› Domain › Management"
        echo -e "  ${GREEN}1)${NC} Renew SSL Certificate"
        echo -e "  ${GREEN}2)${NC} Multi-Domain / Nameserver Manager"
        echo -e "  ${GREEN}3)${NC} View Certificate Info"
        echo -e "  ${YELLOW}0)${NC} Back to Main Menu\n"
        read -p "  Select option: " domain_option
        case $domain_option in
            1) renew_certificate ;;
            2) run_add_host ;;
            3) view_certificate ;;
            0) break ;;
            *) ;;
        esac
    done
}
renew_certificate() {
    show_header "› Domain › Renew Certificate"
    if [ ! -f /usr/local/afterlifevpn/config.conf ]; then
        echo -e "  ${RED}config.conf not found${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    source /usr/local/afterlifevpn/config.conf
    if [ -z "$DOMAIN" ]; then
        echo -e "  ${RED}DOMAIN is empty in config.conf${NC}\n"
        read -p "  Press enter to continue..."
        return
    fi
    echo -e "  ${YELLOW}Renewing SSL certificate for: $DOMAIN${NC}"
    systemctl stop nginx 2>/dev/null
    ~/.acme.sh/acme.sh --renew -d "$DOMAIN" --force
    systemctl start nginx 2>/dev/null
    systemctl restart ws-ssh xray hysteria nginx 2>/dev/null
    echo -e "\n  ${GREEN}✓ Certificate renew command finished!${NC}\n"
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
    if [ -f /usr/local/afterlifevpn/nameserver.conf ]; then
        echo -e "  ${WHITE}Nameserver:${NC}"
        cat /usr/local/afterlifevpn/nameserver.conf
    else
        echo -e "  ${YELLOW}No nameserver configured yet.${NC}"
    fi
    echo ""
    read -p "  Press enter to continue..."
}
update_script() {
    show_header "› System › Update"
    echo -e "  ${YELLOW}Checking for updates from GitHub...${NC}\n"
    local REPO_URL="https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main"
    local SUCCESS=true
    mkdir -p /tmp/afterlife-update
    echo -e "  ${WHITE}Pulling menu system...${NC}"
    wget -q -O /tmp/afterlife-update/menu.sh "$REPO_URL/menu/menu.sh" || SUCCESS=false
    echo -e "  ${WHITE}Pulling setup & user scripts...${NC}"
    wget -q -O /tmp/afterlife-update/xray-user.sh "$REPO_URL/setup/xray-user.sh" || SUCCESS=false
    wget -q -O /tmp/afterlife-update/hysteria-user.sh "$REPO_URL/setup/hysteria-user.sh" || SUCCESS=false
    wget -q -O /tmp/afterlife-update/hysteria.sh "$REPO_URL/setup/hysteria.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/ssh-ws.sh "$REPO_URL/setup/ssh-ws.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/add-host.sh "$REPO_URL/setup/add-host.sh" || SUCCESS=false
    wget -q -O /tmp/afterlife-update/xray-add-vless.sh "$REPO_URL/setup/xray-add-vless.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/xray-add-trojan.sh "$REPO_URL/setup/xray-add-trojan.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/xray-online.sh "$REPO_URL/setup/xray-online.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/xray-renew.sh "$REPO_URL/setup/xray-renew.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/xray-del.sh "$REPO_URL/setup/xray-del.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/user-expire.sh "$REPO_URL/setup/user-expire.sh" 2>/dev/null
    wget -q -O /tmp/afterlife-update/slowdns.sh "$REPO_URL/setup/slowdns.sh" 2>/dev/null
    if [ "$SUCCESS" = true ]; then
        # copy to a new file then rename, so the running menu is not overwritten in place
        cp /tmp/afterlife-update/menu.sh /usr/local/afterlifevpn/menu/menu.sh.new
        mv -f /usr/local/afterlifevpn/menu/menu.sh.new /usr/local/afterlifevpn/menu/menu.sh
        cp /tmp/afterlife-update/xray-user.sh /usr/local/afterlifevpn/setup/xray-user.sh
        cp /tmp/afterlife-update/hysteria-user.sh /usr/local/afterlifevpn/setup/hysteria-user.sh
        cp /tmp/afterlife-update/hysteria.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/ssh-ws.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/add-host.sh /usr/local/afterlifevpn/setup/add-host.sh
        cp /tmp/afterlife-update/xray-add-vless.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/xray-add-trojan.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/xray-online.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/xray-renew.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/xray-del.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/user-expire.sh /usr/local/afterlifevpn/setup/ 2>/dev/null
        cp /tmp/afterlife-update/slowdns.sh /usr/local/afterlifevpn/setup/slowdns.sh 2>/dev/null
        chmod +x /usr/local/afterlifevpn/menu/menu.sh
        chmod +x /usr/local/afterlifevpn/setup/*.sh
        ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/menu
        ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/afterlife
        rm -rf /tmp/afterlife-update
        # keep the port 53 boot service pointing at the new menu.sh
        if [[ -f /usr/local/afterlifevpn/port53-mode.conf ]]; then
            bash /usr/local/afterlifevpn/menu/menu.sh --install-p53-unit 2>/dev/null
        fi
        echo -e "\n  ${GREEN}✓ All AFTERLIFE scripts updated successfully!${NC}"
        echo -e "  ${YELLOW}⚠ Type 'menu' or 'afterlife' to launch.${NC}"
    else
        echo -e "\n  ${RED}✗ Update failed! Could not reach GitHub or critical files are missing.${NC}"
        echo -e "  ${YELLOW}Make sure these exist on GitHub:${NC}"
        echo "  menu/menu.sh"
        echo "  setup/add-host.sh"
        echo "  setup/hysteria.sh"
        echo "  setup/hysteria-user.sh"
        echo "  setup/slowdns.sh"
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
    for srv in nginx xray dropbear ssh ws-ssh badvpn hysteria squid danted dnstt; do
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
    fi
    if [ -f /etc/hysteria/config.yaml ]; then print_check "PASS" "hysteria config"; else print_check "FAIL" "hysteria config missing"; fi
    if [ -f /usr/local/afterlifevpn/setup/add-host.sh ]; then print_check "PASS" "add-host script"; else print_check "FAIL" "add-host script missing"; fi
    if [ -x /usr/local/bin/dnstt-server ]; then print_check "PASS" "dnstt-server binary"; else print_check "WARN" "dnstt-server not installed"; fi
    if [ -f /usr/local/afterlifevpn/setup/slowdns.sh ]; then print_check "PASS" "slowdns script"; else print_check "WARN" "slowdns script missing"; fi
    p53_load_state
    if [[ $P53_MODE == shared_* || $P53_MODE == slowdns ]]; then
        if iptables -t nat -L "$P53_CHAIN" -n &>/dev/null; then
            print_check "PASS" "port 53 mux rules active (mode: $P53_MODE)"
        else
            print_check "FAIL" "port 53 mode is $P53_MODE but mux rules are missing (open option 11 and re-select it)"
        fi
        if systemctl is-enabled --quiet afterlife-p53.service 2>/dev/null; then print_check "PASS" "port 53 boot restore service"; else print_check "WARN" "port 53 boot restore service not enabled"; fi
    fi
    echo ""
    echo -e " ${WHITE}[ Ports ]${NC}"
    check_port() {
        if ss -tuln 2>/dev/null | grep -q ":$1 "; then
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
    check_port 5300 "dnstt"
    HYST_PORT=443
    if [[ -f /usr/local/afterlifevpn/hysteria-config.txt ]]; then
        source /usr/local/afterlifevpn/hysteria-config.txt
        HYST_PORT=${PORT:-443}
    fi
    check_port $HYST_PORT "hysteria"
    echo ""
    echo -e " ${WHITE}[ Management ]${NC}"
    for cmd in menu wget qrencode tar nano; do
        if command -v "$cmd" &> /dev/null || [[ "$cmd" == "menu" && -f "/usr/local/afterlifevpn/menu/menu.sh" ]]; then
            print_check "PASS" "$cmd command"
        else
            print_check "FAIL" "$cmd command missing"
        fi
    done
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
# Non-interactive entry points (used by systemd / update)
case "$1" in
    --restore-p53)      p53_restore; exit 0 ;;
    --install-p53-unit) p53_install_unit; exit 0 ;;
esac
# Main loop
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
