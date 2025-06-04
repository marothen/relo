#!/bin/sh

# Check for argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <config_basename_without_extension>"
  exit 1
fi

CONFIG_BASENAME="$1"
CONFIG_PATH="./conf/${CONFIG_BASENAME}.conf"
PID_FILE="/tmp/runpid.pid"
SCRIPT="./autorelo.sh"

# Check if config file exists
if [ ! -f "$CONFIG_PATH" ]; then
  echo "Error: Config file '$CONFIG_PATH' not found."
  exit 1
fi

# Stop existing process if PID file exists and process is alive
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Stopping existing process with PID $OLD_PID..."
    kill "$OLD_PID"
  fi
  rm -f "$PID_FILE"
fi

# Start new process in background and disown it
echo "Starting new process with config '$CONFIG_PATH'..."
sh "$SCRIPT" "$CONFIG_PATH" &
NEW_PID=$!
disown

# Save new PID
echo "$NEW_PID" > "$PID_FILE"
echo "New process started with PID $NEW_PID."