#!/bin/bash

echo "Waiting for JAMF Pro recurring check-ins..."

/usr/bin/tail -n 0 -F /var/log/jamf.log | \
while IFS= read -r line; do
    [[ "$line" == *' jamf['* ]] || continue
    [[ "$line" == *'Checking for policies triggered by "recurring check-in"'* ]] || continue
    echo "$(date '+%Y-%m-%d %H:%M:%S') Device checked in with JAMF Pro"
done
