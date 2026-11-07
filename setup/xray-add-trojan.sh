#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG="/usr/local/etc/xray/config.json"
DB="/usr/local/afterlifevpn/users/xray_users.txt"
CONFIG_DIR="/usr/local/etc/xray"
APP_CONFIG="/usr/local/afterlifevpn/config.conf"

CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
WHITE='\033[1;37m'
NC='\033[0m'

fail() { echo -e "${RED}Error: $*${NC}" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || fail "Run this account manager as root."
command -v jq >/dev/null 2>&1 || fail "jq is required. Install it with: apt-get install -y jq"
command -v openssl >/dev/null 2>&1 || fail "openssl is required."
[[ -s "$CONFIG" ]] || fail "Xray config not found at $CONFIG. Install/configure Xray first."

mkdir -p "$(dirname "$DB")" "$CONFIG_DIR"
touch "$DB"

DOMAIN_HOST=""
if [[ -f "$APP_CONFIG" ]]; then
    DOMAIN_HOST=$(sed -n 's/^DOMAIN=["'\'']\{0,1\}\([^"'\'']*\)["'\'']\{0,1\}$/\1/p' "$APP_CONFIG" | head -n1)
fi
if [[ -z "$DOMAIN_HOST" ]]; then
    DOMAIN_HOST=$(curl -4fsS --max-time 5 https://ifconfig.me 2>/dev/null || true)
fi

create_trojan_user() {
    local username days expiry created password tmp backup link
    read -r -p "  Username: " username
    [[ "$username" =~ ^[A-Za-z0-9_.-]{1,32}$ ]] || { echo -e "${RED}Use 1-32 letters, numbers, dot, underscore or hyphen.${NC}"; return 1; }
    if awk -F'|' -v u="$username" '$1==u {found=1} END {exit !found}' "$DB"; then
        echo -e "${RED}That username already exists in the Xray user database.${NC}"
        return 1
    fi

    read -r -p "  Expiry (days) [30]: " days
    days=${days:-30}
    [[ "$days" =~ ^[1-9][0-9]{0,3}$ ]] || { echo -e "${RED}Enter a whole number from 1 to 9999.${NC}"; return 1; }
    expiry=$(date -d "+$days days" +%Y-%m-%d) || return 1
    created=$(date +%Y-%m-%d)
    password=$(openssl rand -hex 16) || fail "Could not generate a Trojan password."

    jq -e 'any(.inbounds[]?; .protocol=="trojan" and .streamSettings.network=="ws")' "$CONFIG" >/dev/null ||
        fail "No Trojan WebSocket inbound exists in $CONFIG. Refusing to create an unusable account."

    tmp=$(mktemp "$CONFIG_DIR/.config.json.XXXXXX")
    backup=$(mktemp "$CONFIG_DIR/.config.json.rollback.XXXXXX")
    cp -a "$CONFIG" "$backup"
    if ! jq --arg password "$password" --arg email "$username" '
        (.inbounds[] | select(.protocol=="trojan" and .streamSettings.network=="ws") | .settings.clients) += [{"password":$password,"email":$email}]
    ' "$CONFIG" > "$tmp"; then
        rm -f "$tmp" "$backup"
        fail "Could not update Xray configuration."
    fi

    if ! xray run -test -config "$tmp"; then
        rm -f "$tmp" "$backup"
        fail "Xray rejected the updated configuration; no account was saved."
    fi

    chmod --reference="$CONFIG" "$tmp" 2>/dev/null || chmod 644 "$tmp"
    chown --reference="$CONFIG" "$tmp" 2>/dev/null || true
    mv "$tmp" "$CONFIG"
    if ! systemctl restart xray || ! systemctl is-active --quiet xray; then
        cp -a "$backup" "$CONFIG"
        systemctl restart xray || true
        rm -f "$backup"
        fail "Xray failed to restart. Previous config restored; account was not saved."
    fi
    rm -f "$backup"
    printf '%s|%s|%s|%s\n' "$username" "$password" "$expiry" "$created" >> "$DB"

    echo
    echo -e "${GREEN}========== TROJAN ACCOUNT CREATED ==========${NC}"
    printf 'Username : %s\nPassword : %s\nExpires  : %s\n' "$username" "$password" "$expiry"
    echo "Protocol : Trojan over WebSocket + TLS"
    echo "Port     : 443 (Nginx front end)"
    echo "WS Path  : /trojan"
    echo "Local    : 127.0.0.1:10003"
    echo "SNI/Host : ${DOMAIN_HOST:-Set your domain in config.conf}"
    if [[ -n "$DOMAIN_HOST" ]]; then
        link="trojan://${password}@${DOMAIN_HOST}:443?security=tls&sni=${DOMAIN_HOST}&type=ws&host=${DOMAIN_HOST}&path=%2Ftrojan#${username}-AFTERLIFE"
        echo
        echo "Trojan Link:"
        echo "$link"
        if command -v qrencode >/dev/null 2>&1; then
            echo
            qrencode -t ANSIUTF8 "$link"
        fi
    else
        echo "Set DOMAIN in $APP_CONFIG to generate a shareable link."
    fi
    echo -e "${GREEN}============================================${NC}"
}

list_trojan_users() {
    echo -e "${CYAN}Trojan accounts${NC}"
    local found=0 username password expiry created
    while IFS='|' read -r username password expiry created; do
        [[ -n "$username" && -n "$password" ]] || continue
        printf '%-20s Expiry: %-12s Created: %s\n' "$username" "${expiry:-unknown}" "${created:-unknown}"
        found=1
    done < "$DB"
    [[ "$found" -eq 1 ]] || echo "No Trojan accounts found in the shared Xray database."
}

delete_trojan_user() {
    local username password tmp backup
    read -r -p "  Trojan username to delete: " username
    [[ -n "$username" ]] || return 1
    password=$(awk -F'|' -v u="$username" '$1==u {print $2; exit}' "$DB")
    [[ -n "$password" ]] || { echo -e "${RED}Trojan account not found.${NC}"; return 1; }

    jq -e 'any(.inbounds[]?; .protocol=="trojan" and .streamSettings.network=="ws")' "$CONFIG" >/dev/null ||
        fail "Trojan WebSocket inbound is missing; database was not changed."

    tmp=$(mktemp "$CONFIG_DIR/.config.json.XXXXXX")
    backup=$(mktemp "$CONFIG_DIR/.config.json.rollback.XXXXXX")
    cp -a "$CONFIG" "$backup"
    if ! jq --arg password "$password" '
        .inbounds |= map(if .protocol=="trojan" then .settings.clients |= map(select(.password != $password)) else . end)
    ' "$CONFIG" > "$tmp" || ! xray run -test -config "$tmp"; then
        rm -f "$tmp" "$backup"
        fail "Could not safely remove the Trojan credential."
    fi
    chmod --reference="$CONFIG" "$tmp" 2>/dev/null || chmod 644 "$tmp"
    chown --reference="$CONFIG" "$tmp" 2>/dev/null || true
    mv "$tmp" "$CONFIG"
    if ! systemctl restart xray || ! systemctl is-active --quiet xray; then
        cp -a "$backup" "$CONFIG"
        systemctl restart xray || true
        rm -f "$backup"
        fail "Xray restart failed; previous config restored and database unchanged."
    fi
    rm -f "$backup"
    awk -F'|' -v u="$username" '$1!=u' "$DB" > "$DB.tmp"
    cat "$DB.tmp" > "$DB"
    rm -f "$DB.tmp"
    echo -e "${GREEN}Deleted Trojan account: $username${NC}"
}

while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${WHITE}              XRAY - TROJAN ACCOUNT MANAGER              ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "1) Create Trojan account"
    echo "2) List Trojan accounts"
    echo "3) Delete Trojan account"
    echo "0) Back"
    echo
    read -r -p "Select option [0-3]: " choice
    case "$choice" in
        1) create_trojan_user ;;
        2) list_trojan_users ;;
        3) delete_trojan_user ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}" ;;
    esac
    echo
    read -r -p "Press Enter to continue..." _
done
