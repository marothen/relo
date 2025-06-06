#!/bin/sh

PID_FILE="/tmp/runpid.pid"

# Check if PID file exists
if [ ! -f "$PID_FILE" ]; then
  echo "No PID file found. Nothing to stop."
  exit 0
fi

PID=$(cat "$PID_FILE")

# Kill the process if it’s still running
if kill -0 "$PID" 2>/dev/null; then
  echo "Stopping process with PID $PID..."
  kill "$PID"
else
  echo "No running process with PID $PID."
fi

# Remove the PID file
rm -f "$PID_FILE"
echo "Stopped and cleaned up."
