echo -e "\e[1;36m========================================\e[0m"
echo -e "\e[1;36m        XRAY ACTIVE CONNECTIONS         \e[0m"
echo -e "\e[1;36m========================================\e[0m"
printf "%-15s | %-10s | %s\n" "Username" "IP Count" "Active IP Addresses"
echo -e "----------------------------------------"

if [ ! -f "$LOG_FILE" ]; then
    echo -e "\e[1;31mError: Access log not found at $LOG_FILE\e[0m"
    exit 1
fi

# Extract accepted connections, grab the IP and email, then sort by unique users
grep "accepted" "$LOG_FILE" | awk '{print $3, $7}' | sed 's/tcp://g' | awk -F: '{print $1" "$2}' > /tmp/xray_active.tmp

# Loop through unique emails/users currently active in the log
awk '{print $2}' /tmp/xray_active.tmp | sort | uniq | while read user; do
    if [ "$user" != "email:none" ] && [ "$user" != "" ]; then
        # Extract unique IPs for this specific user
        IP_LIST=$(grep -w "$user" /tmp/xray_active.tmp | awk '{print $1}' | sort | uniq | tr '\n' ', ' | sed 's/, $//')
        IP_COUNT=$(grep -w "$user" /tmp/xray_active.tmp | awk '{print $1}' | sort | uniq | wc -l)
        
        # Print formatted row
        printf "%-15s | %-10s | %s\n" "$user" "$IP_COUNT" "$IP_LIST"
    fi
done

rm -f /tmp/xray_active.tmp
echo -e "\e[1;36m========================================\e[0m"
