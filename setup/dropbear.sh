#!/bin/bash
# AFTERLIFE - Dropbear (keep existing port, banner in /etc/issue.net)
set -e
if [[ $EUID -ne 0 ]]; then
    echo "Error: run as root"
    exit 1
fi

apt-get install -y dropbear >/dev/null

# Prefer port already in use, then /etc/default, else 109 (dnstt target)
PORT=""
live=$(ss -tlnp 2>/dev/null | awk '/dropbear/ {print $4}' | grep -oE '[0-9]+$' | head -1)
[[ "$live" =~ ^[0-9]+$ ]] && PORT="$live"
if [[ -z "$PORT" && -f /etc/default/dropbear ]]; then
    PORT=$(awk -F= '/^DROPBEAR_PORT=/{gsub(/"/,"",$2); print $2}' /etc/default/dropbear)
fi
[[ "$PORT" =~ ^[0-9]+$ ]] || PORT=109

# Banner file — edit this on the VPS to change text
if [[ ! -s /etc/issue.net ]]; then
cat > /etc/issue.net << 'EOF'
<br>
<font color="#00ff80">▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬</font><br>
<font color="#00ffbf"> ★ AFTERLIFE PREMIUM VPN SERVER ★ </font><br>
<font color="#00ffff">▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬</font><br>
<br>
<font color="#00bfff">► SUPPORTED PROTOCOLS</font><br>
<font color="#0080ff">   • SSH / Dropbear / OHP </font><br>
<font color="#0040ff">   • OpenVPN (UDP/TCP/SSL/WS) </font><br>
<font color="#0000ff">   • XRAY (Vmess • Vless • Trojan) </font><br>
<font color="#4000ff">   • Shadowsocks • NoobzVPN </font><br>
<font color="#6000ff">   • BadVPN (UDP Gaming Support) </font><br>
<font color="#8000ff">   • SOCKS5 (Dante) • UDP Custom </font><br>
<br>
<font color="#a000ff">► TERMS OF SERVICE (STRICT)</font><br>
<font color="#bf00ff">   ⛔ NO DDOS / Hacking / Carding</font><br>
<font color="#df00ff">   ⛔ NO Torrent / P2P / Spamming</font><br>
<font color="#ff00ff">   ⛔ NO Multi-Login (Max 1 Login)</font><br>
<br>
<font color="#ff00bf">► CUSTOMER SUPPORT</font><br>
<font color="#ff0080">   ✈ Telegram : @afterlife005</font><br>
<font color="#ff0040">   ☎ WhatsApp : +234 816 512 9071</font><br>
<br>
<font color="#ff0000">▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬</font><br>
<font color="#ff0000">    © 2026 Afterlife World    </font><br>
EOF
fi

cat > /etc/motd << 'EOF'
================================
   AFTERLIFE PREMIUM VPN SERVER
================================
 Telegram : @afterlife005
 WhatsApp : +234 816 512 9071
 Edit banner:  nano /etc/issue.net
 Then run:    systemctl restart dropbear
================================
EOF

cat > /etc/default/dropbear << EOF
NO_START=0
DROPBEAR_PORT=${PORT}
DROPBEAR_EXTRA_ARGS="-p ${PORT} -b /etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

systemctl daemon-reload
systemctl enable dropbear >/dev/null 2>&1 || true
systemctl restart dropbear
sleep 1

echo "Dropbear port ${PORT} (unchanged if it was already running)"
echo "Banner file : /etc/issue.net"
ps aux | grep '[d]ropbear' || true
