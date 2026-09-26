#!/bin/bash
# AFTERLIFE - Hysteria 2 users
# Password-only hy2 links | IP host + domain SNI | command auth (argv[2]=password)
# Adds &obfs=... only when Salamander is on in yaml
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
USERS_FILE="/usr/local/afterlifevpn/users/hysteria_users.txt"
DOMAIN_FILE="/usr/local/afterlifevpn/config.conf"
HY_YAML="/etc/hysteria/config.yaml"
AUTH_SH="/etc/hysteria/auth.sh"
mkdir -p /usr/local/afterlifevpn/users /etc/hysteria
touch "$USERS_FILE"
chmod 644 "$USERS_FILE" 2>/dev/null || true
DOMAIN=""
PUBLIC_IP=""
if [ -f "$DOMAIN_FILE" ]; then
    # shellcheck disable=SC1090
    source "$DOMAIN_FILE" 2>/dev/null || true
fi
PORT=53
OBFS_PASSWORD=""
if [ -f "$HY_YAML" ]; then
    yaml_listen=$(awk '/^listen:/ {print $2; exit}' "$HY_YAML")
    yaml_listen=${yaml_listen#:}
    case "$yaml_listen" in
        ''|*[!0-9]*) ;;
        *) PORT="$yaml_listen" ;;
    esac
    if grep -qE '^obfs:' "$HY_YAML"; then
        OBFS_PASSWORD=$(awk '/salamander:/{f=1} f && /password:/{print $2; exit}' "$HY_YAML")
        OBFS_PASSWORD=${OBFS_PASSWORD//\"/}
    fi
fi
HOST="${DOMAIN:-}"
IP="${PUBLIC_IP:-}"
[ -z "$IP" ] && IP=$(curl -4 -s --max-time 5 ifconfig.me)
[ -z "$IP" ] && IP=$(curl -4 -s --max-time 5 icanhazip.com)
[ -z "$HOST" ] && HOST="$IP"
[ -z "$IP" ] && IP="$HOST"
pause() { read -r -p "  Press Enter to continue..."; }
write_auth() {
    python3 -c '
from pathlib import Path
Path("/etc/hysteria/auth.sh").write_text("""#!/usr/bin/env python3
import sys
from datetime import datetime
auth = sys.argv[2] if len(sys.argv) > 2 else (sys.argv[1] if len(sys.argv) > 1 else "")
path = "/usr/local/afterlifevpn/users/hysteria_users.txt"
username = None
password = auth
if ":" in auth:
    username, password = auth.split(":", 1)
try:
    lines = open(path).read().splitlines()
except FileNotFoundError:
    sys.exit(1)
record = None
for line in lines:
    parts = line.split("|")
    if len(parts) < 3:
        continue
    u, p, exp = parts[0], parts[1], parts[2]
    if username is not None:
        if u == username and p == password:
            record = (u, p, exp)
            break
    elif p == password:
        record = (u, p, exp)
        break
if record is None:
    sys.exit(1)
try:
    if datetime.now() > datetime.strptime(record[2], "%Y-%m-%d"):
        sys.exit(1)
except ValueError:
    sys.exit(1)
print(record[0])
sys.exit(0)
""")
'
    chmod 755 "$AUTH_SH"
}
ensure_command_yaml() {
    python3 -c '
from pathlib import Path
p = Path("/etc/hysteria/config.yaml")
if not p.exists():
    raise SystemExit(0)
lines = p.read_text().splitlines()
out = []
i = 0
done = False
while i < len(lines):
    if lines[i].strip() == "auth:" and not done:
        out.extend(["auth:", "  type: command", "  command: /etc/hysteria/auth.sh"])
        done = True
        i += 1
        while i < len(lines) and (lines[i].strip() == "" or lines[i].startswith(" ") or lines[i].startswith("\t")):
            i += 1
        continue
    out.append(lines[i])
    i += 1
if not done:
    out.extend(["", "auth:", "  type: command", "  command: /etc/hysteria/auth.sh"])
p.write_text("\n".join(out) + "\n")
'
    systemctl restart hysteria >/dev/null 2>&1 || true
}
obfs_query() {
    if [ -n "$OBFS_PASSWORD" ]; then
        printf '&obfs=salamander&obfs-password=%s' "$OBFS_PASSWORD"
    fi
}
generate_links() {
    local user="$1"
    local pass="$2"
    local exp="${3:-}"
    local hy_port="${PORT:-53}"
    local extra
    extra=$(obfs_query)
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "🚀 ${WHITE}AFTERLIFE — HYSTERIA 2${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "👤 ${WHITE}ACCOUNT${NC}"
    echo -e " User     : ${GREEN}${user}${NC}"
    echo -e " Password : ${GREEN}${pass}${NC}"
    echo -e " Port     : ${YELLOW}${hy_port}${NC} (UDP)"
    [ -n "$exp" ] && echo -e " Expires  : ${YELLOW}${exp}${NC}"
    if [ -n "$OBFS_PASSWORD" ]; then
        echo -e " Obfs     : ${YELLOW}salamander${NC}"
        echo -e " Obfs pass: ${GREEN}${OBFS_PASSWORD}${NC}"
    else
        echo -e " Obfs     : ${GREEN}off${NC}"
    fi
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "🔗 ${WHITE}STANDARD LINK${NC}"
    echo "hy2://${pass}@${IP}:${hy_port}?insecure=1&sni=${HOST}${extra}#${user}-Hy2"
    echo -e "${CYAN}══════════════════════════════${NC}"
    echo -e "🔀 ${WHITE}PORT-HOPPING LINK (harder to block)${NC}"
    echo "hy2://${pass}@${IP}:${hy_port},20000-40000?insecure=1&sni=${HOST}${extra}#${user}-Hy2-Hop"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
}
add_user() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         ADD HYSTERIA USER${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo
    read -r -p "  Username: " username
    if [ -z "$username" ]; then
        echo -e "  ${RED}Username cannot be empty.${NC}"
        pause
        return
    fi
    if grep -q "^${username}|" "$USERS_FILE"; then
        echo -e "  ${RED}User already exists.${NC}"
        pause
        return
    fi
    read -r -p "  Expiration days [30]: " days
    days=${days:-30}
    password=$(openssl rand -hex 6)
    expiry=$(date -d "+${days} days" +%Y-%m-%d)
    echo "${username}|${password}|${expiry}" >> "$USERS_FILE"
    echo
    echo -e "  ${GREEN}✓ Password generated and saved${NC}"
    echo
    generate_links "$username" "$password" "$expiry"
    pause
}
delete_user() {
    clear
    echo -e "${YELLOW}         DELETE USER${NC}"
    echo
    if [ ! -s "$USERS_FILE" ]; then
        echo -e "  ${RED}No users.${NC}"
        pause
        return
    fi
    cut -d'|' -f1 "$USERS_FILE" | nl -w2 -s'. '
    echo
    read -r -p "  Username: " username
    if grep -q "^${username}|" "$USERS_FILE"; then
        sed -i "/^${username}|/d" "$USERS_FILE"
        echo -e "  ${GREEN}✓ Deleted${NC}"
    else
        echo -e "  ${RED}Not found${NC}"
    fi
    pause
}
list_users() {
    clear
    echo -e "${YELLOW}         USER LIST${NC}"
    echo
    if [ ! -s "$USERS_FILE" ]; then
        echo -e "  ${RED}No users.${NC}"
        pause
        return
    fi
    printf "  %-4s %-16s %-18s %-12s\n" "No" "User" "Password" "Expiry"
    echo "  ----------------------------------------------------"
    i=1
    while IFS='|' read -r user pass exp; do
        [ -z "$user" ] && continue
        printf "  %-4s %-16s %-18s %-12s\n" "$i" "$user" "$pass" "$exp"
        i=$((i + 1))
    done < "$USERS_FILE"
    echo
    pause
}
show_user_link() {
    clear
    echo -e "${YELLOW}         SHOW LINK${NC}"
    echo
    if [ ! -s "$USERS_FILE" ]; then
        echo -e "  ${RED}No users.${NC}"
        pause
        return
    fi
    cut -d'|' -f1 "$USERS_FILE" | nl -w2 -s'. '
    echo
    read -r -p "  Username: " username
    rec=$(grep "^${username}|" "$USERS_FILE" || true)
    if [ -z "$rec" ]; then
        echo -e "  ${RED}Not found.${NC}"
        pause
        return
    fi
    generate_links "$username" "$(echo "$rec" | cut -d'|' -f2)" "$(echo "$rec" | cut -d'|' -f3)"
    pause
}
if [ ! -f "$HY_YAML" ]; then
    echo -e "${RED}Missing $HY_YAML${NC}"
    exit 1
fi
write_auth
if ! grep -q '|qMBcPERq5JKxEl4ZDfOlDA==|' "$USERS_FILE"; then
    echo 'core|qMBcPERq5JKxEl4ZDfOlDA==|2027-12-31' >> "$USERS_FILE"
fi
ensure_command_yaml
while true; do
    clear
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}      AFTERLIFE — HYSTERIA 2 USERS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo
    echo -e "  Host : ${GREEN}${HOST}${NC}"
    echo -e "  IP   : ${GREEN}${IP}${NC}"
    echo -e "  Port : ${YELLOW}${PORT}${NC} UDP"
    if [ -n "$OBFS_PASSWORD" ]; then
        echo -e "  Obfs : ${YELLOW}salamander ON${NC}"
    else
        echo -e "  Obfs : ${GREEN}off${NC}"
    fi
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
    esac
done
