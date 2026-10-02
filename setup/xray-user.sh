#!/bin/bash
XRAY_CONFIG="/usr/local/etc/xray/config.json"
USERS_FILE="/usr/local/afterlifevpn/users/xray_users.txt"
DOMAIN=$(grep '^DOMAIN=' /usr/local/afterlifevpn/config.conf 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'")
mkdir -p /usr/local/afterlifevpn/users
touch "$USERS_FILE"

add_to_xray() {
    local uuid="$1" email="$2" tmp
    tmp=$(mktemp)
    jq --arg uuid "$uuid" --arg email "$email" \
        '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": $uuid, "email": $email, "alterId": 0}]' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
    chmod 644 "$XRAY_CONFIG"
}

remove_from_xray() {
    local uuid="$1" tmp
    tmp=$(mktemp)
    jq --arg uuid "$uuid" \
        '.inbounds |= map(if .protocol=="vmess" then .settings.clients |= map(select(.id != $uuid)) else . end)' \
        "$XRAY_CONFIG" > "$tmp" && mv "$tmp" "$XRAY_CONFIG"
    chmod 644 "$XRAY_CONFIG"
}

show_vmess_config() {
    local username="$1"
    local uuid="$2"
    local expiry="$3"
    local host="$DOMAIN"
    if [[ -z "$host" ]]; then
        host=$(curl -4 -s --max-time 5 ifconfig.me)
    fi
    echo "Host/SNI : $host"
    echo "UUID     : $uuid"
    echo "Expired  : ${expiry:-n/a}"
    echo "Port     : 443"
    echo "Path     : /vmess"
    local json link
    json=$(printf '{"v":"2","ps":"%s","add":"%s","port":"443","id":"%s","aid":"0","scy":"auto","net":"ws","type":"none","host":"%s","path":"/vmess","tls":"tls","sni":"%s"}' \
        "$username" "$host" "$uuid" "$host" "$host")
    link="vmess://$(printf '%s' "$json" | base64 -w 0)"
    echo "$link"
    echo
    if command -v qrencode >/dev/null 2>&1; then
        qrencode -t ANSIUTF8 "$link"
    fi
}

add_vmess_user() {
    local username="$1"
    local days="${2:-30}"
    local uuid expiry
    if [[ -z "$username" ]]; then
        echo "Username required"
        return 1
    fi
    if grep -q "^${username}:" "$USERS_FILE"; then
        echo "User exists"
        return 1
    fi
    if [[ ! -f "$XRAY_CONFIG" ]]; then
        echo "Run vmess.sh first"
        return 1
    fi
    uuid=$(cat /proc/sys/kernel/random/uuid)
    expiry=\( (date -d "+ \){days} days" +%Y-%m-%d)
    add_to_xray "$uuid" "$username" || { echo "Failed to edit config"; return 1; }
    systemctl restart xray
    echo "\( {username}: \){uuid}:${expiry}" >> "$USERS_FILE"
    echo "User saved"
    show_vmess_config "$username" "$uuid" "$expiry"
}

delete_vmess_user() {
    local username="$1"
    local uuid
    uuid=\( (grep "^ \){username}:" "$USERS_FILE" | cut -d: -f2)
    if [[ -z "$uuid" ]]; then
        echo "Not found"
        return 1
    fi
    remove_from_xray "$uuid"
    systemctl restart xray
    sed -i "/^${username}:/d" "$USERS_FILE"
    echo "Deleted $username"
}

list_vmess_users() {
    if [[ ! -s "$USERS_FILE" ]]; then
        echo "No users"
        return
    fi
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
        if [[ -z "$uuid" ]]; then
            echo "Not found"
            exit 1
        fi
        show_vmess_config "$2" "$uuid" "$exp"
        ;;
    *) echo "Usage: $0 {add|delete|list|show} [username] [days]" ;;
esac