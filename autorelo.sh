#!/bin/bash



# Debug-Ausgabe-Funktion
log_debug() {
  local level="$1"
  local message="$2"
  case "$debug_mode" in
    0) return ;;  # keine Ausgabe
    1)
      [[ "$level" == "run" || "$level" == "locsim" ]] || return
      echo "$(date '+%Y-%m-%d %H:%M:%S') $message" >> "$BASE_DIR/debug.log"
      ;;
    2)
      echo "$(date '+%Y-%m-%d %H:%M:%S') $message" >> "$BASE_DIR/debug.log"
      ;;
    3)
      echo "$(date '+%Y-%m-%d %H:%M:%S') $message"
      ;;
  esac
}

CONFIG_FILE="$1"
echo Config-Datei: "$CONFIG_FILE"
if [[ -z "$CONFIG_FILE" || ! -f "$CONFIG_FILE" ]]; then
  log_debug "init" "Error: Config file must be provided and exist."
  exit 1
fi

source "$CONFIG_FILE"

# Validierung der nötigen Variablen
if [[ -z "$subfolder" || -z "$file_name" || -z "$auto_wait_time" ]]; then
  log_debug "init" "Error: subfolder, file_name und auto_wait_time müssen gesetzt sein."
  exit 1
fi

# Standardwerte
check_interval_minutes=${check_interval_minutes:-1}
debug_mode=${debug_mode:-0}
BASE_DIR="./locations"
SUBFOLDER="$BASE_DIR/$subfolder"
selected_file="$SUBFOLDER/$file_name"
auto_wait_seconds=$((auto_wait_time * 60))
check_interval_seconds=$((check_interval_minutes * 60))

# Datei prüfen
if [[ ! -f "$selected_file" ]]; then
  log_debug "init" "Error: Datei '$selected_file' nicht gefunden."
  exit 1
fi

select_random_location_from_file() {
  local line=$(grep -Eo '\([^)]+\)' "$selected_file" | shuf -n 1)
  clean_line=$(echo "$line" | tr -d '()')
  IFS=',' read -r lat lon <<< "$clean_line"
  lat=$(echo "$lat" | xargs)
  lon=$(echo "$lon" | xargs)
  current_location="($lat, $lon)"
  log_debug "run" "Neue Zufallsposition: $current_location"
}

randomize_location() {
  if [[ -z "$move_meters" || "$move_meters" -eq 0 ]]; then
    return
  fi
  IFS=',' read -r lat lon <<< "${current_location//[()]/}"
  angle=$(awk -v seed=$RANDOM 'BEGIN { srand(seed); print rand() * 2 * 3.14159265359 }')
  random_radius=$(od -An -N2 -tu2 < /dev/urandom | awk -v max="$move_meters" '{print $1 % (max + 1)}')
  delta_lat=$(awk -v d="$random_radius" -v a="$angle" 'BEGIN { printf "%.10f", (d * cos(a)) / 111320 }')
  delta_lon=$(awk -v d="$random_radius" -v a="$angle" -v lat="$lat" 'BEGIN { printf "%.10f", (d * sin(a)) / (111320 * cos(lat * 3.14159265359 / 180)) }')
  lat=$(awk -v l="$lat" -v d="$delta_lat" 'BEGIN { printf "%.10f", l + d }')
  lon=$(awk -v l="$lon" -v d="$delta_lon" 'BEGIN { printf "%.10f", l + d }')
  current_location="($lat, $lon)"
  log_debug "run" "Position randomisiert um $random_radius Meter: $current_location"
}

safe_locsim_start() {
  IFS=',' read -r lat lon <<< "${current_location//[()]/}"
  log_debug "locsim" "Starte locsim mit Koordinaten: $lat, $lon"
  locsim start "$lat" "$lon"
}

log_debug "init" "Starte Autorelo-Skript. auto_wait_time=${auto_wait_time}min, check_interval=${check_interval_minutes}min, debug_mode=$debug_mode"
last_run_time=0

# Hauptloop
while true; do
  current_time=$(date +%s)
  elapsed=$((current_time - last_run_time))

  if (( elapsed >= auto_wait_seconds )); then
    select_random_location_from_file
    randomize_location
    safe_locsim_start
    last_run_time=$(date +%s)
    sleep_duration="$check_interval_seconds"
  else
    sleep_duration=$((auto_wait_seconds - elapsed))
    if (( sleep_duration > check_interval_seconds )); then
      sleep_duration="$check_interval_seconds"
    fi
    log_debug "run" "Noch $elapsed Sekunden vergangen. Nächster Check in ${sleep_duration}s."
  fi

  sleep "$sleep_duration"
done
