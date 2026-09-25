#!/bin/bash
# ==========================================================
# AFTERLIFE - Hysteria 2 User Management
# ==========================================================

USERS_FILE="/usr/local/afterlifevpn/users/hysteria_users.txt"
CONFIG_FILE="/usr/local/afterlifevpn/hysteria-config.txt"
DOMAIN_FILE="/usr/local/afterlifevpn/config.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

mkdir -p /usr/local/afterlifevpn/users
touch "$USERS_FILE"

# Load domain and hysteria config
if [[ -f "$DOMAIN_FILE" ]]; then
    source "$DOMAIN_FILE"
else
    echo -e "${RED}Error: Domain config not found.${NC}"
    exit 1
fi

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    PORT=36712
    MODE="single"
    SALAMANDER="n"
fi

# Generate both links for a user
generate_links() {
    local user=$1
    local pass=$2
    local remark=${3:-Afterlife-Hy2}

    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         HYSTERIA 2 LINKS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo
    echo -e "${GREEN}STANDARD LINK${NC}"
    echo "hy2://${user}:${pass}@${DOMAIN}:${PORT}?insecure=1&sni=${DOMAIN}#${remark}"
    echo
    echo -e "${GREEN}PORT-HOPPING LINK (harder to block)${NC}"
    echo "hy2://${user}:${pass}@${DOMAIN}:${PORT},20000-50000?insecure=1&sni=${DOMAIN}#${remark}-Hop"
    echo
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
}

add_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         ADD HYSTERIA USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo

    read -p "Username: " username
    if [[ -z "$username" ]]; then
        echo -e "${RED}Username cannot be empty.${NC}"
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi

    # Check if user already exists
    if grep -q "^${username}|" "$USERS_FILE"; then
        echo -e "${RED}User already exists.${NC}"
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi

    read -p "Password (leave empty to auto-generate): " password
    if [[ -z "$password" ]]; then
        password=$(openssl rand -hex 6)
    fi

    read -p "Expiration days (default 30): " days
    days=${days:-30}
    expiry=$(date -d "+${days} days" +%Y-%m-%d)

    # Format: username|password|expiry
    echo "${username}|${password}|${expiry}" >> "$USERS_FILE"

    echo
    echo -e "${GREEN}✓ User created successfully!${NC}"
    echo
    echo -e "Username   : $username"
    echo -e "Password   : $password"
    echo -e "Expiry     : $expiry"
    echo

    generate_links "$username" "$password" "$username"
    read -n 1 -s -r -p "Press any key to continue..."
}

delete_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         DELETE HYSTERIA USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo

    if [[ ! -s "$USERS_FILE" ]]; then
        echo -e "${RED}No users found.${NC}"
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi

    echo -e "Current users:"
    echo
    nl -w2 -s'. ' "$USERS_FILE" | cut -d'|' -f1
    echo
    read -p "Enter username to delete: " username

    if grep -q "^${username}|" "$USERS_FILE"; then
        sed -i "/^${username}|/d" "$USERS_FILE"
        echo -e "${GREEN}✓ User '$username' deleted.${NC}"
    else
        echo -e "${RED}User not found.${NC}"
    fi
    read -n 1 -s -r -p "Press any key to continue..."
}

list_users() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         HYSTERIA USER LIST${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo

    if [[ ! -s "$USERS_FILE" ]]; then
        echo -e "${RED}No users found.${NC}"
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi

    printf "%-4s %-18s %-16s %-12s %-10s\n" "No" "Username" "Password" "Expiry" "Status"
    echo "---------------------------------------------------------------"

    local i=1
    while IFS='|' read -r user pass exp; do
        exp_sec=$(date -d "$exp" +%s 2>/dev/null || echo 0)
        now_sec=$(date +%s)
        if [[ $now_sec -gt $exp_sec ]]; then
            status="${RED}EXPIRED${NC}"
        else
            status="${GREEN}ACTIVE${NC}"
        fi
        printf "%-4s %-18s %-16s %-12s %-10b\n" "$i" "$user" "$pass" "$exp" "$status"
        ((i++))
    done < "$USERS_FILE"

    echo
    read -n 1 -s -r -p "Press any key to continue..."
}

show_user_link() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}       SHOW HYSTERIA USER LINK${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo

    if [[ ! -s "$USERS_FILE" ]]; then
        echo -e "${RED}No users found.${NC}"
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi

    echo -e "Current users:"
    echo
    cut -d'|' -f1 "$USERS_FILE" | nl -w2 -s'. '
    echo
    read -p "Enter username: " username

    USER_RECORD=$(grep "^${username}|" "$USERS_FILE")
    if [[ -z "$USER_RECORD" ]]; then
        echo -e "${RED}User not found.${NC}"
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi

    pass=$(echo "$USER_RECORD" | cut -d'|' -f2)
    exp=$(echo "$USER_RECORD" | cut -d'|' -f3)

    echo
    echo -e "Username : $username"
    echo -e "Password : $pass"
    echo -e "Expiry   : $exp"
    echo

    generate_links "$username" "$pass" "$username"
    read -n 1 -s -r -p "Press any key to continue..."
}

# Main Menu
while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}      AFTERLIFE - HYSTERIA 2 MENU${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo
    echo -e "  1) Add User"
    echo -e "  2) Delete User"
    echo -e "  3) List Users"
    echo -e "  4) Show User Link (Standard + Hopping)"
    echo -e "  5) Exit"
    echo
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo -e " Current Port : $PORT  |  Mode : $MODE"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    echo
    read -p "Select option [1-5]: " opt

    case $opt in
        1) add_user ;;
        2) delete_user ;;
        3) list_users ;;
        4) show_user_link ;;
        5) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
