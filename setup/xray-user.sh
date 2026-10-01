#!/bin/bash
XRAY_CONFIG="/usr/local/etc/xray/config.json"
USERS_FILE="/usr/local/afterlifevpn/users/xray_users.txt"
DOMAIN=$(grep '^DOMAIN=' /usr/local/afterlifevpn/config.conf 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'")
mkdir -p /usr/local/afterlifevpn/users
touch "$USERS_FILE"

generate_uuid() { cat /proc/sys/kernel/random/uuid; }

add_to_xray() {
    local uuid="$1" email="$2" tmp
    tmp=$(mktemp)
    jq --arg uuid "$uuid" --arg email "$email" \
        '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": $uuid, "email": $email, "alterId": 0}]' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
}

remove_from_xray() {
    local uuid="$1" tmp
    tmp=$(mktemp)
    jq --arg uuid "$uuid" \
        '.inbounds |= map(if .protocol=="vmess" then .settings.clients |= map(select(.id != $uuid)) else . end)' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
}

show_vmess_config() {
    local username="$1" uuid="$2" expiry="$3"
    local host="$DOMAIN"
    [[ -z "\( host" ]] && host= \)(curl -4 -s --max-time 5 ifconfig.me)
    echo "════════════════════════════════════════════════════════"
    echo "  Xray VMess Account"
    echo "  Remarks  : $username"
    echo "  Host/SNI : $host"
    echo "  UUID     : $uuid"
    echo "  Expired  : ${expiry:-n/a}"
    echo "  Port TLS : 443"
    echo "  Network  : ws"
    echo "  Path     : /vmess"
    echo "════════════════════════════════════════════════════════"
    local json link
    json=$(printf '{"v":"2","ps":"%s","add":"%s","port":"443","id":"%s","aid":"0","scy":"auto","net":"ws","type":"none","host":"%s","path":"/vmess","tls":"tls","sni":"%s"}' \
        "$username" "$host" "$uuid" "$host" "$host")
    link="vmess://$(printf '%s' "$json" | base64 -w 0)"
    echo "$link"
    echo
    command -v qrencode >/dev/null 2>&1 && qrencode -t ANSIUTF8 "$link"
}

add_vmess_user() {
    local username="$1" days="${2:-30}" uuid expiry
    [[ -z "$username" ]] && { echo "Username required"; return 1; }
    grep -q "^${username}:" "$USERS_FILE" && { echo "User exists"; return 1; }
    [[ -f "$XRAY_CONFIG" ]] || { echo "Run vmess.sh first"; return 1; }
    uuid=$(generate_uuid)
    expiry=\( (date -d "+ \){days} days" +%Y-%m-%d)
    add_to_xray "$uuid" "$username" || { echo "Failed to edit config"; return 1; }
    systemctl restart xray
    echo "\( {username}: \){uuid}:${expiry}" >> "$USERS_FILE"
    echo "User saved"
    show_vmess_config "$username" "$uuid" "$expiry"
}

delete_vmess_user() {
    local username="$1" uuid
    uuid=\( (grep "^ \){username}:" "$USERS_FILE" | cut -d: -f2)
    [[ -z "$uuid" ]] && { echo "Not found"; return 1; }
    remove_from_xray "$uuid"
    systemctl restart xray
    sed -i "/^${username}:/d" "$USERS_FILE"
    echo "Deleted $username"
}

list_vmess_users() {
    [[ ! -s "$USERS_FILE" ]] && { echo "No users"; return; }
    while IFS=: read -r u id exp; do
        echo "$u  $exp  $id"
    done < "$USERS_FILE"
}

case "$1" in
    add) add_vmess_user "$2" "$3" ;;
    delete) delete_vmess_user "$2" ;;
    list) list_vmess_users ;;
    show)
        uuid=$(grep "^$2:" "$USERS_FILE" | cut -d: -f2)
        exp=$(grep "^$2:" "$USERS_FILE" | cut -d: -f3)
        [[ -z "$uuid" ]] && { echo "Not found"; exit 1; }
        show_vmess_config "$2" "$uuid" "$exp"
        ;;
    *) echo "Usage: $0 {add|delete|list|show} [username] [days]" ;;
esac