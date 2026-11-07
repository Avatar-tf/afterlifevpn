#!/usr/bin/env bash
# AFTERLIFE VPN - DNSTT / DNS Features account management.
# DNSTT forwards tunnel traffic to the existing Dropbear SSH backend.
# Therefore every account shown here is a shared SSH account as well.
set -Eeuo pipefail

ROOT=/usr/local/afterlifevpn
USERS_DIR=$ROOT/users
SSH_DB=$USERS_DIR/ssh_users.txt
DNS_DIR=/etc/afterlifevpn/dns
DNS_KEY=$DNS_DIR/server.pub
RESOLVER_FILE=$ROOT/dnstt-resolver.conf
P53_STATE=$ROOT/port53-mode.conf
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

[[ $EUID -eq 0 ]] || { echo -e "$RED Must run as root.$NC"; exit 1; }
pause() { read -r -p "  Press Enter to continue..." _ || true; }
header() {
  clear
  echo -e "$CYAN════════════════════════════════════════════════════════════$NC"
  echo -e "  $WHITE AFTERLIFE VPN — DNS FEATURES / DNSTT$NC"
  echo -e "$CYAN════════════════════════════════════════════════════════════$NC\n"
}
load_config() {
  DOMAIN=; NS_HOST=; NS_DOMAIN=
  [[ -r $ROOT/config.conf ]] && source "$ROOT/config.conf"
  [[ -r $ROOT/nameserver.conf ]] && source "$ROOT/nameserver.conf"
  SERVER_HOST=$DOMAIN
  [[ -n $SERVER_HOST ]] || SERVER_HOST=$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || hostname -f 2>/dev/null || hostname)
  TUNNEL_NS=$NS_HOST
  [[ -n $TUNNEL_NS ]] || TUNNEL_NS=$NS_DOMAIN
  SERVER_PUBLIC_KEY=
  [[ -s $DNS_KEY ]] && SERVER_PUBLIC_KEY=$(tr -d '[:space:]' < "$DNS_KEY")

  local exec_line
  exec_line=$(systemctl show -p ExecStart --value dnstt.service 2>/dev/null || true)
  BACKEND_PORT=$(printf '%s' "$exec_line" | sed -n 's/.*127\.0\.0\.1:\([0-9][0-9]*\).*/\1/p')
  [[ -n $BACKEND_PORT ]] || BACKEND_PORT=$(awk -F= '/^DROPBEAR_PORT=/{gsub(/[" ]/,"",$2);print $2;exit}' /etc/default/dropbear 2>/dev/null || true)
  [[ -n $BACKEND_PORT ]] || BACKEND_PORT=109
  DROPBEAR_PORT=$(awk -F= '/^DROPBEAR_PORT=/{gsub(/[" ]/,"",$2);print $2;exit}' /etc/default/dropbear 2>/dev/null || true)
  [[ -n $DROPBEAR_PORT ]] || DROPBEAR_PORT=109

  DNS_RESOLVER=8.8.8.8:53
  [[ -s $RESOLVER_FILE ]] && DNS_RESOLVER=$(head -n1 "$RESOLVER_FILE" | tr -d '[:space:]')
  [[ -n $DNS_RESOLVER ]] || DNS_RESOLVER=8.8.8.8:53
  P53_MODE=none
  [[ -r $P53_STATE ]] && P53_MODE=$(sed -n 's/^MODE=//p' "$P53_STATE" | tail -n1 | tr -d "\"' ")
  [[ -n $P53_MODE ]] || P53_MODE=none
  UDPGW_PORT=7300
  if [[ -r /etc/systemd/system/badvpn.service ]]; then
    local port
    port=$(sed -n 's/.*--listen-addr[[:space:]]*127\.0\.0\.1:\([0-9][0-9]*\).*/\1/p' /etc/systemd/system/badvpn.service | head -n1)
    [[ -n $port ]] && UDPGW_PORT=$port
  fi
}
valid_resolver() {
  [[ $1 =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]] || return 1
  local port
  port=$(printf '%s' "$1" | cut -d: -f2)
  (( port >= 1 && port <= 65535 ))
}
dns_ready() {
  load_config
  local bad=0
  if [[ ! -s $DNS_DIR/server.key || ! $SERVER_PUBLIC_KEY =~ ^[0-9A-Fa-f]{64}$ ]]; then
    echo -e "  $RED DNSTT server keypair is missing or invalid.$NC"; bad=1
  fi
  if [[ -z $TUNNEL_NS ]]; then
    echo -e "  $RED DNSTT nameserver/tunnel domain is not configured.$NC"; bad=1
  fi
  if ! systemctl is-active --quiet dnstt.service; then
    echo -e "  $RED DNSTT service is not running. Check Option 11 and journalctl -u dnstt.$NC"; bad=1
  fi
  if ! systemctl is-active --quiet dropbear.service; then
    echo -e "  $RED Dropbear backend is not running.$NC"; bad=1
  fi
  (( bad == 0 ))
}
show_config() {
  load_config
  local ns key
  ns=$TUNNEL_NS; key=$SERVER_PUBLIC_KEY
  [[ -n $ns ]] || ns="Not configured"
  [[ -n $key ]] || key="Not installed"
  echo -e "  $WHITE CLIENT CONFIGURATION$NC"
  echo -e "  Protocol        : $GREEN SSH-DNSTT$NC"
  echo -e "  SSH Host        : $GREEN$SERVER_HOST$NC"
  echo -e "  SSH Port        : $GREEN$BACKEND_PORT$NC $CYAN(DNSTT backend / Dropbear)$NC"
  echo -e "  UDPGW Port      : $GREEN$UDPGW_PORT$NC"
  echo -e "  Transparent DNS : $GREEN Enable in client$NC"
  echo -e "  DNSTT Mode      : $GREEN UDP$NC"
  echo -e "  Resolver        : $GREEN$DNS_RESOLVER$NC"
  echo -e "  Nameserver      : $GREEN$ns$NC"
  echo -e "  Public Key      : $YELLOW$key$NC"
  echo -e "  Port 53 Mode    : $YELLOW$P53_MODE$NC"
  [[ $BACKEND_PORT == "$DROPBEAR_PORT" ]] || echo -e "  $YELLOW WARNING: DNSTT forwards to $BACKEND_PORT but Dropbear listens on $DROPBEAR_PORT.$NC"
  case $P53_MODE in
    slowdns|shared_hy|shared_udp|shared_all) ;;
    *) echo -e "  $YELLOW Select SlowDNS or a Shared mode in Option 11 before testing UDP/53.$NC" ;;
  esac
}
create_account() {
  header
  echo -e "  $WHITE CREATE DNSTT ACCOUNT$NC"
  echo -e "  $CYAN Creates a shared SSH/Dropbear login used by DNSTT.$NC\n"
  if ! dns_ready; then pause; return; fi
  local username password password2 days devices quota expiry created resolver_input resolver
  read -r -p "  Username: " username
  if [[ ! $username =~ ^[A-Za-z_][A-Za-z0-9_.-]{0,31}$ ]]; then
    echo -e "  $RED Invalid username. Use 1-32 letters, digits, dot, underscore or hyphen.$NC"; pause; return
  fi
  if id "$username" >/dev/null 2>&1; then
    echo -e "  $RED Username already exists. Existing SSH accounts already work through DNSTT.$NC"; pause; return
  fi
  read -r -p "  Expiry days [30]: " days; [[ -n $days ]] || days=30
  if [[ ! $days =~ ^[0-9]{1,4}$ ]] || (( days < 1 || days > 3650 )); then
    echo -e "  $RED Expiry must be between 1 and 3650 days.$NC"; pause; return
  fi
  read -r -p "  Max devices [2]: " devices; [[ -n $devices ]] || devices=2
  if [[ ! $devices =~ ^[0-9]{1,3}$ ]] || (( devices < 1 || devices > 100 )); then
    echo -e "  $RED Max devices must be between 1 and 100.$NC"; pause; return
  fi
  read -r -p "  Data quota label [Unlimited]: " quota; [[ -n $quota ]] || quota=Unlimited
  if [[ $quota == *"|"* ]]; then echo -e "  $RED Invalid quota label.$NC"; pause; return; fi
  read -r -s -p "  Password (blank = generate): " password; echo
  if [[ -z $password ]]; then
    password=$(openssl rand -hex 8 2>/dev/null || od -An -N8 -tx1 /dev/urandom | tr -d ' \n')
    echo -e "  Generated password: $GREEN$password$NC"
  else
    read -r -s -p "  Confirm password: " password2; echo
    if [[ $password != "$password2" ]]; then echo -e "  $RED Passwords do not match.$NC"; pause; return; fi
  fi
  if [[ -z $password || $password == *"|"* ]]; then echo -e "  $RED Password cannot be empty or contain |.$NC"; pause; return; fi
  read -r -p "  DNS Resolver [$DNS_RESOLVER]: " resolver_input
  resolver=$resolver_input; [[ -n $resolver ]] || resolver=$DNS_RESOLVER
  if ! valid_resolver "$resolver"; then echo -e "  $RED Use resolver format 8.8.8.8:53.$NC"; pause; return; fi

  expiry=$(date -d "+$days days" +%Y-%m-%d)
  created=$(date +%Y-%m-%d)
  mkdir -p "$USERS_DIR"; touch "$SSH_DB"; chmod 600 "$SSH_DB"
  if awk -F'|' -v u="$username" '$1==u{f=1}END{exit !f}' "$SSH_DB"; then
    echo -e "  $RED Username already exists in SSH database.$NC"; pause; return
  fi
  if ! useradd -e "$expiry" -s /bin/false -M "$username"; then echo -e "  $RED useradd failed.$NC"; pause; return; fi
  if ! printf '%s:%s\n' "$username" "$password" | chpasswd; then
    userdel "$username" 2>/dev/null || true; echo -e "  $RED Password setup failed; user rolled back.$NC"; pause; return
  fi
  if command -v htpasswd >/dev/null 2>&1 && [[ -f /etc/squid/passwd ]]; then
    htpasswd -b /etc/squid/passwd "$username" "$password" >/dev/null 2>&1 || true
  fi
  if ! printf '%s|%s|%s|%s|%s|%s\n' "$username" "$password" "$expiry" "$created" "$devices" "$quota" >> "$SSH_DB"; then
    userdel "$username" 2>/dev/null || true; echo -e "  $RED Could not save user record; account rolled back.$NC"; pause; return
  fi
  printf '%s\n' "$resolver" > "$RESOLVER_FILE"; chmod 600 "$RESOLVER_FILE"
  header
  echo -e "  $GREEN DNSTT ACCOUNT CREATED$NC\n"
  echo -e "  Username        : $GREEN$username$NC"
  echo -e "  Password        : $GREEN$password$NC"
  echo -e "  Expires         : $YELLOW$expiry$NC"
  echo -e "  Max devices     : $devices"
  echo -e "  Data quota      : $quota $CYAN(metadata only; quota enforcement is not implemented)$NC\n"
  show_config
  echo -e "\n  $YELLOW These credentials also work for ordinary SSH. The DNSTT public key is shared by all users.$NC"
  pause
}
list_accounts() {
  header
  echo -e "  $WHITE DNSTT-COMPATIBLE ACCOUNTS (SHARED SSH USERS)$NC\n"
  if [[ ! -s $SSH_DB ]]; then echo -e "  $YELLOW No SSH accounts found.$NC"; pause; return; fi
  printf "  %-18s %-13s %-13s %-12s\n" USERNAME CREATED EXPIRES STATUS
  echo "  ───────────────────────────────────────────────────────────"
  local username password expiry created devices quota expiry_epoch now status
  now=$(date +%s)
  while IFS='|' read -r username password expiry created devices quota; do
    [[ -n $username ]] || continue
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
    if (( expiry_epoch > 0 && expiry_epoch >= now )) && id "$username" >/dev/null 2>&1; then status="$GREEN Active$NC"; else status="$RED Expired/Unavailable$NC"; fi
    [[ -n $created ]] || created=N/A; [[ -n $expiry ]] || expiry=N/A
    printf "  %-18s %-13s %-13s " "$username" "$created" "$expiry"
    echo -e "$status"
  done < "$SSH_DB"
  echo -e "\n  $CYAN Every active SSH account can use the configured DNSTT backend.$NC"
  pause
}
delete_account() {
  header
  echo -e "  $WHITE DELETE DNSTT ACCOUNT$NC"
  echo -e "  $YELLOW This also deletes the same user's ordinary SSH access.$NC\n"
  local username confirm tmp
  read -r -p "  Username: " username
  [[ -n $username ]] || return
  if ! awk -F'|' -v u="$username" '$1==u{f=1}END{exit !f}' "$SSH_DB" 2>/dev/null; then
    echo -e "  $RED No matching SSH account record.$NC"; pause; return
  fi
  read -r -p "  Type DELETE to confirm: " confirm
  [[ $confirm == DELETE ]] || { echo "  Cancelled."; pause; return; }
  pkill -u "$username" 2>/dev/null || true
  userdel -r "$username" 2>/dev/null || true
  tmp=$(mktemp); awk -F'|' -v u="$username" '$1!=u' "$SSH_DB" > "$tmp"; cat "$tmp" > "$SSH_DB"; rm -f "$tmp"
  if [[ -f /etc/squid/passwd ]] && command -v htpasswd >/dev/null 2>&1; then htpasswd -D /etc/squid/passwd "$username" >/dev/null 2>&1 || true; fi
  echo -e "  $GREEN Shared SSH/DNSTT account deleted.$NC"; pause
}
server_status() {
  header; echo -e "  $WHITE DNSTT SERVER STATUS$NC\n"; show_config; echo
  systemctl is-active --quiet dnstt.service && echo -e "  DNSTT: $GREEN Active$NC" || echo -e "  DNSTT: $RED Inactive$NC"
  systemctl is-active --quiet dropbear.service && echo -e "  Dropbear: $GREEN Active$NC" || echo -e "  Dropbear: $RED Inactive$NC"
  systemctl is-active --quiet badvpn.service && echo -e "  UDPGW: $GREEN Active$NC" || echo -e "  UDPGW: $YELLOW Inactive$NC"
  pause
}
while true; do
  header
  echo -e "  $GREEN 1) Create DNSTT Account$NC"
  echo -e "  $GREEN 2) List DNSTT-Compatible Accounts$NC"
  echo -e "  $GREEN 3) Delete DNSTT Account (also removes SSH login)$NC"
  echo -e "  $GREEN 4) View DNSTT Server Configuration / Status$NC"
  echo -e "  $YELLOW 0) Back to Main Menu$NC\n"
  read -r -p "  Select option [0-4]: " option
  case "$option" in
    1) create_account ;;
    2) list_accounts ;;
    3) delete_account ;;
    4) server_status ;;
    0) exit 0 ;;
    *) ;;
  esac
done
