#!/bin/bash

LOCATION_LOG_FILE="./track/location_latest.txt"
PID_FILE="./track/runpid.pid"
touch "$PID_FILE"
NEW_PID=$$
# Append the new PID as a new line to the PID file
echo "$NEW_PID" >> "$PID_FILE"

# --- 1. Read positional arguments ---
GPX_FILE="$1"
SPEED_KMH="$2"
INTERVAL_SECONDS="$3"

# Initialize optional parameters
START_LAT=""
START_LON=""
ENABLE_DEBUG=false

# --- 2. Handle optional parameters ---
if [ "$#" -eq 4 ] && [ "$4" = "debug" ]; then
  ENABLE_DEBUG=true
elif [ "$#" -eq 5 ]; then
  START_LAT="$4"
  START_LON="$5"
elif [ "$#" -eq 6 ] && [ "$6" = "debug" ]; then
  START_LAT="$4"
  START_LON="$5"
  ENABLE_DEBUG=true
fi

log_debug() {
  if [[ "$ENABLE_DEBUG" == true ]]; then
    local debug_file="./debug/atrav_debug.log"  # Path to the debug file
    mkdir -p "$(dirname "$debug_file")"        # Ensure the directory exists
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$debug_file"
  fi
}

# --- 2. Validate required parameters ---
if [ -z "$GPX_FILE" ] || [ -z "$SPEED_KMH" ] || [ -z "$INTERVAL_SECONDS" ]; then
  log_debug "Usage: $0 <gpx_file> <speed_kmh> <interval_seconds> [<start_lat> <start_lon>]"
  exit 1
fi

# Check that speed and interval are integers
if ! echo "$SPEED_KMH" | grep -Eq '^[0-9]+$' || ! echo "$INTERVAL_SECONDS" | grep -Eq '^[0-9]+$'; then
  log_debug "Error: speed_kmh and interval_seconds must be integers. Speed: $SPEED_KMH, Interval: $INTERVAL_SECONDS"
  exit 1
fi

# Ensure either both lat/lon are given or neither
#if { [ -n "$START_LAT" ] && [ -z "$START_LON" ]; } || \
#   { [ -z "$START_LAT" ] && [ -n "$START_LON" ]; }; then
#  log_debug "Error: Either provide both latitude and longitude, or neither."
#  log_debug "Usage: $0 <gpx_file> <speed_kmh> <interval_seconds> [<start_lat> <start_lon>]"
#  exit 1
#fi

# If both are provided, validate their numeric format
#if [ -n "$START_LAT" ] && [ -n "$START_LON" ]; then
#  if ! echo "$START_LAT" | grep -Eq '^-?[0-9]+(\.[0-9]+)?$' || \
#     ! echo "$START_LON" | grep -Eq '^-?[0-9]+(\.[0-9]+)?$'; then
#    log_debug "Error: Invalid format for latitude or longitude. Must be decimal numbers."
#    exit 1
#  fi
#fi

# --- 3. Define helper functions ---

safe_locsim_start() {
  lat="$1"
  lon="$2"
  echo "$lat $lon" > "$LOCATION_LOG_FILE"   # Overwrite file with latest coords
  log_debug "Position saved to $LOCATION_LOG_FILE: ($lat, $lon)"
  if ! command -v locsim >/dev/null 2>&1; then
    log_debug "Warning: 'locsim' is not installed or not in your PATH."
    return 1
  fi
  locsim start "$lat" "$lon"
}

haversine_distance() {
  awk -v lat1="$1" -v lon1="$2" -v lat2="$3" -v lon2="$4" '
  function to_rad(x) { return x * 3.141592653589793 / 180 }
  BEGIN {
    R = 6371000
    dlat = to_rad(lat2 - lat1)
    dlon = to_rad(lon2 - lon1)
    lat1 = to_rad(lat1)
    lat2 = to_rad(lat2)
    a = sin(dlat/2)^2 + cos(lat1)*cos(lat2)*sin(dlon/2)^2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    print R * c
  }'
}

interpolate_point() {
  awk -v lat1="$1" -v lon1="$2" -v lat2="$3" -v lon2="$4" -v ratio="$5" '
  BEGIN {
    lat = lat1 + (lat2 - lat1) * ratio
    lon = lon1 + (lon2 - lon1) * ratio
    printf "%.6f %.6f", lat, lon
  }'
}
log_debug "Starting simulation with GPX file: $GPX_FILE, Speed: $SPEED_KMH km/h, Interval: $INTERVAL_SECONDS seconds"
# --- 4. Read GPX coordinates ---
coords=$(awk -F'"' '/<trkpt / { print $2, $4, $6}' "$GPX_FILE")
if [ -z "$coords" ]; then
  log_debug "No coordinates found in GPX file $GPX_FILE. Exiting." >&2
  exit 1
fi

coord_tmp=$(mktemp)
echo "$coords" > "$coord_tmp"
num_points=$(wc -l < "$coord_tmp")

# --- 5. Determine starting point ---
if [ -n "$START_LAT" ] && [ -n "$START_LON" ]; then
  log_debug "Finding the closest GPX point to ($START_LAT, $START_LON)..."
    # Initialize margins
  left_margin=1
  right_margin="$num_points"
  found_index=""
  min_distance=999999999

  while [ "$left_margin" -le "$right_margin" ]; do
    # Calculate the middle point
    middle_index=$(( (left_margin + right_margin) / 2 ))
    middle_line=$(sed -n "${middle_index}p" "$coord_tmp")
    middle_lat=$(echo "$middle_line" | awk '{print $1}')
    middle_lon=$(echo "$middle_line" | awk '{print $2}')

    # Calculate distances for left, middle, and right points
    left_line=$(sed -n "${left_margin}p" "$coord_tmp")
    left_lat=$(echo "$left_line" | awk '{print $1}')
    left_lon=$(echo "$left_line" | awk '{print $2}')
    left_distance=$(python3 ./haversine.py "$START_LAT" "$START_LON" "$left_lat" "$left_lon")

    right_line=$(sed -n "${right_margin}p" "$coord_tmp")
    right_lat=$(echo "$right_line" | awk '{print $1}')
    right_lon=$(echo "$right_line" | awk '{print $2}')
    right_distance=$(python3 ./haversine.py "$START_LAT" "$START_LON" "$right_lat" "$right_lon")

    middle_distance=$(python3 ./haversine.py "$START_LAT" "$START_LON" "$middle_lat" "$middle_lon")

    # Update the closest point if the middle point is closer
    if (( $(printf "%.0f" "$middle_distance") < min_distance )); then
      min_distance=$(printf "%.0f" "$middle_distance")
      found_index="$middle_index"
    fi

    # Narrow the search space
    if (( $(printf "%.0f" "$left_distance") < $(printf "%.0f" "$right_distance") )); then
      right_margin=$((middle_index - 1))
    else
      left_margin=$((middle_index + 1))
    fi
  done


  if [ -z "$found_index" ]; then
    log_debug "Error: Could not find a starting point near ($START_LAT, $START_LON)." >&2
    exit 1
  fi
  log_debug "Closest point at index $found_index (distance $min_distance m)."
  curr_index=$found_index
  curr_lat=$(sed -n "${curr_index}p" "$coord_tmp" | awk '{print $1}')
  curr_lon=$(sed -n "${curr_index}p" "$coord_tmp" | awk '{print $2}')
else
  # Start at the very first point
  curr_index=1
  curr_lat=$(sed -n "1p" "$coord_tmp" | awk '{print $1}')
  curr_lon=$(sed -n "1p" "$coord_tmp" | awk '{print $2}')
fi

# --- 6. Kick off the simulation ---
safe_locsim_start "$curr_lat" "$curr_lon"
log_debug "Sleeping for $INTERVAL_SECONDS seconds before continuing..."
sleep "$INTERVAL_SECONDS"

SPEED=$(( SPEED_KMH * 1000 / 3600 ))

while [ "$curr_index" -lt $(( num_points - 1 )) ]; do
  start_time=$(date +%s)
  segment_start_lat="$curr_lat"
  segment_start_lon="$curr_lon"
  distance_needed=$(( SPEED * INTERVAL_SECONDS ))
  remaining_interval="$INTERVAL_SECONDS"

  while [ "$curr_index" -lt $(( num_points - 1 )) ]; do
    next_line=$(sed -n "$(( curr_index + 1 ))p" "$coord_tmp")
    next_lat=$(echo "$next_line" | awk '{print $1}')
    next_lon=$(echo "$next_line" | awk '{print $2}')
    next_wait=$(echo "$next_line" | awk '{print $3}')
    segment_distance=$(python3 ./haversine.py "$segment_start_lat" "$segment_start_lon" "$next_lat" "$next_lon")
    segment_distance_int=$(printf "%.0f" "$segment_distance")

    if [ "$distance_needed" -le "$segment_distance_int" ]; then
      ratio=$(awk -v d="$distance_needed" -v sd="$segment_distance" 'BEGIN { printf "%.8f", d / sd }')
      landing_point=$(interpolate_point "$segment_start_lat" "$segment_start_lon" "$next_lat" "$next_lon" "$ratio")
      landing_lat=$(echo "$landing_point" | awk '{print $1}')
      landing_lon=$(echo "$landing_point" | awk '{print $2}')

      safe_locsim_start "$landing_lat" "$landing_lon"

      end_time=$(date +%s)
      elapsed=$(( end_time - start_time ))
      if [ "$elapsed" -gt "$remaining_interval" ]; then
        remaining_interval=0
      else
        remaining_interval=$(( remaining_interval - elapsed ))
      fi

      sleep "$remaining_interval"
      curr_lat="$landing_lat"
      curr_lon="$landing_lon"
      break
    else
      if [ -n "$next_wait" ]; then
        safe_locsim_start "$next_lat" "$next_lon"
        sleep "$next_wait"
        distance_needed=$(( SPEED * INTERVAL_SECONDS ))
        segment_start_lat="$next_lat"
        segment_start_lon="$next_lon"
        curr_index=$(( curr_index + 1 ))
      else
        distance_needed=$(( distance_needed - segment_distance_int ))
        segment_start_lat="$next_lat"
        segment_start_lon="$next_lon"
        curr_index=$(( curr_index + 1 ))
      fi
    fi
  done

  if [ "$curr_index" -ge $(( num_points - 1 )) ]; then
    final_lat="$segment_start_lat"
    final_lon="$segment_start_lon"
    last_distance=$(haversine_distance "$curr_lat" "$curr_lon" "$final_lat" "$final_lon")
    last_seconds=$(awk -v d="$last_distance" -v s="$SPEED" 'BEGIN { printf "%.0f", d / s }')
    sleep "$last_seconds"
    safe_locsim_start "$final_lat" "$final_lon"
    break
  fi
done

# --- 7. Cleanup ---
rm -f "$coord_tmp"
log_debug "Simulation complete."
