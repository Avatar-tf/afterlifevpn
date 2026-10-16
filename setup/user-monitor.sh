#!/usr/bin/env bash
# AFTERLIFE VPN User Monitor launcher. No service or firewall changes.
MONITOR_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 1
if ! command -v python3 >/dev/null 2>&1; then
    printf "User Monitor requires Python 3.\n"
    read -r -p "Press Enter to return..." _ || true
    exit 1
fi
if [[ ! -s "$MONITOR_DIR/user-monitor.py" ]]; then
    printf "User Monitor display module missing: %s/user-monitor.py\n" "$MONITOR_DIR"
    printf "Download both monitor files from the AfterlifeVPN main branch.\n"
    read -r -p "Press Enter to return..." _ || true
    exit 1
fi
exec python3 "$MONITOR_DIR/user-monitor.py"
