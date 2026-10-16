#!/usr/bin/env bash
# AFTERLIFE VPN monitor preview — READ ONLY. No bans, no counters invented.
set -u
pause(){ read -r -p "Press Enter..." _ || true; }
ssh_view(){
  echo "=== CURRENT SSH SOCKETS (NOT USER IDENTITIES) ==="
  printf '%-11s %-43s %s\n' Protocol Remote_IP Local_Port
  ss -Htn state established 2>/dev/null | awk '
  { p=$4;sub(/^.*:/,"",p);
    if(p=="22"||p=="109"){
      ip=$5;sub(/:[0-9]+$/,"",ip);gsub(/^\[|\]$/,"",ip);
      printf "%-11s %-43s %s\n",(p=="22"?"OpenSSH":"Dropbear"),ip,p;n++
    }
  }END{if(!n)print "No active SSH TCP sessions observed."}'
  echo "Socket IPs cannot reliably identify usernames; SSH-WebSocket may show localhost."
}
xray_view(){
  echo "=== XRAY HISTORICAL IPs (NOT ONLINE OR BANDWIDTH) ==="
  if [[ ! -r /var/log/xray/access.log ]]; then
    echo "Xray access.log unavailable."; return
  fi
  python3 - <<'PY'
from collections import defaultdict
import re
ips=defaultdict(set)
for line in open('/var/log/xray/access.log', errors='replace'):
    if 'accepted' not in line: continue
    src=re.search(r'from\s+(\S+)',line)
    user=re.search(r'email:\s*(\S+)',line)
    if src and user:
        host=src.group(1).rsplit(':',1)[0].strip('[]')
        ips[user.group(1)].add(host)
if not ips: print('No parseable accepted Xray connections yet.')
for user,addresses in sorted(ips.items()):
    print(user, '| historical IPs:',len(addresses),'|',', '.join(sorted(addresses)[:4]))
print('Historical log entries do NOT establish simultaneous sessions.')
PY
}
hysteria_view(){
  echo "=== HYSTERIA / SLOWDNS STATUS ==="
  for svc in hysteria-server dnstt; do
    printf '%s: ' "$svc"; systemctl is-active "$svc" 2>/dev/null || true
  done
  echo "Per-user live IP and bandwidth counters are not available in current setup."
}
while :; do
  clear
  echo "AFTERLIFE VPN — MONITOR PREVIEW (READ ONLY)"
  echo "1) SSH / Dropbear connected socket IPs"
  echo "2) Xray historical account IPs"
  echo "3) Hysteria and SlowDNS services"
  echo "4) View all"
  echo "0) Back"
  echo "Bandwidth: NOT YET COLLECTED. No blocking."
  read -r -p "Select: " choice || exit 0
  case "$choice" in
    1) ssh_view; pause;;
    2) xray_view; pause;;
    3) hysteria_view; pause;;
    4) ssh_view;xray_view;hysteria_view;pause;;
    0) exit 0;;
  esac
done
