#!/bin/sh

if [ -z "$1" ]; then
  echo "Usage: $0 <plist_name_without_extension>"
  exit 1
fi

PLIST_NAME="$1"
PLIST_PATH="/var/mobile/Library/LaunchAgents/${PLIST_NAME}.plist"

# Unload and delete
launchctl bootout gui/501 "$PLIST_PATH"
rm -f "$PLIST_PATH"

echo "$PLIST_NAME undeployed and removed."
