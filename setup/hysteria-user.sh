#!/bin/bash

USER_DB="/usr/local/afterlifevpn/users/hysteria_users.txt"
HYSTERIA_CONFIG="/etc/hysteria/config.yaml"

# Ensure database exists
mkdir -p /usr/local/afterlifevpn/users
touch $USER_DB

# Function: Add Hysteria user
add_hysteria_user() {
    local username=$1
    local days=$2
    local password=$(openssl rand -base64 12)
    local expiry=$(date -d "+$days days" +%Y-%m-%d)
    
    # Save to database
    echo "$username|$password|$expiry|$(date +%Y-%m-%d)" >> $USER_DB
    
    echo "$password"
}

# Function: Delete Hysteria user
delete_hysteria_user() {
    local username=$1
    sed -i "/^$username|/d" $USER_DB
}

# Function: List Hysteria users
list_hysteria_users() {
    if [ -f $USER_DB ]; then
        cat $USER_DB
    fi
}

# Function: Get user password
get_user_password() {
    local username=$1
    grep "^$username|" $USER_DB | cut -d'|' -f2
}

# Execute based on argument
case "$1" in
    add)
        add_hysteria_user "$2" "$3"
        ;;
    delete)
        delete_hysteria_user "$2"
        ;;
    list)
        list_hysteria_users
        ;;
    getpass)
        get_user_password "$2"
        ;;
esac
