#!/bin/bash

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Clear screen
clear

# Banner
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}  AFTERLIFE VPN Auto Installer${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use: sudo su)${NC}"
    exit 1
fi

# Check OS
if [[ $(cat /etc/os-release | grep -w ID | head -n1 | sed 's/=/ /g' | awk '{print $2}') != "ubuntu" ]]; then
    echo -e "${RED}This script only supports Ubuntu${NC}"
    echo -e "${YELLOW}Recommended: Ubuntu 20.04 LTS or Ubuntu 22.04 LTS${NC}"
    exit 1
fi

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
echo -e "Detected: ${GREEN}Ubuntu $UBUNTU_VERSION${NC}"
echo ""

# Get user input
echo -e "${YELLOW}Please provide the following information:${NC}"
echo ""
read -p "Enter your domain (e.g., vpn.example.com): " domain
read -p "Enter your email for SSL certificate: " email
echo ""

# Port configuration
echo -e "${YELLOW}Port Configuration:${NC}"
read -p "SSH WebSocket port (default 443): " ws_port
ws_port=${ws_port:-443}

read -p "Enable Hysteria 2 port hopping? (y/n, default y): " enable_hopping
enable_hopping=${enable_hopping:-y}

if [[ $enable_hopping == "y" ]]; then
    read -p "Hysteria 2 port range (default 20000-40000): " hysteria_ports
    hysteria_ports=${hysteria_ports:-20000-40000}
    read -p "Include port 53 for Hysteria? (y/n, default y): " include_53
    include_53=${include_53:-y}
else
    read -p "Hysteria 2 single port (default 443): " hysteria_port
    hysteria_port=${hysteria_port:-443}
fi

echo ""

# Update system
echo -e "${GREEN}[1/8] Updating system...${NC}"
apt update && apt upgrade -y

# Install basic dependencies
echo -e "${GREEN}[2/8] Installing dependencies...${NC}"
apt install -y wget curl git nano socat jq lsb-release iptables-persistent

# Download setup scripts
echo -e "${GREEN}[3/8] Downloading setup modules...${NC}"
mkdir -p /usr/local/afterlifevpn/setup
mkdir -p /usr/local/afterlifevpn/menu

# Base URL - REPLACE YOUR_USERNAME with your actual GitHub username
BASE_URL="https://raw.githubusercontent.com/Avatar-tf/afterlifevpn/main"

# Download all setup scripts
wget -q -O /usr/local/afterlifevpn/setup/ssh-ws.sh "$BASE_URL/setup/ssh-ws.sh"
wget -q -O /usr/local/afterlifevpn/setup/vmess.sh "$BASE_URL/setup/vmess.sh"
wget -q -O /usr/local/afterlifevpn/setup/hysteria.sh "$BASE_URL/setup/hysteria.sh"
wget -q -O /usr/local/afterlifevpn/setup/udp.sh "$BASE_URL/setup/udp.sh"
wget -q -O /usr/local/afterlifevpn/setup/ssl.sh "$BASE_URL/setup/ssl.sh"
wget -q -O /usr/local/afterlifevpn/setup/bbr.sh "$BASE_URL/setup/bbr.sh"
wget -q -O /usr/local/afterlifevpn/setup/dropbear.sh "$BASE_URL/setup/dropbear.sh"
wget -q -O /usr/local/afterlifevpn/menu/menu.sh "$BASE_URL/menu/menu.sh"

# Make scripts executable
chmod +x /usr/local/afterlifevpn/setup/*.sh
chmod +x /usr/local/afterlifevpn/menu/*.sh

# Run setup scripts
echo -e "${GREEN}[4/8] Setting up TCP BBR...${NC}"
bash /usr/local/afterlifevpn/setup/bbr.sh

echo -e "${GREEN}[5/8] Setting up SSL certificates...${NC}"
bash /usr/local/afterlifevpn/setup/ssl.sh "$domain" "$email"

echo -e "${GREEN}[6/8] Setting up SSH WebSocket...${NC}"
bash /usr/local/afterlifevpn/setup/ssh-ws.sh "$domain" "$ws_port"

echo -e "${GREEN}[7/8] Setting up Dropbear...${NC}"
bash /usr/local/afterlifevpn/setup/dropbear.sh

echo -e "${GREEN}[8/8] Setting up VMess, Hysteria, and UDP...${NC}"
bash /usr/local/afterlifevpn/setup/vmess.sh "$domain"

if [[ $enable_hopping == "y" ]]; then
    bash /usr/local/afterlifevpn/setup/hysteria.sh "$domain" "hopping" "$hysteria_ports" "$include_53"
else
    bash /usr/local/afterlifevpn/setup/hysteria.sh "$domain" "single" "$hysteria_port"
fi

bash /usr/local/afterlifevpn/setup/udp.sh

# Create menu command
ln -sf /usr/local/afterlifevpn/menu/menu.sh /usr/bin/menu

# Save configuration
cat > /usr/local/afterlifevpn/config.conf <<EOF
DOMAIN=$domain
EMAIL=$email
WS_PORT=$ws_port
HYSTERIA_MODE=$enable_hopping
HYSTERIA_PORTS=$hysteria_ports
HYSTERIA_PORT=$hysteria_port
INCLUDE_53=$include_53
INSTALL_DATE=$(date)
EOF

# Display completion
clear
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}   Installation Complete!${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo -e "Domain: ${YELLOW}$domain${NC}"
echo -e "Services installed:"
echo -e "  - SSH WebSocket (Port: $ws_port)"
echo -e "  - VMess (V2Ray) (Port: 443)"
if [[ $enable_hopping == "y" ]]; then
    echo -e "  - Hysteria 2 (Port Hopping: $hysteria_ports)"
    [[ $include_53 == "y" ]] && echo -e "    + Port 53 included"
else
    echo -e "  - Hysteria 2 (Port: $hysteria_port)"
fi
echo -e "  - UDP Custom (Port 53)"
echo -e "  - Dropbear SSH (Port 442)"
echo -e "  - TCP BBR enabled"
echo ""
echo -e "Type ${GREEN}menu${NC} to access the management panel"
echo ""
