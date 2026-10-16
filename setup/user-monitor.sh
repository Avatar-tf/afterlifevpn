#!/usr/bin/env bash
# AFTERLIFE VPN - optional read-only monitoring preview.
# No firewall, service, user, or account settings are modified.
set -u

monitor_pause() { read -r -p 'Press Enter to return...' _ || true; }
monitor_status() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        printf 'active'
    else
        printf 'inactive'
    fi
}

monitor_ssh() {
    printf '\n=== SSH / DROPBEAR: CURRENT CONNECTIONS ===\n'
    printf 'OpenSSH: %s | Dropbear: %s\n' "$(monitor_status ssh)" "$(monitor_status dropbear)"
    printf '\n%-12s %-42s %s\n' SERVICE REMOTE_IP SERVER_PORT
    if command -v ss >/dev/null 2>&1; then
        ss -Htn state established 2>/dev/null | awk '
            NF>=4 {
                port=$3; sub(/^.*:/, "", port)
                if (port == "22" || port == "109") {
                    ip=$4; sub(/:[0-9]+$/, "", ip)
                    gsub(/^\[|\]$/, "", ip)
                    printf "%-12s %-42s %s\n", (port=="22"?"OpenSSH":"Dropbear"), ip, port
                    count++
                }
            }
            END { if (!count) print "No established SSH TCP sockets observed." }
        '
    else
        echo 'Socket inspection unavailable: ss not installed.'
    fi
    printf '\nInteractive SSH logins (when recorded by the OS):\n'
    if command -v who >/dev/null 2>&1; then
        sessions=$(who 2>/dev/null)
        if [[ -n "$sessions" ]]; then printf '%s\n' "$sessions" | head -n 20
        else echo 'No interactive logins reported.'; fi
    else
        echo 'Login listing unavailable.'
    fi
    echo 'NOTE: Socket IPs are not confirmed account identities or device counts.'
    echo 'SSH-over-WebSocket may show the local proxy address; tunnel-only users may not appear in who.'
}

monitor_xray() {
    printf '\n=== XRAY: HISTORICAL ACCOUNT IPs ===\n'
    printf 'Xray service: %s\n' "$(monitor_status xray)"
    local logfile=/var/log/xray/access.log
    if [[ ! -r "$logfile" ]]; then
        echo 'No readable /var/log/xray/access.log; account/IP history unavailable.'
        echo 'No Xray logging settings were changed.'
        return
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echo 'Python 3 missing; log summary unavailable.'
        return
    fi
    # Only inspect recent lines to avoid expensive reads of very large logs.
    tail -n 5000 "$logfile" 2>/dev/null | python3 -c '
import re, sys
from collections import defaultdict
seen = defaultdict(set)
for line in sys.stdin:
    if "accepted" not in line.lower():
        continue
    u = re.search(r"\bemail:\s*([^\s]+)", line)
    ip = re.search(r"\bfrom\s+(\[[0-9a-fA-F:]+\]|[0-9.]+):[0-9]+", line)
    if u and ip:
        seen[u.group(1)].add(ip.group(1).strip("[]"))
if not seen:
    print("No account/IP pairs found in the last 5,000 log lines.")
else:
    print("Account | Distinct historical IPs | Example IPs")
    for account, ips in sorted(seen.items()):
        print("{} | {} | {}".format(account, len(ips), ", ".join(sorted(ips)[:4])))
print("NOTE: Historical IPs are not proof of simultaneous online sessions or account sharing.")
'
}

monitor_hysteria() {
    printf '\n=== HYSTERIA / SLOWDNS ===\n'
    printf 'Hysteria: %s | SlowDNS: %s\n' "$(monitor_status hysteria-server)" "$(monitor_status dnstt)"
    local userfile=/usr/local/afterlifevpn/users/hysteria_users.txt
    if [[ -r "$userfile" ]]; then
        awk 'NF {n++} END {printf "Configured Hysteria accounts: %d\n",n}' "$userfile"
    fi
    echo 'Current Hysteria setup does not expose reliable per-user live IP/byte accounting.'
}

monitor_host_traffic() {
    printf '\n=== SERVER TRAFFIC (NOT PER-USER) ===\n'
    local iface rx tx
    iface=$(ip -4 route show default 2>/dev/null | awk '/^default / {for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1);exit}}')
    if [[ -z "$iface" || ! -r "/sys/class/net/$iface/statistics/rx_bytes" ]]; then
        echo 'Main network interface not found.'
        return
    fi
    rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes")
    tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes")
    if command -v numfmt >/dev/null 2>&1; then
        rx=$(numfmt --to=iec-i --suffix=B "$rx")
        tx=$(numfmt --to=iec-i --suffix=B "$tx")
    fi
    printf 'Interface: %s | Received: %s | Sent: %s\n' "$iface" "$rx" "$tx"
    echo 'Totals are since network-interface initialization, include every service, and are NOT individual user quotas.'
}

while true; do
    clear
    echo '========== AFTERLIFE VPN — USER MONITOR =========='
    echo 'Preview: read-only. No blocking, user tracking agent or service changes.'
    echo '1) SSH / Dropbear connected IPs'
    echo '2) Xray historical account IPs'
    echo '3) Hysteria / SlowDNS overview'
    echo '4) Server-wide bandwidth totals'
    echo '5) View all'
    echo '0) Back'
    read -r -p 'Select [0-5]: ' answer || exit 0
    case "$answer" in
        1) monitor_ssh; monitor_pause ;;
        2) monitor_xray; monitor_pause ;;
        3) monitor_hysteria; monitor_pause ;;
        4) monitor_host_traffic; monitor_pause ;;
        5) monitor_ssh; monitor_xray; monitor_hysteria; monitor_host_traffic; monitor_pause ;;
        0) exit 0 ;;
        *) echo 'Unknown option.'; monitor_pause ;;
    esac
done
