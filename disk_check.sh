#!/bin/bash

THRESHOLD=80  # Set your threshold value here
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
