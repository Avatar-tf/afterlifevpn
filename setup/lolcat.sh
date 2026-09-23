#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}   Rainbow Theme Manager${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "1. Install Lolcat (Rainbow Colors)"
echo "2. Enable Rainbow Banner"
echo "3. Disable Rainbow Banner"
echo "4. Test Rainbow Effect"
echo "0. Back to Menu"
echo ""
read -p "Select option: " option

case $option in
    1)
        clear
        echo "Installing lolcat..."
        
        # Install Ruby if not installed
        apt install -y ruby
        
        # Install lolcat gem
        gem install lolcat
        
        echo -e "${GREEN}Lolcat installed successfully!${NC}"
        ;;
    2)
        clear
        if ! command -v lolcat &> /dev/null; then
            echo -e "${YELLOW}Lolcat not installed. Installing now...${NC}"
            apt install -y ruby
            gem install lolcat
        fi
        
        # Create rainbow banner
        cat > /usr/local/bin/rainbow-banner <<'EOF'
#!/bin/bash
cat << "BANNER" | lolcat
================================
   AFTERLIFE VPN SERVER
================================
   Welcome to the Matrix
================================
BANNER
EOF
        
        chmod +x /usr/local/bin/rainbow-banner
        
        # Add to login banner
        echo "/usr/local/bin/rainbow-banner" >> /etc/profile
        
        echo -e "${GREEN}Rainbow banner enabled!${NC}"
        echo "Users will see rainbow colors on login"
        ;;
    3)
        clear
        sed -i '/rainbow-banner/d' /etc/profile
        echo -e "${GREEN}Rainbow banner disabled${NC}"
        ;;
    4)
        clear
        if command -v lolcat &> /dev/null; then
            echo "AFTERLIFE VPN - Rainbow Test" | lolcat
            echo "================================" | lolcat
            echo "SSH WebSocket" | lolcat
            echo "VMess (V2Ray)" | lolcat
            echo "Hysteria 2" | lolcat
            echo "UDP Custom" | lolcat
            echo "================================" | lolcat
        else
            echo -e "${RED}Lolcat not installed. Install it first (Option 1)${NC}"
        fi
        ;;
    0)
        exit 0
        ;;
esac

read -p "Press enter to continue..."
