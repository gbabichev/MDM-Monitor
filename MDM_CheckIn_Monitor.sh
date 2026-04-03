#!/bin/bash

echo "Waiting for MDM Commands..."

/usr/bin/log stream --info --predicate 'process == "mdmclient"' | \
while IFS= read -r line; do
    [[ "$line" == *"Processing server request: DeclarativeManagement for"* ]] || continue
    echo "$(date '+%Y-%m-%d %H:%M:%S') MDM Command Received"
done
