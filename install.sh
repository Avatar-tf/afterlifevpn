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
echo -e "${GREEN}   VPN Auto Installation Script${NC}"
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
    exit 1
fi

# Get user input
echo -e "${YELLOW}Please provide the following information:${NC}"
echo ""
read -p "Enter your domain (e.g., vpn.example.com): " domain
read -p "Enter your email for SSL certificate: " email
echo ""

# Update system
echo -e "${GREEN}[1/8] Updating system...${NC}"
apt update && apt upgrade -y

# Install basic dependencies
echo -e "${GREEN}[2/8] Installing dependencies...${NC}"
apt install -y wget curl git nano socat jq

# Download setup scripts
echo -e "${GREEN}[3/8] Downloading setup modules...${NC}"
mkdir -p /usr/local/vpnscript/setup
mkdir -p /usr/local/vpnscript/menu

# Base URL for your GitHub repo
BASE_URL="https://raw.githubusercontent.com/Avatar-tf/afterlifevvpn/main"

# Download all setup scripts
wget -q -O /usr/local/vpnscript/setup/ssh-ws.sh "$BASE_URL/setup/ssh-ws.sh"
wget -q -O /usr/local/vpnscript/setup/vmess.sh "$BASE_URL/setup/vmess.sh"
wget -q -O /usr/local/vpnscript/setup/hysteria.sh "$BASE_URL/setup/hysteria.sh"
wget -q -O /usr/local/vpnscript/setup/udp.sh "$BASE_URL/setup/udp.sh"
wget -q -O /usr/local/vpnscript/setup/ssl.sh "$BASE_URL/setup/ssl.sh"
wget -q -O /usr/local/vpnscript/setup/bbr.sh "$BASE_URL/setup/bbr.sh"
wget -q -O /usr/local/vpnscript/setup/dropbear.sh "$BASE_URL/setup/dropbear.sh"
wget -q -O /usr/local/vpnscript/menu/menu.sh "$BASE_URL/menu/menu.sh"

# Make scripts executable
chmod +x /usr/local/vpnscript/setup/*.sh
chmod +x /usr/local/vpnscript/menu/*.sh

# Run setup scripts
echo -e "${GREEN}[4/8] Setting up TCP BBR...${NC}"
bash /usr/local/vpnscript/setup/bbr.sh

echo -e "${GREEN}[5/8] Setting up SSL certificates...${NC}"
bash /usr/local/vpnscript/setup/ssl.sh "$domain" "$email"

echo -e "${GREEN}[6/8] Setting up SSH WebSocket...${NC}"
bash /usr/local/vpnscript/setup/ssh-ws.sh "$domain"

echo -e "${GREEN}[7/8] Setting up Dropbear...${NC}"
bash /usr/local/vpnscript/setup/dropbear.sh

echo -e "${GREEN}[8/8] Setting up VMess, Hysteria, and UDP...${NC}"
bash /usr/local/vpnscript/setup/vmess.sh "$domain"
bash /usr/local/vpnscript/setup/hysteria.sh "$domain"
bash /usr/local/vpnscript/setup/udp.sh

# Create menu command
ln -sf /usr/local/vpnscript/menu/menu.sh /usr/bin/menu

# Save configuration
cat > /usr/local/vpnscript/config.conf <<EOF
DOMAIN=$domain
EMAIL=$email
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
echo -e "  - SSH WebSocket"
echo -e "  - VMess (V2Ray)"
echo -e "  - Hysteria 2"
echo -e "  - UDP Custom (Port 53)"
echo -e "  - Dropbear SSH"
echo -e "  - TCP BBR enabled"
echo ""
echo -e "Type ${GREEN}menu${NC} to access the management panel"
echo ""
