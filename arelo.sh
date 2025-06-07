#!/bin/bash

BASE_DIR="./locations"
mkdir -p "$BASE_DIR"

# Flag to enable or disable logging
ENABLE_DEBUG=false
if [[ -n "$2" ]]; then
  ENABLE_DEBUG=true
fi

log_debug() {
  if [[ "$ENABLE_DEBUG" == true ]]; then
    local debug_file="./debug.log"  # Path to the debug file
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$debug_file"
  fi
}

log_debug "Starting script with config file: $1"

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
  if ! command -v locsim >/dev/null 2>&1; then
    log_debug  "Error: 'locsim' is not installed or not in your PATH."
    return 1
  fi
  locsim start "$@"
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
  sleep_time=1
  log_debug "config" "'sleep_time' not defined in config. Defaulting to 1."
fi

if [[ -z "$cycle_interval" ]]; then
  log_debug  "Error: 'cycle_interval' not defined in config."
  exit 1
fi

last_run=0

while true; do
  current_time=$(date +%s)
  elapsed=$(( current_time - last_run ))

  if (( elapsed >= cycle_interval * 60 )); then
    run_spoof_cycle
    last_run=$(date +%s)
  else
    log_debug  "Not time yet for next cycle. Elapsed: $elapsed seconds."
  fi

  log_debug  "Sleeping for $sleep_time minutes..."
  sleep $((sleep_time * 60))
done
