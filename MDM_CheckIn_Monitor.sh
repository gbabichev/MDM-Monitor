#!/bin/bash

echo "Waiting for mdmclient check-ins..."

/usr/bin/log stream --info --predicate 'process == "mdmclient"' | \
while IFS= read -r line; do
    [[ "$line" == *"Processing server request:"* ]] || continue
    echo "$(date '+%Y-%m-%d %H:%M:%S') Device checked in with MDM"
done
