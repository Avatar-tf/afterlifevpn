#!/bin/bash

# AFTERLIFE VPN - Automated Account Expiry
# Runs daily at 00:00 (Midnight) via Cron

TODAY=$(date +%s)
RESTART_XRAY=0
RESTART_HYS=0

# 1. Process Xray Users
if [ -f /usr/local/afterlifevpn/users/xray_users.txt ]; then
    while IFS='|' read -r user uuid exp created; do
        EXP_SEC=$(date -d "$exp" +%s 2>/dev/null)
        if [[ -n "$EXP_SEC" ]] && [[ $TODAY -ge $EXP_SEC ]]; then
            # Surgically remove from Xray config
            jq --arg u "$user" --arg id "$uuid" '
              .inbounds |= map(
                if .settings.clients then
                  .settings.clients |= map(select(.email != $u and .id != $id))
                else
                  .
                end
              )
            ' /usr/local/etc/xray/config.json > /tmp/x_clean.json && mv /tmp/x_clean.json /usr/local/etc/xray/config.json
            
            # Remove from local database
            sed -i "/^${user}|/d" /usr/local/afterlifevpn/users/xray_users.txt
            RESTART_XRAY=1
        fi
    done < /usr/local/afterlifevpn/users/xray_users.txt
fi

# 2. Process SSH Users
if [ -f /usr/local/afterlifevpn/users/ssh_users.txt ]; then
    while IFS='|' read -r user pass exp created max quota; do
        EXP_SEC=$(date -d "$exp" +%s 2>/dev/null)
        if [[ -n "$EXP_SEC" ]] && [[ $TODAY -ge $EXP_SEC ]]; then
            # Kill active connections and delete system user
            pkill -u "$user" 2>/dev/null
            userdel -r "$user" 2>/dev/null
            
            # Remove from local database
            sed -i "/^${user}|/d" /usr/local/afterlifevpn/users/ssh_users.txt
        fi
    done < /usr/local/afterlifevpn/users/ssh_users.txt
fi

# 3. Process Hysteria Users
if [ -f /usr/local/afterlifevpn/users/hysteria_users.txt ]; then
    while IFS='|' read -r user pass exp created; do
        EXP_SEC=$(date -d "$exp" +%s 2>/dev/null)
        if [[ -n "$EXP_SEC" ]] && [[ $TODAY -ge $EXP_SEC ]]; then
            # Remove from local database
            sed -i "/^${user}|/d" /usr/local/afterlifevpn/users/hysteria_users.txt
            
            # Remove from Hysteria config (if using inline passwords)
            sed -i "/password: $pass/d" /etc/hysteria/config.yaml 2>/dev/null
            RESTART_HYS=1
        fi
    done < /usr/local/afterlifevpn/users/hysteria_users.txt
fi

# Restart services ONLY if users were actually deleted to prevent unnecessary downtime
if [ "$RESTART_XRAY" -eq 1 ]; then systemctl restart xray; fi
if [ "$RESTART_HYS" -eq 1 ]; then systemctl restart hysteria-server.service; fi
