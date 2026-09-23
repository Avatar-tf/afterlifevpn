#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BACKUP_DIR="/root/afterlifevpn-backup"
BACKUP_FILE="afterlifevpn-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

echo -e "${GREEN}Starting AFTERLIFE VPN Backup...${NC}"

# Create backup directory
mkdir -p $BACKUP_DIR

# Create temporary backup folder
TEMP_BACKUP="/tmp/afterlifevpn-backup-temp"
mkdir -p $TEMP_BACKUP

# Backup configurations
echo "Backing up configurations..."
cp -r /usr/local/afterlifevpn $TEMP_BACKUP/
cp -r /etc/afterlifevpn $TEMP_BACKUP/
cp -r /etc/hysteria $TEMP_BACKUP/
cp /usr/local/etc/xray/config.json $TEMP_BACKUP/ 2>/dev/null
cp /etc/default/dropbear $TEMP_BACKUP/ 2>/dev/null
cp /etc/issue.net $TEMP_BACKUP/ 2>/dev/null

# Backup user accounts
echo "Backing up user accounts..."
grep -E "^[^:]+:[^:]*:[0-9]{4,}:" /etc/passwd > $TEMP_BACKUP/users.txt
grep -E "^[^:]+:[^:]*:[0-9]{4,}:" /etc/shadow > $TEMP_BACKUP/shadow.txt

# Backup acme.sh certificates
echo "Backing up SSL certificates..."
cp -r ~/.acme.sh $TEMP_BACKUP/ 2>/dev/null

# Create compressed archive
echo "Creating archive..."
cd /tmp
tar -czf $BACKUP_DIR/$BACKUP_FILE afterlifevpn-backup-temp/

# Cleanup
rm -rf $TEMP_BACKUP

echo -e "${GREEN}Backup completed!${NC}"
echo -e "Backup saved to: ${YELLOW}$BACKUP_DIR/$BACKUP_FILE${NC}"
echo -e "Backup size: $(du -h $BACKUP_DIR/$BACKUP_FILE | awk '{print $1}')"
