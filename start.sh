#!/bin/sh

if [ -z "$1" ]; then
  echo "Usage: $0 <plist_name_without_extension>"
  exit 1
fi

PLIST_NAME="$1"
SOURCE_PLIST="./plist/${PLIST_NAME}.plist"
TARGET_PLIST="/var/mobile/Library/LaunchAgents/${PLIST_NAME}.plist"

# Ensure LaunchAgents directory exists
mkdir -p /var/mobile/Library/LaunchAgents

# Check if source plist exists
if [ ! -f "$SOURCE_PLIST" ]; then
  echo "Error: $SOURCE_PLIST not found."
  exit 1
fi

# Copy and load plist
cp "$SOURCE_PLIST" "$TARGET_PLIST"
launchctl bootstrap gui/501 "$TARGET_PLIST"
launchctl kickstart -kp gui/501/"$PLIST_NAME"

echo "$PLIST_NAME deployed and started."
