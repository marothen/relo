#!/bin/bash

BASE_DIR="./locations"
mkdir -p "$BASE_DIR"

# Standardwerte
is_batch=false
debug_mode=false

# Logging-Vorbereitung
LOGFILE="/var/mobile/locsim_debug.log"
log() {
  [[ "$debug_mode" == true ]] && echo "$(date '+%F %T') | $*" >> "$LOGFILE"
}

# Config einlesen
if [[ -f "$1" ]]; then
  source "$1"
  [[ "$debug_mode" == true ]] && exec >>"$LOGFILE" 2>&1
  [[ -z "$execution_mode" ]] && echo "Error: 'execution_mode' not set in config." >&2 && exit 1
  is_batch=true
  exec 1>/dev/null 2>&1
elif [[ -n "$1" ]]; then
  echo "Error: Config file '$1' not found." >&2
  exit 1
fi

# PATH erweitern
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:/opt/bin:$PATH"

safe_locsim_start() {
  log "Trying to start locsim with arguments: $*"
  if ! command -v locsim >/dev/null 2>&1; then
    log "locsim not found in PATH: $PATH"
    [[ $is_batch == false ]] && echo "Error: 'locsim' not in PATH"
    return 1
  fi
  locsim start "$@"
  log "locsim executed"
}

select_random_location_from_file() {
  line=$(grep -Eo '\([^)]+\)' "$selected_file" | shuf -n 1)
  clean_line=$(echo "$line" | tr -d '()')
  IFS=',' read -r lat lon <<< "$clean_line"
  lat=$(echo "$lat" | xargs)
  lon=$(echo "$lon" | xargs)
  current_location="($lat, $lon)"
  log "Selected location from file: $current_location"
}

run_spoof_cycle() {
  if [[ "$execution_mode" == "file" ]]; then
    select_random_location_from_file
  fi
  IFS=',' read -r lat lon <<< "${current_location//[()]/}"
  log "Running spoof cycle with base coordinates: $lat, $lon"

  if [ -n "$move_meters" ]; then
    angle=$(awk -v seed=$RANDOM 'BEGIN { srand(seed); print rand() * 2 * 3.14159265359 }')
    random_radius=$(od -An -N2 -tu2 < /dev/urandom | awk -v max="$move_meters" '{print $1 % (max + 1)}')
    delta_lat=$(awk -v d="$random_radius" -v a="$angle" 'BEGIN { printf "%.10f", (d * cos(a)) / 111320 }')
    delta_lon=$(awk -v d="$random_radius" -v a="$angle" -v lat="$lat" 'BEGIN { printf "%.10f", (d * sin(a)) / (111320 * cos(lat * 3.14159265359 / 180)) }')
    lat=$(awk -v l="$lat" -v d="$delta_lat" 'BEGIN { printf "%.10f", l + d }')
    lon=$(awk -v l="$lon" -v d="$delta_lon" 'BEGIN { printf "%.10f", l + d }')
    log "Random movement applied: $random_radius m → New coords: $lat, $lon"
  fi

  log "Calling locsim with final coordinates: $lat, $lon"
  safe_locsim_start "$lat" "$lon"
}

# --- Batch Modus ---
if [[ $is_batch == true ]]; then
  [[ "$debug_mode" == true ]] && log "Running in batch mode"

  if [[ "$execution_mode" == "file" ]]; then
    [[ -z "$subfolder" ]] && echo "Missing 'subfolder'" && exit 1
    [[ -z "$file_name" ]] && echo "Missing 'file_name'" && exit 1
    SUBFOLDER="$BASE_DIR/$subfolder"
    selected_file="$SUBFOLDER/$file_name"

    if [[ ! -d "$SUBFOLDER" ]]; then
      echo "Subfolder '$SUBFOLDER' does not exist"
      exit 1
    fi

    if [[ ! -f "$selected_file" ]]; then
      echo "File '$file_name' not found in '$SUBFOLDER'"
      exit 1
    fi
  elif [[ "$execution_mode" == "manual" ]]; then
    [[ -z "$current_location" ]] && echo "Missing 'current_location'" && exit 1
  else
    echo "Unknown execution_mode: $execution_mode"
    exit 1
  fi

  while true; do
    run_spoof_cycle
    log "Sleeping for $auto_wait_time minutes"
    sleep "$((auto_wait_time * 60))"
  done
fi
