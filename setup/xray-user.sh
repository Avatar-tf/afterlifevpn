#!/bin/bash

XRAY_CONFIG="/usr/local/etc/xray/config.json"
USER_DB="/usr/local/afterlifevpn/users/xray_users.txt"

# Ensure database exists
mkdir -p /usr/local/afterlifevpn/users
touch $USER_DB

# Function: Add VMess user
add_vmess_user() {
    local username=$1
    local days=$2
    local uuid=$(cat /proc/sys/kernel/random/uuid)
    local expiry=$(date -d "+$days days" +%Y-%m-%d)
    
    # Add to Xray config
    python3 <<EOF
import json
with open('$XRAY_CONFIG', 'r') as f:
    config = json.load(f)

# Add client
config['inbounds'][0]['settings']['clients'].append({
    'id': '$uuid',
    'alterId': 0,
    'email': '$username'
})

with open('$XRAY_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
EOF
    
    # Save to database
    echo "$username|$uuid|$expiry|$(date +%Y-%m-%d)" >> $USER_DB
    
    # Restart Xray
    systemctl restart xray
    
    echo "$uuid"
}

# Function: Delete VMess user
delete_vmess_user() {
    local username=$1
    
    # Remove from Xray config
    python3 <<EOF
import json
with open('$XRAY_CONFIG', 'r') as f:
    config = json.load(f)

# Remove client
config['inbounds'][0]['settings']['clients'] = [
    c for c in config['inbounds'][0]['settings']['clients']
    if c.get('email') != '$username'
]

with open('$XRAY_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
EOF
    
    # Remove from database
    sed -i "/^$username|/d" $USER_DB
    
    # Restart Xray
    systemctl restart xray
}

# Function: List VMess users
list_vmess_users() {
    if [ -f $USER_DB ]; then
        cat $USER_DB
    fi
}

# Execute based on argument
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
esac
