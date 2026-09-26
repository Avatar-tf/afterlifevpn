#!/bin/bash
# ============================================================================
# AFTERLIFE - Hysteria 2 user manager
# Path: setup/hysteria-user.sh
# Adds users to hysteria_users.txt (read by /etc/hysteria/auth.sh).
# Does NOT reinstall Hysteria or change listen/obfs.
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

USERS_FILE="/usr/local/afterlifevpn/users/hysteria_users.txt"
CONFIG_FILE="/usr/local/afterlifevpn/hysteria-config.txt"
DOMAIN_FILE="/usr/local/afterlifevpn/config.conf"
HY_YAML="/etc/hysteria/config.yaml"
AUTH_SH="/etc/hysteria/auth.sh"

mkdir -p /usr/local/afterlifevpn/users
touch "$USERS_FILE"

DOMAIN=""
PUBLIC_IP=""
[[ -f "$DOMAIN_FILE" ]] && source "$DOMAIN_FILE"

PORT=443
MODE="443"
SALAMANDER="n"
OBFS_PASSWORD=""
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

if [[ -f "$HY_YAML" ]]; then
    yaml_listen=$(awk '/^listen:/ {print $2; exit}' "$HY_YAML" 2>/dev/null || true)
    yaml_listen=${yaml_listen#:}
    if [[ "$yaml_listen" =~ ^[0-9]+$ ]]; then
        PORT="$yaml_listen"
    fi
fi

HOST="${DOMAIN:-$PUBLIC_IP}"
if [[ -z "$HOST" ]]; then
    HOST=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
fi
HOST="${HOST:-YOUR-SERVER}"

ensure_auth_helper() {
    if [[ -x "$AUTH_SH" ]]; then
        return 0
    fi
    mkdir -p /etc/hysteria
    cat > "$AUTH_SH" <<'EOF'
#!/bin/bash
AUTH_PAYLOAD="$1"
USERS_FILE="/usr/local/afterlifevpn/users/hysteria_users.txt"

if [[ "$AUTH_PAYLOAD" == *":"* ]]; then
    USERNAME="${AUTH_PAYLOAD%%:*}"
    PASSWORD="${AUTH_PAYLOAD#*:}"
    USER_RECORD=$(grep "^${USERNAME}|${PASSWORD}|" "$USERS_FILE" 2>/dev/null)
else
    PASSWORD="$AUTH_PAYLOAD"
    USER_RECORD=$(grep "|${PASSWORD}|" "$USERS_FILE" 2>/dev/null | head -1)
fi

[[ -z "$USER_RECORD" ]] && exit 1

EXPIRY=$(echo "$USER_RECORD" | cut -d'|' -f3)
EXPIRY_SEC=$(date -d "$EXPIRY" +%s 2>/dev/null || echo 0)
CURRENT_SEC=$(date +%s)
[[ "$CURRENT_SEC" -gt "$EXPIRY_SEC" ]] && exit 1
exit 0
EOF
    chmod 755 "$AUTH_SH"
}

pause() { read -r -p "  Press Enter to continue..."; }

generate_links() {
    local user="$1"
    local pass="$2"
    local remark="${3:-$user}"
    local extra=""
    if [[ "${SALAMANDER}" == "y" || "${SALAMANDER}" == "Y" || "${SALAMANDER}" == "yes" ]]; then
        if [[ -n "$OBFS_PASSWORD" ]]; then
            extra="&obfs=salamander&obfs-password=${OBFS_PASSWORD}"
        fi
    fi
    local hy_port="${PORT:-53}"

    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "🚀 ${WHITE}AFTERLIFE — HYSTERIA 2${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "👤 ${WHITE}ACCOUNT${NC}"
    echo -e " User     : ${GREEN}${user}${NC}"
    echo -e " Password : ${GREEN}${pass}${NC}"
    echo -e " Port     : ${YELLOW}${hy_port}${NC} (UDP)"
    echo -e "${CYAN}══════════════════════════════${NC}"
    echo -e "🔗 ${WHITE}STANDARD LINK${NC}"
    echo "hy2://${pass}@${HOST}:${hy_port}?insecure=1&sni=${HOST}${extra}#${remark}-Hy2"
    echo -e "${CYAN}══════════════════════════════${NC}"
    echo -e "🔀 ${WHITE}PORT-HOPPING LINK (harder to block)${NC}"
    echo "hy2://${pass}@${HOST}:${hy_port},20000-40000?insecure=1&sni=${HOST}${extra}#${remark}-Hy2-Hop"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
}

add_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         ADD HYSTERIA USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo
    read -r -p "  Username: " username
    if [[ -z "$username" ]]; then
        echo -e "  ${RED}Username cannot be empty.${NC}"; pause; return
    fi
    if grep -q "^${username}|" "$USERS_FILE"; then
        echo -e "  ${RED}User already exists.${NC}"; pause; return
    fi
    read -r -p "  Password (empty = auto): " password
    if [[ -z "$password" ]]; then
        password=$(openssl rand -hex 6)
    fi
    read -r -p "  Expiration days [30]: " days
    days=${days:-30}
    expiry=$(date -d "+${days} days" +%Y-%m-%d)

    echo "${username}|${password}|${expiry}" >> "$USERS_FILE"
    echo
    echo -e "  ${GREEN}✓ User saved.${NC}"
    echo
    generate_links "$username" "$password" "$username"
    pause
}

delete_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         DELETE HYSTERIA USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo
    if [[ ! -s "$USERS_FILE" ]]; then
        echo -e "  ${RED}No users found.${NC}"; pause; return
    fi
    cut -d'|' -f1 "$USERS_FILE" | nl -w2 -s'. '
    echo
    read -r -p "  Username to delete: " username
    if grep -q "^${username}|" "$USERS_FILE"; then
        sed -i "/^${username}|/d" "$USERS_FILE"
        echo -e "  ${GREEN}✓ Deleted ${username}${NC}"
    else
        echo -e "  ${RED}User not found.${NC}"
    fi
    pause
}

list_users() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         HYSTERIA USER LIST${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo
    if [[ ! -s "$USERS_FILE" ]]; then
        echo -e "  ${RED}No users found.${NC}"; pause; return
    fi
    printf "  %-4s %-16s %-16s %-12s %s\n" "No" "Username" "Password" "Expiry" "Status"
    echo "  ---------------------------------------------------------------"
    local i=1 user pass exp exp_sec now_sec status
    now_sec=$(date +%s)
    while IFS='|' read -r user pass exp; do
        [[ -z "$user" ]] && continue
        exp_sec=$(date -d "$exp" +%s 2>/dev/null || echo 0)
        if (( now_sec > exp_sec )); then
            status="${RED}EXPIRED${NC}"
        else
            status="${GREEN}ACTIVE${NC}"
        fi
        printf "  %-4s %-16s %-16s %-12s %b\n" "$i" "$user" "$pass" "$exp" "$status"
        ((i++))
    done < "$USERS_FILE"
    echo
    pause
}

show_user_link() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}       SHOW HYSTERIA USER LINK${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo
    if [[ ! -s "$USERS_FILE" ]]; then
        echo -e "  ${RED}No users found.${NC}"; pause; return
    fi
    cut -d'|' -f1 "$USERS_FILE" | nl -w2 -s'. '
    echo
    read -r -p "  Username: " username
    local rec
    rec=$(grep "^${username}|" "$USERS_FILE" || true)
    if [[ -z "$rec" ]]; then
        echo -e "  ${RED}User not found.${NC}"; pause; return
    fi
    local pass exp
    pass=$(echo "$rec" | cut -d'|' -f2)
    exp=$(echo "$rec" | cut -d'|' -f3)
    echo
    echo -e "  Expiry : $exp"
    generate_links "$username" "$pass" "$username"
    pause
}

ensure_auth_helper

if [[ ! -f "$HY_YAML" ]]; then
    echo -e "${RED}Hysteria config missing: $HY_YAML${NC}"
    echo -e "${YELLOW}Install Hysteria first (menu 3 option 2) — do that later.${NC}"
    pause
fi

while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}      AFTERLIFE - HYSTERIA 2 USERS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo
    echo -e "  Host : ${GREEN}${HOST}${NC}"
    echo -e "  Port : ${YELLOW}${PORT}${NC} (from live yaml / saved config)"
    echo
    echo -e "  ${GREEN}1)${NC} Add User"
    echo -e "  ${GREEN}2)${NC} Delete User"
    echo -e "  ${GREEN}3)${NC} List Users"
    echo -e "  ${GREEN}4)${NC} Show User Link"
    echo -e "  ${RED}0)${NC} Back"
    echo
    read -r -p "  Select [0-4]: " opt
    case "$opt" in
        1) add_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) show_user_link ;;
        0|5|q|Q|x|X) exit 0 ;;
        *) sleep 0.3 ;;
    esac
done
