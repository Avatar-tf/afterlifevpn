#!/usr/bin/env bash
set -Eeuo pipefail

# AFTERLIFE VPN network tuning. Settings are isolated in /etc/sysctl.d.
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
CONFIG_DIR="/etc/sysctl.d"
CONFIG_FILE="$CONFIG_DIR/99-afterlife-network.conf"
BACKUP_DIR="/root/afterlife-backup"

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        echo -e "${RED}Run this utility as root.${NC}"
        exit 1
    fi
}

write_settings() {
    local label="$1"; shift
    local tmp
    mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"
    if [[ -f "$CONFIG_FILE" && ! -f "$BACKUP_DIR/99-afterlife-network.conf.original" ]]; then
        cp -a "$CONFIG_FILE" "$BACKUP_DIR/99-afterlife-network.conf.original"
    fi
    tmp=$(mktemp "$CONFIG_DIR/.afterlife-network.XXXXXX")
    {
        echo "# AFTERLIFE VPN network settings: $label"
        echo "# Managed by /usr/local/afterlifevpn/setup/netf.sh"
        printf '%s\n' "$@"
    } > "$tmp"
    chmod 644 "$tmp"
    mv "$tmp" "$CONFIG_FILE"
    sysctl --load="$CONFIG_FILE"
    echo -e "${GREEN}Applied and persisted: $label${NC}"
}

apply_all_optimizations() {
    write_settings "all optimizations" \
        "net.ipv4.tcp_fastopen = 3" \
        "net.core.rmem_max = 134217728" \
        "net.core.wmem_max = 134217728" \
        "net.core.rmem_default = 65536" \
        "net.core.wmem_default = 65536" \
        "net.ipv4.tcp_rmem = 4096 87380 67108864" \
        "net.ipv4.tcp_wmem = 4096 65536 67108864" \
        "net.ipv4.ip_forward = 1" \
        "net.ipv6.conf.all.forwarding = 1" \
        "net.netfilter.nf_conntrack_max = 262144" \
        "net.ipv4.tcp_slow_start_after_idle = 0" \
        "net.ipv4.tcp_no_metrics_save = 1" \
        "net.ipv4.tcp_sack = 1" \
        "net.ipv4.tcp_window_scaling = 1" \
        "net.ipv4.tcp_moderate_rcvbuf = 1" \
        "net.ipv4.tcp_keepalive_time = 600" \
        "net.ipv4.tcp_keepalive_intvl = 60" \
        "net.ipv4.tcp_keepalive_probes = 10" \
        "net.core.somaxconn = 65535" \
        "net.core.netdev_max_backlog = 65535" \
        "net.ipv4.conf.all.rp_filter = 1" \
        "net.ipv4.conf.default.rp_filter = 1"
}

enable_fast_open() { write_settings "TCP Fast Open" "net.ipv4.tcp_fastopen = 3"; }

optimize_buffers() {
    write_settings "network buffers" \
        "net.core.rmem_max = 134217728" "net.core.wmem_max = 134217728" \
        "net.core.rmem_default = 65536" "net.core.wmem_default = 65536" \
        "net.ipv4.tcp_rmem = 4096 87380 67108864" \
        "net.ipv4.tcp_wmem = 4096 65536 67108864"
}

enable_forwarding() {
    write_settings "IP forwarding" "net.ipv4.ip_forward = 1" "net.ipv6.conf.all.forwarding = 1"
}

optimize_conntrack() {
    write_settings "connection tracking" "net.netfilter.nf_conntrack_max = 262144"
}

show_settings() {
    echo -e "\n${BLUE}Current network settings${NC}"
    sysctl net.ipv4.tcp_fastopen net.core.rmem_max net.core.wmem_max \
        net.ipv4.ip_forward net.ipv6.conf.all.forwarding \
        net.netfilter.nf_conntrack_max net.core.somaxconn 2>/dev/null || true
    echo -e "\n${YELLOW}AFTERLIFE configuration file:${NC} $CONFIG_FILE"
    if [[ -f "$CONFIG_FILE" ]]; then cat "$CONFIG_FILE"; else echo "No AFTERLIFE network tuning file is installed."; fi
}

reset_defaults() {
    echo -e "${YELLOW}This removes only AFTERLIFE-managed sysctl settings; unrelated system settings are preserved.${NC}"
    read -r -p "Continue? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; return; }
    rm -f "$CONFIG_FILE"
    if [[ -f "$BACKUP_DIR/99-afterlife-network.conf.original" ]]; then
        cp -a "$BACKUP_DIR/99-afterlife-network.conf.original" "$CONFIG_FILE"
    fi
    sysctl --system
    echo -e "${GREEN}AFTERLIFE network tuning removed; sysctl configuration reloaded.${NC}"
}

main() {
    require_root
    while true; do
        clear
        echo -e "${BLUE}================================${NC}"
        echo -e "${GREEN}   Network Optimization${NC}"
        echo -e "${BLUE}================================${NC}"
        echo
        echo "1. Apply All Optimizations (Recommended)"
        echo "2. Enable TCP Fast Open"
        echo "3. Optimize Network Buffers"
        echo "4. Enable IP Forwarding"
        echo "5. Optimize Connection Tracking"
        echo "6. Show Current Settings"
        echo "7. Reset AFTERLIFE Network Settings"
        echo "0. Back to Menu"
        echo
        read -r -p "Select option: " option
        case "$option" in
            1) apply_all_optimizations ;;
            2) enable_fast_open ;;
            3) optimize_buffers ;;
            4) enable_forwarding ;;
            5) optimize_conntrack ;;
            6) show_settings ;;
            7) reset_defaults ;;
            0) return 0 ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac
        echo
        read -r -p "Press Enter to continue..." _
    done
}
main "$@"
