#!/bin/bash
THRESHOLD=80
APP_USERS=("appuser1" "appuser2" "appgroup")
echo "Checking disk usage..."
df -h | awk 'NR>1'

echo "Checking for filesystems above $THRESHOLD%..."
df -h | awk 'NR>1 {print $5, $6}' | sed 's/%//' | while read -r usage mount
do
    usage=${usage%\%}  # Remove %
    if [ "$usage" -gt "$THRESHOLD" ]; then
        echo " $mount is at $usage% usage"
        cd "$mount" || continue
        echo "Analyzing $mount..."
        echo "Top 5 space-consuming directories:"
        du -sh * 2>/dev/null | sort -hr | head -n 5
        avail=$(df -h "$mount" | awk 'NR>1 {print $4}')
        echo "Available space on $mount: $avail"
        du -ah --max-depth=1 2>/dev/null | sort -rh | head -n 10 | while read SIZE ITEM; do
        OWNER=$(stat -c '%U' "$ITEM")
        echo "$ITEM ($SIZE) owned by $OWNER"
        for user in "${APP_USERS[@]}"; do
                if [[ "$OWNER" == "$user" ]]; then
                    echo "Action needed: $ITEM owned by $OWNER"
                fi
        done
done
        echo "Checking for deleted files held by processes..."
        USAGE=$(df -h /var | awk 'NR==2 {gsub("%",""); print $5}')
        if [ "$USAGE" -ge "$THRESHOLD" ]; then
                echo "/var is using ${USAGE}%, which is above ${THRESHOLD}%."
                echo "Cleaning up YUM repository cache files..."

                # Refresh subscription and clean repos
                subscription-manager repos --list
                subscription-manager repos --disable "*"
                subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-optional-rpms
                subscription-manager refresh

                yum clean all
        else
                echo "/var usage (${USAGE}%) is below threshold (${THRESHOLD}%). No cleanup needed."
        fi
        deleted=$(lsof | grep deleted)
        if [ -n "$deleted" ]; then
            echo "Found deleted files still held by processes."
            size=$(lsof | awk '/deleted/ {sum+=$7} END {print sum}')
            echo "Total size of deleted files: $size bytes"

            if [ "$size" -gt 0 ]; then
                echo "Releasing occupied space..."
                pids=$(lsof -nP | grep '(deleted)' | awk '{print $2}')
                for pid in $pids; do
                    kill -9 "$pid"
                done
            fi
        fi
        new_usage=$(df -h "$mount" | awk 'NR>1 {print $5}' | sed 's/%//')
        echo "New usage on $mount: $new_usage%"
        if [ "$new_usage" -gt "$THRESHOLD" ]; then
            echo "Still above threshold. Notify NOC team to escalate to VMware team for LUN addition."
            echo "After LUN addition, resize the filesystem."
        else
            echo " Usage is now under threshold."
        fi
    fi
done