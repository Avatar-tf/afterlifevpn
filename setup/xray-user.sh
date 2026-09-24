#!/bin/bash

# Xray/VMess User Management Script
# Part of AFTERLIFE VPN

XRAY_CONFIG="/usr/local/etc/xray/config.json"
USERS_FILE="/usr/local/afterlifevpn/users/xray_users.txt"
DOMAIN=$(grep DOMAIN /usr/local/afterlifevpn/config.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"')

# Ensure users directory exists
mkdir -p /usr/local/afterlifevpn/users

# Generate UUID
generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

# Add VMess user
add_vmess_user() {
    local username="$1"
    local expiry_days="${2:-30}"
    local uuid=$(generate_uuid)
    local expiry_date=$(date -d "+${expiry_days} days" +"%Y-%m-%d")
    
    # Check if user already exists
    if grep -q "^${username}:" "$USERS_FILE" 2>/dev/null; then
        echo "Error: User '$username' already exists"
        return 1
    fi
    
    # Add user to xray config
    local temp_config=$(mktemp)
    jq --arg uuid "$uuid" --arg email "$username" \
        '.inbounds[0].settings.clients += [{"id": $uuid, "email": $email}]' \
        "$XRAY_CONFIG" > "$temp_config"
    
    if [ $? -eq 0 ]; then
        mv "$temp_config" "$XRAY_CONFIG"
        systemctl reload xray
        
        # Save user info
        echo "${username}:${uuid}:${expiry_date}" >> "$USERS_FILE"
        
        echo "✓ VMess user created successfully"
        echo ""
        echo "Username: $username"
        echo "UUID: $uuid"
        echo "Expiry: $expiry_date"
        echo ""
        
        # Generate connection details
        show_vmess_config "$username" "$uuid"
    else
        rm -f "$temp_config"
        echo "Error: Failed to update Xray config"
        return 1
    fi
}

# Delete VMess user
delete_vmess_user() {
    local username="$1"
    
    # Check if user exists
    if ! grep -q "^${username}:" "$USERS_FILE" 2>/dev/null; then
        echo "Error: User '$username' not found"
        return 1
    fi
    
    # Get UUID
    local uuid=$(grep "^${username}:" "$USERS_FILE" | cut -d':' -f2)
    
    # Remove from xray config
    local temp_config=$(mktemp)
    jq --arg uuid "$uuid" \
        '.inbounds[0].settings.clients = [.inbounds[0].settings.clients[] | select(.id != $uuid)]' \
        "$XRAY_CONFIG" > "$temp_config"
    
    if [ $? -eq 0 ]; then
        mv "$temp_config" "$XRAY_CONFIG"
        systemctl reload xray
        
        # Remove from users file
        sed -i "/^${username}:/d" "$USERS_FILE"
        
        echo "✓ VMess user '$username' deleted successfully"
    else
        rm -f "$temp_config"
        echo "Error: Failed to update Xray config"
        return 1
    fi
}

# List VMess users
list_vmess_users() {
    if [ ! -f "$USERS_FILE" ] || [ ! -s "$USERS_FILE" ]; then
        echo "No VMess users found"
        return 0
    fi
    
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                    VMess Users                         ║"
    echo "╠════════════════════════════════════════════════════════╣"
    printf "║ %-20s %-15s %-15s ║\n" "Username" "Expiry Date" "Status"
    echo "╠════════════════════════════════════════════════════════╣"
    
    while IFS=: read -r username uuid expiry; do
        local status="Active"
        local today=$(date +%s)
        local exp_timestamp=$(date -d "$expiry" +%s 2>/dev/null)
        
        if [ -n "$exp_timestamp" ] && [ "$today" -gt "$exp_timestamp" ]; then
            status="Expired"
        fi
        
        printf "║ %-20s %-15s %-15s ║\n" "$username" "$expiry" "$status"
    done < "$USERS_FILE"
    
    echo "╚════════════════════════════════════════════════════════╝"
}

# Show VMess configuration
show_vmess_config() {
    local username="$1"
    local uuid="$2"
    local server_ip=$(curl -s ifconfig.me)
    local port="8443"
    
    echo "════════════════════════════════════════════════════════"
    echo "  VMess Configuration for: $username"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "Server: $server_ip"
    echo "Port: $port"
    echo "UUID: $uuid"
    echo "AlterID: 0"
    echo "Security: auto"
    echo "Network: ws"
    echo "Path: /vmess"
    echo "TLS: tls"
    echo "SNI: $DOMAIN"
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  VMess Link"
    echo "════════════════════════════════════════════════════════"
    
    # Generate VMess link (base64 encoded JSON)
    local vmess_json=$(cat <<EOF
{
  "v": "2",
  "ps": "$username",
  "add": "$server_ip",
  "port": "$port",
  "id": "$uuid",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "$DOMAIN",
  "path": "/vmess",
  "tls": "tls",
  "sni": "$DOMAIN"
}
EOF
)
    
    local vmess_link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"
    echo "$vmess_link"
    echo ""
    
    # Generate QR code if available
    if command -v qrencode &> /dev/null; then
        echo "════════════════════════════════════════════════════════"
        echo "  QR Code"
        echo "════════════════════════════════════════════════════════"
        qrencode -t ANSIUTF8 "$vmess_link"
    fi
}

# Extend user expiry
extend_vmess_user() {
    local username="$1"
    local add_days="${2:-30}"
    
    if ! grep -q "^${username}:" "$USERS_FILE" 2>/dev/null; then
        echo "Error: User '$username' not found"
        return 1
    fi
    
    local uuid=$(grep "^${username}:" "$USERS_FILE" | cut -d':' -f2)
    local old_expiry=$(grep "^${username}:" "$USERS_FILE" | cut -d':' -f3)
    local new_expiry=$(date -d "$old_expiry +${add_days} days" +"%Y-%m-%d")
    
    sed -i "s/^${username}:${uuid}:${old_expiry}$/${username}:${uuid}:${new_expiry}/" "$USERS_FILE"
    
    echo "✓ User '$username' extended to $new_expiry"
}

# Main function
case "$1" in
    add)
        add_vmess_user "$2" "$3"
        ;;
    delete)
        delete_vmess_user "$2"
        ;;
    list)
        list_vmess_users
        ;;
    show)
        if grep -q "^$2:" "$USERS_FILE" 2>/dev/null; then
            uuid=$(grep "^$2:" "$USERS_FILE" | cut -d':' -f2)
            show_vmess_config "$2" "$uuid"
        else
            echo "Error: User '$2' not found"
            exit 1
        fi
        ;;
    extend)
        extend_vmess_user "$2" "$3"
        ;;
    *)
        echo "Usage: $0 {add|delete|list|show|extend} [username] [days]"
        echo ""
        echo "Commands:"
        echo "  add <username> [days]     - Add new VMess user (default: 30 days)"
        echo "  delete <username>         - Delete VMess user"
        echo "  list                      - List all VMess users"
        echo "  show <username>           - Show user configuration"
        echo "  extend <username> [days]  - Extend user expiry (default: 30 days)"
        exit 1
        ;;
esac
