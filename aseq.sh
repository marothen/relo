#!/bin/bash

# Get the config file from the first parameter
CONFIG_FILE="$1"
# Set debug mode based on the second parameter
if [[ "$2" == "null" ]]; then
  ENABLE_DEBUG=false
else
  ENABLE_DEBUG=true
fi

# Set FAKE_TIME based on the third parameter
if [[ "$3" == "null" ]]; then
  FAKE_TIME=""
else
  FAKE_TIME="$3"
fi


log_debug() {
  if [[ "$ENABLE_DEBUG" == true ]]; then
    local debug_file="./debug/aseq_debug.log"  # Path to the debug file
    mkdir -p "$(dirname "$debug_file")"        # Ensure the directory exists
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$debug_file"
  fi
}

# Get the current time in HHMM format
current_time=$(date '+%H%M')

# Split FAKE_TIME into hours and minutes if it is set
if [[ -n "$FAKE_TIME" ]]; then
  fake_hours=$((10#${FAKE_TIME:0:2}))  # Extract the first two digits (hours)
  fake_minutes=$((10#${FAKE_TIME:2:2}))  # Extract the last two digits (minutes)
else
  fake_hours=0
  fake_minutes=0
fi

# Split current_time into hours and minutes
current_hours=$((10#${current_time:0:2}))  # Extract the first two digits (hours)
current_minutes=$((10#${current_time:2:2}))  # Extract the last two digits (minutes)

# Convert FAKE_TIME and current_time to total minutes
fake_total_minutes=$((fake_hours * 60 + fake_minutes))
current_total_minutes=$((current_hours * 60 + current_minutes))

# Calculate FAKE_TIME_DIFF in minutes
FAKE_TIME_DIFF=$((fake_total_minutes - current_total_minutes))

# Debug log for FAKE_TIME_DIFF
log_debug "FAKE_TIME=$FAKE_TIME, current_time=$current_time, FAKE_TIME_DIFF=$FAKE_TIME_DIFF minutes"

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1381175181644664832/kuFQ4S89HKJJNiFrWMr9UQQ1aBrJZebktFLr0dQYEduARdtUcppYEF2yfavZ5mViOlZD"

# Function to send a message to Discord
send_discord_message() {
  local message="$1"
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"$message\"}" \
       "$DISCORD_WEBHOOK_URL"
}

log_debug() {
  if [[ "$ENABLE_DEBUG" == true ]]; then
    local debug_file="./debug/aseq_debug.log"  # Path to the debug file
    mkdir -p "$(dirname "$debug_file")"        # Ensure the directory exists
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$debug_file"
  fi
}

# Define the process_relo function
process_relo() {
  log_debug "Starting relo with config: $1 and end_time: $2"
  send_discord_message "Starting relo with config: $1 and end_time: $2"
  bash ./arelo.sh "$1" "debug" "$2" "$FAKE_TIME"
  log_debug "Stopping relo with config: $1 and end_time: $2"
  send_discord_message "Stopping relo with config: $1 and end_time: $2"
}

# Define the process_trav function
process_trav() {
  log_debug "Starting trav with config: $1"
  send_discord_message "Starting trav with config: $1"
  # Read values from the given config file
  local config_file="$1"
  if [[ ! -f "$config_file" ]]; then
    log_debug "Error: Config file '$config_file' not found."
    send_discord_message "Error: Config file '$config_file' not found."
    return 1
  fi

  
  # Extract and sanitize values from the config file
  local file=$(grep -E '^file=' "$config_file" | cut -d'=' -f2 | tr -d '[:space:]')
  local speed=$(grep -E '^speed=' "$config_file" | cut -d'=' -f2 | tr -d '[:space:]')
  local cycle_interval=$(grep -E '^cycle_interval=' "$config_file" | cut -d'=' -f2 | tr -d '[:space:]')

  file=$(echo "$file" | sed 's/^"//;s/"$//')

  bash ./atrav.sh $file "$speed" "$cycle_interval" "debug"

  log_debug "Stopping trav with config: $1"
  send_discord_message "Stopping trav with config: $1"
}

# Check if the config file is provided
if [[ -z "$CONFIG_FILE" ]]; then
  log_debug "Error: No config file provided. Please specify a config file as the first parameter."
  exit 1
fi

# Check if the config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  log_debug "Error: Config file '$CONFIG_FILE' not found."
  exit 1
fi

# Get the current time in HHMM format
current_time=$(date '+%H%M')

# Read the file line by line
found_first_non_skipped_line=false

while IFS=',' read -r type conf start_time end_time; do
  log_debug $conf
  # Trim any whitespace or invalid characters from start_time and end_time
  start_time=$(echo "$start_time" | tr -d '[:space:]')
  end_time=$(echo "$end_time" | tr -d '[:space:]')

  # Convert start_time and end_time to integers
  start_time=$((10#$start_time))
  end_time=$((10#$end_time))

  # Calculate the adjusted time based on FAKE_TIME_DIFF
  current_time=$(date '+%H%M')# Split current_time into hours and minutes
  current_hours=$((10#${current_time:0:2}))  # Extract the first two digits (hours)
  current_minutes=$((10#${current_time:2:2}))  # Extract the last two digits (minutes)

  # Calculate total minutes by adding FAKE_TIME_DIFF
  total_minutes=$((current_hours * 60 + current_minutes + FAKE_TIME_DIFF))

  # Convert total minutes back to HHMM format
  adjusted_hours=$((total_minutes / 60 % 24))  # Ensure hours wrap around after 24
  adjusted_minutes=$((total_minutes % 60))

  # Format adjusted_time as HHMM
  adjusted_time=$(printf "%02d%02d" $adjusted_hours $adjusted_minutes)

  # Debug log for adjusted time
  log_debug "current_time=$current_time, FAKE_TIME_DIFF=$FAKE_TIME_DIFF, adjusted_time=$adjusted_time"

  # Sanitize end_time and adjusted_time to remove any invalid characters or whitespace
  end_time=$(echo "$end_time" | tr -d '[:space:]')
  adjusted_time=$(echo "$adjusted_time" | tr -d '[:space:]')
  
  # Skip lines where end_time is smaller than the current time, but only until the first non-skipped line is found
  if [[ "$found_first_non_skipped_line" == false && $((10#$end_time)) -lt $((10#$adjusted_time)) ]]; then
    log_debug "Skipping line with end_time=$end_time (smaller than adjusted_time=$adjusted_time)"
    continue
  fi

  # Mark that the first non-skipped line has been found
  found_first_non_skipped_line=true

  # Call the appropriate function based on the type
  if [[ "$type" == "relo" ]]; then
    process_relo "$conf" "$end_time"
  elif [[ "$type" == "trav" ]]; then
    process_trav "$conf"
  else
    log_debug "Error: Unknown type '$type'. Exiting."
    exit 1
  fi
done < "$CONFIG_FILE"