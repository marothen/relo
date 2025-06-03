#!/bin/sh

if [ $# -ne 2 ]; then
  echo "Usage: $0 <plist_name> {start|stop|restart}"
  exit 1
fi

PLIST_NAME="$1"
ACTION="$2"
PLIST_PATH="/var/mobile/Library/LaunchAgents/${PLIST_NAME}.plist"
LABEL="$PLIST_NAME"

case "$ACTION" in
  start)
    launchctl bootstrap gui/501 "$PLIST_PATH"
    launchctl kickstart -kp gui/501/"$LABEL"
    echo "$PLIST_NAME started"
    ;;
  stop)
    launchctl bootout gui/501 "$PLIST_PATH"
    echo "$PLIST_NAME stopped"
    ;;
  restart)
    launchctl bootout gui/501 "$PLIST_PATH"
    launchctl bootstrap gui/501 "$PLIST_PATH"
    launchctl kickstart -kp gui/501/"$LABEL"
    echo "$PLIST_NAME restarted"
    ;;
  *)
    echo "Invalid action: $ACTION"
    echo "Usage: $0 <plist_name> {start|stop|restart}"
    exit 1
    ;;
esac
