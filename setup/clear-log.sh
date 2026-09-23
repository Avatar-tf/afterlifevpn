#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Clearing system logs...${NC}"

# Get disk usage before
BEFORE=$(df -h / | awk 'NR==2 {print $3}')

# Clear journal logs
journalctl --vacuum-time=1d
journalctl --vacuum-size=50M

# Clear system logs
echo "" > /var/log/syslog
echo "" > /var/log/auth.log
echo "" > /var/log/kern.log
echo "" > /var/log/messages 2>/dev/null

# Clear service logs
systemctl reset-failed

# Clear bash history
history -c
echo "" > ~/.bash_history

# Get disk usage after
AFTER=$(df -h / | awk 'NR==2 {print $3}')

echo -e "${GREEN}Logs cleared!${NC}"
echo "Disk usage before: $BEFORE"
echo "Disk usage after: $AFTER"
