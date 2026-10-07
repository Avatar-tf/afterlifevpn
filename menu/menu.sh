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
        echo -e "${CYAN}║${NC}${CYAN}Nameserver:${NC}${GREEN}${ACTIVE_NS}${NC} ${CYAN}║${NC}"
    fi
    echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
    printf "${CYAN}║${NC}${WHITE}%-54s${NC}${CYAN}║${NC}\n" "$breadcrumb"
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
        echo -e "${CYAN}║${NC}${CYAN}Nameserver:${NC}${GREEN}${ACTIVE_NS}${NC} ${CYAN}║${NC}"
    fi
    echo -e "${CYAN}╠────────────────────────────────────────────────────────╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}› AFTERLIFE › Core${NC}                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo -e "  ${WHITE}Server:${NC}${DOMAIN:-$HOSTNAME}${CYAN}($PUBLIC_IP)${NC}"
    echo -e "  ${WHITE}OS:${NC}$OS_VERSION"
    echo -e "  ${WHITE}Uptime:${NC}$UPTIME"
    echo -e "  ${WHITE}CPU:${NC}  $(create_bar$CPU_USAGE_INT) ${CPU_USAGE_INT}\%${CYAN}($CPU_CORES Core)${NC}"
    echo -e "  ${WHITE}RAM:${NC}$(create_bar $RAM_PERCENT)${RAM_PERCENT}% ${CYAN}(${USED_RAM}MB / ${TOTAL_RAM}MB)${NC}"
    echo -e "  ${WHITE}Disk:${NC}$(create_bar $DISK_PERCENT)${DISK_PERCENT}% ${CYAN}($USED_DISK / $TOTAL_DISK)${NC}"
    echo -e "  ${WHITE}[ Active Services ]${NC}"
    echo -e "  $(check_service xray)${WHITE}Xray${NC}$(check_service nginx) ${WHITE}Nginx${NC}   $(check_service hysteria)${WHITE}Hysteria2${NC}$(check_service wg-quick@wg0) ${WHITE}WireGuard${NC}"
    echo -e "  $(check_service ssh)${WHITE}SSH${NC}$(check_service dropbear) ${WHITE}Dropbear${NC}   $(check_service squid)${WHITE}Squid${NC}$(check_service danted) ${WHITE}Dante${NC}"
    local user_count=$(count_users)
    echo -e "  ${WHITE}Registered Clients:${NC}${GREEN}$user_count${NC} total across protocols"
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
    echo "$username\vert{}$password|$exp_date\vert{}$(date +%Y-%m-%d)|$devices\vert{}$quota" >> /usr/local/afterlifevpn/users/ssh_users.txt
    
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
    echo -e "   ${YELLOW}GET wss://$SERVER_HOST/ HTTP/1.1[crlf]Host:$
