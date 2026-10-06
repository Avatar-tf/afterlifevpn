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
