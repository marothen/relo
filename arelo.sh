#!/bin/bash

BASE_DIR="./locations"
mkdir -p "$BASE_DIR"
LOCATION_LOG_FILE="./track/location_latest.txt"
PID_FILE="./track/runpid.pid"
touch "$PID_FILE"
NEW_PID=$$
# Append the new PID as a new line to the PID file
echo "$NEW_PID" >> "$PID_FILE"

# Initialize variables
ENABLE_DEBUG=false
END_TIME=""
FAKE_TIME=""
FAKE_TIME_SECONDS=0  # Used to track fake time in seconds

# --- Parameter handling ---
if [[ "$2" != "null" ]]; then
  ENABLE_DEBUG=true
fi

if [[ "$3" != "null" ]]; then
  END_TIME="$3"
fi

log_debug() {
  if [[ "$ENABLE_DEBUG" == true ]]; then
    local debug_file="./debug/arelo_debug.log"  # Path to the debug file
    mkdir -p "$(dirname "$debug_file")"        # Ensure the directory exists
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$debug_file"
  fi
}

if [[ -n "$4" ]]; then
  FAKE_TIME="$4"
  # Convert FAKE_TIME to seconds since midnight
  fake_time_seconds=$((10#${FAKE_TIME:0:2} * 3600 + 10#${FAKE_TIME:2:2} * 60))

  # Get the current real time in seconds since midnight
  current_real_time_seconds=$(( 10#$(date '+%H') * 3600 + 10#$(date '+%M') * 60 ))

  # Calculate the difference between fake time and real time
  FAKE_TIME_DIFF=$((fake_time_seconds - current_real_time_seconds))
  log_debug "FAKE_TIME_DIFF calculated: $FAKE_TIME_DIFF seconds"
fi

log_debug "Starting script with config file: $1"
log_debug "Debug mode: $ENABLE_DEBUG"
log_debug "End time: $END_TIME"
log_debug "Fake time: $FAKE_TIME"

if [[ -f "$1" ]]; then
  source "$1"
  if [[ -z "$subfolder" ]]; then
    log_debug  "Error: 'subfolder' not defined in config."
    exit 1
  fi
  if [[ -z "$file_name" ]]; then
    log_debug  "Error: 'file_name' not defined in config."
    exit 1
  fi
  SUBFOLDER="$BASE_DIR/$subfolder"
  if [[ ! -d "$SUBFOLDER" ]]; then
    log_debug  "Error: Subfolder '$SUBFOLDER' does not exist."
    exit 1
  fi

  selected_file="$SUBFOLDER/$file_name"
  if [[ ! -f "$selected_file" ]]; then
    log_debug  "Error: File '$file_name' not found in subfolder '$SUBFOLDER'."
    exit 1
  fi
else
  log_debug  "Error: Config file '$1' not found."
  exit 1
fi

safe_locsim_start() {
  # Sanitize the input to remove extra spaces or invalid characters
  sanitized_input=$(echo "$@" | tr -s ' ')

  # Save the sanitized input to the location log file
  echo "$sanitized_input" > "$LOCATION_LOG_FILE"
  log_debug "Position saved to $LOCATION_LOG_FILE: ($sanitized_input)"

  # Check if locsim is installed
  if ! command -v locsim >/dev/null 2>&1; then
    log_debug "Error: 'locsim' is not installed or not in your PATH."
    return 1
  fi

  # Start locsim with the sanitized input
  locsim start $sanitized_input
}

select_random_location_from_file() {
  line=$(grep -Eo '\([^)]+\)' "$selected_file" | shuf -n 1)
  clean_line=$(echo "$line" | tr -d '()')
  IFS=',' read -r lat lon <<< "$clean_line"
  lat=$(echo "$lat" | xargs)
  lon=$(echo "$lon" | xargs)
  current_location="($lat, $lon)"
}

run_spoof_cycle() {
  select_random_location_from_file

  IFS=',' read -r lat lon <<< "${current_location//[()]/}"
  

  log_debug  "Coordinates: $lat, $lon"

  if [ -n "$move_meters" ]; then
    angle=$(awk -v seed=$RANDOM 'BEGIN { srand(seed); print rand() * 2 * 3.14159265359 }')
    random_radius=$(od -An -N2 -tu2 < /dev/urandom | awk -v max="$move_meters" '{print $1 % (max + 1)}')
    log_debug  "Random radius: $random_radius meters"
    delta_lat=$(awk -v d="$random_radius" -v a="$angle" 'BEGIN { printf "%.10f", (d * cos(a)) / 111320 }')
    delta_lon=$(awk -v d="$random_radius" -v a="$angle" -v lat="$lat" 'BEGIN { printf "%.10f", (d * sin(a)) / (111320 * cos(lat * 3.14159265359 / 180)) }')
    lat=$(awk -v l="$lat" -v d="$delta_lat" 'BEGIN { printf "%.10f", l + d }')
    lon=$(awk -v l="$lon" -v d="$delta_lon" 'BEGIN { printf "%.10f", l + d }')
    log_debug  "New randomized coordinates: $lat, $lon"
  fi

  log_debug  "Starting locsim with coordinates: $lat, $lon"
  safe_locsim_start "$lat" "$lon"
}

if [[ -z "$sleep_time" ]]; then
  sleep_time=60
  log_debug "config" "'sleep_time' not defined in config. Defaulting to 60 seconds."
fi

if [[ -z "$cycle_interval" ]]; then
  log_debug  "Error: 'cycle_interval' not defined in config."
  exit 1
fi

last_run=0

while true; do
  # Use fake time if provided, otherwise use the real current time
  if [[ -n "$FAKE_TIME" ]]; then
    # Get the current real time in seconds since midnight
    current_real_time_seconds=$(( 10#$(date '+%H') * 3600 + 10#$(date '+%M') * 60 ))

    # Calculate the current fake time in seconds
    current_fake_time_seconds=$((current_real_time_seconds + FAKE_TIME_DIFF))

    # Convert current fake time back to HHMM format
    fake_hours=$((current_fake_time_seconds / 3600 % 24))
    fake_minutes=$((current_fake_time_seconds % 3600 / 60))
    FAKE_TIME=$(printf "%02d%02d" $fake_hours $fake_minutes)
    current_time_hhmm="$FAKE_TIME"

    # Debug logs for fake time
    log_debug "Current fake time: $FAKE_TIME (calculated using FAKE_TIME_DIFF: $FAKE_TIME_DIFF)"
  else
    current_time_hhmm=$(date '+%H%M')
  fi

  # Sanitize current_time_hhmm and END_TIME to remove any invalid characters or whitespace
  current_time_hhmm=$(echo "$current_time_hhmm" | tr -d '[:space:]')
  END_TIME=$(echo "$END_TIME" | tr -d '[:space:]')

  # Check if END_TIME is defined and exit if the current time has reached or passed it
  if [[ -n "$END_TIME" ]]; then
    if [[ $((10#$END_TIME)) -lt $((10#$current_time_hhmm)) ]]; then
      # Handle wraparound at midnight
      if [[ $((10#$current_time_hhmm)) -lt $((10#2400)) ]]; then
        log_debug "End time $END_TIME not yet reached. Continuing loop."
      else
        log_debug "End time $END_TIME reached. Exiting loop."
        break
      fi
    else
      # Standard range
      if [[ $((10#$current_time_hhmm)) -ge $((10#$END_TIME)) ]]; then
        log_debug "End time $END_TIME reached. Exiting loop."
        break
      fi
    fi
  fi

  current_time=$(date +%s)
  elapsed=$(( current_time - last_run ))

  if (( elapsed >= cycle_interval)); then
    run_spoof_cycle
    last_run=$(date +%s)
  else
    log_debug  "Not time yet for next cycle. Elapsed: $elapsed seconds."
    read -r position < "$LOCATION_LOG_FILE"
    safe_locsim_start "$position"
  fi

  log_debug  "Sleeping for $sleep_time seconds..."
  sleep "$sleep_time"
done

log_debug "Script completed. Exiting."
# Check if the script is being sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Script is executed directly
  exit 0  # Ensure the terminal regains control
else
  # Script is sourced or called by another script
  return 0  # Ensure the calling script regains control
fi
