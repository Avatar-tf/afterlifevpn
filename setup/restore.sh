#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

BACKUP_DIR="/root/afterlifevpn-backup"

echo -e "${YELLOW}AFTERLIFE VPN Restore${NC}"
echo ""

# List available backups
if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR)" ]; then
    echo -e "${RED}No backups found in $BACKUP_DIR${NC}"
    exit 1
fi

echo "Available backups:"
ls -lh $BACKUP_DIR/*.tar.gz | awk '{print NR". "$9" ("$5")"}'
echo ""

read -p "Enter backup number to restore: " backup_num

# Get selected backup file
BACKUP_FILE=$(ls $BACKUP_DIR/*.tar.gz | sed -n "${backup_num}p")

if [ -z "$BACKUP_FILE" ]; then
    echo -e "${RED}Invalid selection${NC}"
    exit 1
fi

echo -e "${YELLOW}Restoring from: $BACKUP_FILE${NC}"
read -p "This will overwrite current configuration. Continue? (y/n): " confirm

if [[ $confirm != "y" ]]; then
    echo "Restore cancelled"
    exit 0
fi

# Extract backup
TEMP_RESTORE="/tmp/afterlifevpn-restore-temp"
mkdir -p $TEMP_RESTORE
tar -xzf $BACKUP_FILE -C $TEMP_RESTORE

# Restore configurations
echo "Restoring configurations..."
cp -r $TEMP_RESTORE/afterlifevpn-backup-temp/afterlifevpn /usr/local/
cp -r $TEMP_RESTORE/afterlifevpn-backup-temp/afterlifevpn /etc/
cp -r $TEMP_RESTORE/afterlifevpn-backup-temp/hysteria /etc/
cp $TEMP_RESTORE/afterlifevpn-backup-temp/config.json /usr/local/etc/xray/ 2>/dev/null
cp $TEMP_RESTORE/afterlifevpn-backup-temp/dropbear /etc/default/ 2>/dev/null
cp $TEMP_RESTORE/afterlifevpn-backup-temp/issue.net /etc/ 2>/dev/null

# Restore SSL certificates
echo "Restoring SSL certificates..."
cp -r $TEMP_RESTORE/afterlifevpn-backup-temp/.acme.sh ~/ 2>/dev/null

# Restart services
echo "Restarting services..."
systemctl restart ws-ssh xray hysteria udp-custom dropbear

# Cleanup
rm -rf $TEMP_RESTORE

echo -e "${GREEN}Restore completed!${NC}"
echo "Please verify all services are running correctly"
