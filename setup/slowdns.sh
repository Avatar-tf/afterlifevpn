#!/bin/bash
# ============================================================================
# AFTERLIFE VPN - SlowDNS (dnstt) Installation & Configuration
# Path: setup/slowdns.sh
#
# dnstt listens on 0.0.0.0:5300 so iptables REDIRECT --to-ports 5300 from
# public UDP/53 can reach it. Do NOT bind 127.0.0.1:5300 with REDIRECT.
# Option 11 (menu_port53) owns public port 53.
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

CONFIG="/usr/local/afterlifevpn/config.conf"
NS_FILE="/usr/local/afterlifevpn/nameserver.conf"
DNS_DIR="/etc/afterlifevpn/dns"
BIN="/usr/local/bin/dnstt-server"
UNIT="/etc/systemd/system/dnstt.service"
LISTEN_ADDR="0.0.0.0"
LISTEN_PORT="5300"
SSH_BACKEND="127.0.0.1:109"
DNSTT_REPO="https://www.bamsoftware.com/git/dnstt.git"

if [[ ${EUID} -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root.${NC}"
    exit 1
fi

mkdir -p "$DNS_DIR" /usr/local/afterlifevpn /usr/local/bin

have_cmd() { command -v "$1" >/dev/null 2>&1; }

key_fail() {
    echo -e "  ${RED}✗ $1${NC}"
    exit 1
}

file_nonempty() { [[ -f "$1" && -s "$1" ]]; }

looks_like_hex() {
    local data
    data=$(tr -d ' \n\r\t' < "$1" 2>/dev/null || true)
    [[ -n "$data" && "$data" =~ ^[0-9A-Fa-f]+$ ]]
}

harden_key_perms() {
    chown root:root "$DNS_DIR/server.key" "$DNS_DIR/server.pub" 2>/dev/null || true
    chmod 600 "$DNS_DIR/server.key"
    chmod 644 "$DNS_DIR/server.pub"
}

validate_keypair() {
    local priv="$DNS_DIR/server.key"
    local pub="$DNS_DIR/server.pub"

    [[ -e "$priv" && -e "$pub" ]] || return 1
    [[ -r "$priv" && -r "$pub" ]] || key_fail "keypair exists but is unreadable under $DNS_DIR"
    file_nonempty "$priv" || key_fail "private key is empty: $priv"
    file_nonempty "$pub"  || key_fail "public key is empty: $pub"
    looks_like_hex "$priv" || key_fail "private key is not hex (corrupt): $priv"
    looks_like_hex "$pub"  || key_fail "public key is not hex (corrupt): $pub"

    local pub_len
    pub_len=$(tr -d ' \n\r\t' < "$pub" | wc -c)
    if (( pub_len != 64 )); then
        key_fail "public key length is ${pub_len}, expected 64 hex chars"
    fi
    return 0
}

# 1. Release systemd-resolved stub on :53 without wiping a working resolver
free_port_53() {
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        echo -e "  ${YELLOW}Configuring systemd-resolved to release port 53...${NC}"
        mkdir -p /etc/systemd/resolved.conf.d
        cat > /etc/systemd/resolved.conf.d/disable-stub.conf <<'EOF'
[Resolve]
DNSStubListener=no
EOF
        if [[ -e /run/systemd/resolve/resolv.conf ]]; then
            ln -sfn /run/systemd/resolve/resolv.conf /etc/resolv.conf
        elif [[ ! -s /etc/resolv.conf ]]; then
            printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
        fi
        systemctl restart systemd-resolved 2>/dev/null || true
    fi

    if ss -ulnp 2>/dev/null | grep -qE ':53\s'; then
        echo -e "  ${YELLOW}Note: something is still listening on UDP/53.${NC}"
        ss -ulnp | grep -E ':53\s' || true
        echo -e "  ${YELLOW}Option 11 owns public 53. dnstt stays on ${LISTEN_PORT}.${NC}"
    fi
}

ensure_build_deps() {
    local need=()
    have_cmd git || need+=(git)
    have_cmd go  || need+=(golang-go)
    if ((${#need[@]})); then
        echo -e "  ${YELLOW}Installing build deps: ${need[*]}${NC}"
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${need[@]}" >/dev/null
    fi
    have_cmd go || key_fail "go is required to build official dnstt-server"
}

# 2. Prefer an existing binary. Otherwise build official dnstt (no random wget).
install_dnstt() {
    echo -e "  ${CYAN}Checking dnstt-server binary...${NC}"
    if [[ -x "$BIN" ]]; then
        echo -e "  ${GREEN}✓ $BIN already present${NC}"
        return 0
    fi

    ensure_build_deps
    local tmp
    tmp=$(mktemp -d)
    echo -e "  ${YELLOW}Building official dnstt-server from source...${NC}"
    if ! git clone --depth 1 "$DNSTT_REPO" "$tmp/dnstt" >/dev/null 2>&1; then
        rm -rf "$tmp"
        key_fail "git clone of official dnstt failed. Place a trusted binary at $BIN and re-run."
    fi

    (
        cd "$tmp/dnstt/dnstt-server"
        go build -trimpath -ldflags="-s -w" -o "$BIN"
    )
    rm -rf "$tmp"
    chmod 755 "$BIN"
    [[ -x "$BIN" ]] || key_fail "build finished but $BIN is not executable"
    echo -e "  ${GREEN}✓ dnstt-server installed to $BIN${NC}"
}

# 3. Key checks: never rotate a half-pair, never start on a corrupt key
generate_keys() {
    local priv="$DNS_DIR/server.key"
    local pub="$DNS_DIR/server.pub"

    [[ -x "$BIN" ]] || key_fail "dnstt-server missing or not executable: $BIN"

    if [[ -e "$priv" && ! -e "$pub" ]]; then
        key_fail "orphan private key at $priv (no server.pub). Move it aside or restore the matching pubkey."
    fi
    if [[ -e "$pub" && ! -e "$priv" ]]; then
        key_fail "orphan public key at $pub (no server.key). Move it aside or restore the matching privkey."
    fi

    if [[ -e "$priv" && -e "$pub" ]]; then
        echo -e "  ${CYAN}Checking existing keypair...${NC}"
        validate_keypair
        harden_key_perms
        echo -e "  ${GREEN}✓ existing keypair valid ($DNS_DIR)${NC}"
        return 0
    fi

    echo -e "  ${YELLOW}Generating Ed25519 keypair (once)...${NC}"
    if ! "$BIN" -gen-key -privkey-file "$priv" -pubkey-file "$pub"; then
        rm -f "$priv" "$pub"
        key_fail "dnstt-server -gen-key failed"
    fi
    validate_keypair
    harden_key_perms
    echo -e "  ${GREEN}✓ keypair generated in $DNS_DIR${NC}"
}

# 4. systemd unit — bind ALL interfaces on 5300 (mux REDIRECT target)
setup_service() {
    local target_domain="$1"
    [[ -n "$target_domain" ]] || key_fail "tunnel NS domain is empty"
    validate_keypair || key_fail "refusing to start dnstt without a valid keypair"

    cat > "$UNIT" <<EOF
[Unit]
Description=AFTERLIFE SlowDNS (dnstt) Tunnel Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=${BIN} -udp ${LISTEN_ADDR}:${LISTEN_PORT} -privkey-file ${DNS_DIR}/server.key ${target_domain} ${SSH_BACKEND}
Restart=always
RestartSec=3
LimitNOFILE=65535
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable dnstt >/dev/null 2>&1 || true
    systemctl restart dnstt
}

wait_listen() {
    local i
    for i in $(seq 1 10); do
        if ss -ulnp 2>/dev/null | grep -qE ":${LISTEN_PORT}\\s"; then
            return 0
        fi
        sleep 0.4
    done
    return 1
}

check_ns_hint() {
    local ns="$1"
    echo -e "  ${CYAN}NS record hint for ${ns}${NC}"
    if have_cmd dig; then
        local ans
        ans=$(dig +short NS "$ns" 2>/dev/null || true)
        if [[ -n "$ans" ]]; then
            echo -e "  NS answers: ${GREEN}${ans//$'\n'/ }${NC}"
        else
            echo -e "  ${YELLOW}No NS found for ${ns} from this host.${NC}"
            echo -e "  ${YELLOW}Create: ${ns} IN NS <nameserver> and A of that NS -> this VPS IP.${NC}"
        fi
    else
        echo -e "  ${YELLOW}Optional: apt-get install -y bind9-dnsutils && dig NS ${ns} +short${NC}"
    fi
}

# ----------------- Execution -----------------
clear
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC} ${GREEN}AFTERLIFE VPN — SlowDNS (dnstt) Setup${NC}                ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

free_port_53
install_dnstt
generate_keys

DOMAIN=""
SOURCE_DOMAIN=""
[[ -f "$CONFIG" ]] && source "$CONFIG" && SOURCE_DOMAIN="${DOMAIN:-}"
[[ -f "$NS_FILE" ]] && source "$NS_FILE"

DEFAULT_TARGET="sl.${DOMAIN:-${SOURCE_DOMAIN:-example.com}}"
echo -e "  Configured Domain : ${GREEN}${SOURCE_DOMAIN:-${DOMAIN:-N/A}}${NC}"
echo -e "  Listen            : ${YELLOW}${LISTEN_ADDR}:${LISTEN_PORT}${NC}  (mux target)"
echo -e "  SSH backend       : ${YELLOW}${SSH_BACKEND}${NC}"
echo -e "  Target Tunnel NS  : ${YELLOW}${DEFAULT_TARGET}${NC}"
echo ""
read -r -p "  Confirm Tunnel Domain [$DEFAULT_TARGET]: " input_target
TARGET_TUNNEL="${input_target:-$DEFAULT_TARGET}"

printf 'NS_DOMAIN="%s"\n' "$TARGET_TUNNEL" > "$NS_FILE"

setup_service "$TARGET_TUNNEL"

echo ""
if systemctl is-active --quiet dnstt && wait_listen; then
    echo -e "  ${GREEN}✓ dnstt is running and listening on ${LISTEN_ADDR}:${LISTEN_PORT}${NC}"
else
    echo -e "  ${RED}✗ dnstt failed to listen. journalctl -u dnstt -n 50 --no-pager${NC}"
    systemctl --no-pager --full status dnstt || true
    exit 1
fi

validate_keypair || key_fail "keypair invalid after service start"
PUB_KEY=$(tr -d ' \n\r\t' < "$DNS_DIR/server.pub")
check_ns_hint "$TARGET_TUNNEL"

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo -e " ${GREEN}✓ SlowDNS Core Engine Installed & Running${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo -e "  Bind            : ${YELLOW}${LISTEN_ADDR}:${LISTEN_PORT}${NC}"
echo -e "  Backend         : ${YELLOW}${SSH_BACKEND}${NC} (Dropbear/SSH)"
echo -e "  Tunnel NS       : ${GREEN}${TARGET_TUNNEL}${NC}"
echo -e "  Public Key      : ${YELLOW}${PUB_KEY}${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo -e "  ${WHITE}Public UDP/53 is not bound here.${NC}"
echo -e "  ${YELLOW}Use Option 11 (Port 53 Toggle) to REDIRECT 53 -> ${LISTEN_PORT}.${NC}"
echo ""
read -r -p "  Press [Enter] to return..."
