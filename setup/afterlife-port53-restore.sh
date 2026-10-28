#!/usr/bin/env bash
# Restore only AfterlifeVPN-owned legacy UDP/53 NAT rules.
set -euo pipefail
STATE=/usr/local/afterlifevpn/port53-mode.conf
CHAIN=AFTERLIFE_MUX
IPT=iptables-legacy
[[ $EUID -eq 0 ]] || { echo 'Must run as root' >&2; exit 1; }
command -v "$IPT" >/dev/null || { echo 'iptables-legacy missing' >&2; exit 1; }
[[ -r $STATE ]] || exit 0  # New installations may not have selected a mode.
mode=$(sed -n 's/^MODE=//p' "$STATE" | tail -n 1)
case "$mode" in slowdns|shared_hy|shared_udp|shared_all) ;; hysteria|none|reset|'') exit 0 ;; *) echo 'Invalid Port 53 mode' >&2; exit 1 ;; esac
expected=("-A $CHAIN -p udp -m length --length 0:300 -j REDIRECT --to-ports 5300")
case "$mode" in
  slowdns) expected=("-A $CHAIN -p udp -j REDIRECT --to-ports 5300") ;;
  shared_hy) expected+=("-A $CHAIN -p udp -j REDIRECT --to-ports 4430") ;;
  shared_udp) expected+=("-A $CHAIN -p udp -j REDIRECT --to-ports 7300") ;;
  shared_all) expected+=("-A $CHAIN -p udp -m length --length 301:1199 -j REDIRECT --to-ports 7300" "-A $CHAIN -p udp -j REDIRECT --to-ports 4430") ;;
esac
if "$IPT" -t nat -S "$CHAIN" >/dev/null 2>&1; then
  actual=$("$IPT" -t nat -S "$CHAIN" | tail -n +2)
  wanted=$(printf '%s\n' "${expected[@]}")
  [[ "$actual" == "$wanted" ]] || { echo 'Existing Afterlife rules differ; refusing to overwrite' >&2; exit 1; }
  if "$IPT" -t nat -C PREROUTING -p udp --dport 53 -j "$CHAIN" >/dev/null 2>&1; then
    echo 'Afterlife Port 53 rules already correct'
    exit 0
  fi
  "$IPT" -t nat -I PREROUTING 1 -p udp --dport 53 -j "$CHAIN"
  echo 'Afterlife Port 53 jump restored'
  exit 0
fi
if "$IPT" -t nat -S PREROUTING | grep -q -- "-j $CHAIN"; then
  echo 'Dangling Afterlife jump exists; refusing to overwrite' >&2; exit 1
fi
"$IPT" -t nat -N "$CHAIN"
for rule in "${expected[@]}"; do
  read -r -a args <<< "${rule#-A $CHAIN }"
  "$IPT" -t nat -A "$CHAIN" "${args[@]}"
done
"$IPT" -t nat -I PREROUTING 1 -p udp --dport 53 -j "$CHAIN"
echo 'Afterlife Port 53 routing restored'
