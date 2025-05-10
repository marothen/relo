#!/bin/sh

LOGGING=0
[ "$1" = "--log" ] && LOGGING=1

log() {
  [ "$LOGGING" -eq 1 ] && echo "$@"
}

# Function to safely call locsim
safe_locsim_start() {
  if ! command -v locsim >/dev/null 2>&1; then
    echo "Warning: 'locsim' is not installed or not in your PATH." >&2
    return 1
  fi
  locsim start "$@"
}

# Haversine distance function
haversine_distance() {
  awk -v lat1="$1" -v lon1="$2" -v lat2="$3" -v lon2="$4" '
  function to_rad(x) { return x * 3.141592653589793 / 180 }
  BEGIN {
    R = 6371000
    dlat = to_rad(lat2 - lat1)
    dlon = to_rad(lon2 - lon1)
    lat1 = to_rad(lat1)
    lat2 = to_rad(lat2)
    a = sin(dlat / 2)^2 + cos(lat1) * cos(lat2) * sin(dlon / 2)^2
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

#subdir="./rou/short"
#gpx_file="./rou/short/kirchberg/Wanderung14KM.gpx"
#INTERVAL_SECONDS=10
#SPEED_KMH=7
#START_LAT="48.357818"
#START_LON="8.730149"
LOGGING=0

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --lat)
      START_LAT="$2"
      shift 2
      ;;
    --lon)
      START_LON="$2"
      shift 2
      ;;
    --log)
      LOGGING=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate presence of both or none
if { [ -n "$START_LAT" ] && [ -z "$START_LON" ]; } || \
   { [ -z "$START_LAT" ] && [ -n "$START_LON" ]; }; then
  echo "Error: Both --lat and --lon must be provided together." >&2
  exit 1
fi

# Validate numeric format
if [ -n "$START_LAT" ] && [ -n "$START_LON" ]; then
  if ! echo "$START_LAT" | grep -Eq '^-?[0-9]+(\.[0-9]+)?$' || \
     ! echo "$START_LON" | grep -Eq '^-?[0-9]+(\.[0-9]+)?$'; then
    echo "Error: Invalid format for --lat or --lon. Must be decimal numbers." >&2
    exit 1
  fi
fi



if [ -z "$gpx_file" ]; then
    # Step 1: Select subdirectory
    log "Choose a subdirectory under './rou':"
    subdir_tmp=$(mktemp)
    find ./rou -mindepth 1 -maxdepth 1 -type d > "$subdir_tmp"

    i=1
    while IFS= read -r dir; do
    echo "$i) $dir"
    i=$((i + 1))
    done < "$subdir_tmp"

    printf "Enter the number corresponding to the subdirectory: "
    read -r subdir_index
    subdir=$(sed -n "${subdir_index}p" "$subdir_tmp")
    log "Using subdirectory: $subdir"
    rm -f "$subdir_tmp"

    # Step 2: Select GPX file
    log "Choose a GPX file in '$subdir':"
    gpx_tmp=$(mktemp)
    find "$subdir" -type f -name "*.gpx" > "$gpx_tmp"

    i=1
    while IFS= read -r file; do
    echo "$i) $file"
    i=$((i + 1))
    done < "$gpx_tmp"

    printf "Enter the number corresponding to the GPX file: "
    read -r gpx_file_index
    gpx_file=$(sed -n "${gpx_file_index}p" "$gpx_tmp")
    log "Using GPX file: $gpx_file"
    rm -f "$gpx_tmp"

    # Step 3: Get speed
    printf "Enter speed in km/h: "
    read -r SPEED_KMH
fi
SPEED=$(expr "$SPEED_KMH" \* 1000 / 3600)

if [ -z "$INTERVAL_SECONDS" ]; then
    # Step 4: Interval
    echo "Choose the interval unit:"
    echo "1) Minutes"
    echo "2) Seconds"
    printf "Enter 1 for minutes or 2 for seconds: "
    read -r interval_choice
    if [ "$interval_choice" -eq 1 ]; then
        printf "Enter wait interval in minutes: "
        read -r TRIGGER_INTERVAL
        INTERVAL_SECONDS=$((TRIGGER_INTERVAL * 60))
    elif [ "$interval_choice" -eq 2 ]; then
        printf "Enter wait interval in seconds: "
        read -r INTERVAL_SECONDS
    else
        echo "Invalid choice." >&2
    exit 1
    fi
fi

# Step 5: Parse coordinates
coords=$(awk -F'"' '/<trkpt / { print $2, $4, $6}' "$gpx_file")
if [ -z "$coords" ]; then
  echo "No coordinates found in GPX file. Exiting." >&2
  exit 1
fi

# Load into array
coord_tmp=$(mktemp)
echo "$coords" > "$coord_tmp"

num_points=$(wc -l < "$coord_tmp")

# Step 5: Parse coordinates
coords=$(awk -F'"' '/<trkpt / { print $2, $4, $6}' "$gpx_file")
if [ -z "$coords" ]; then
  echo "No coordinates found in GPX file. Exiting." >&2
  exit 1
fi

# Load into array
coord_tmp=$(mktemp)
echo "$coords" > "$coord_tmp"

num_points=$(wc -l < "$coord_tmp")

# Optional: Start from given lat/lon
if [ -n "$START_LAT" ] || [ -n "$START_LON" ]; then
  if ! echo "$START_LAT" | grep -Eq '^[-+]?[0-9]+(\.[0-9]+)?$' || ! echo "$START_LON" | grep -Eq '^[-+]?[0-9]+(\.[0-9]+)?$'; then
    echo "Error: Both --startlat and --startlon must be valid floating point numbers." >&2
    exit 1
  fi

  min_distance=999999999
  prev_distance=999999999
  increasing_count=0
  found_index=""
  for i in $(seq 1 $num_points); do
    line=$(sed -n "${i}p" "$coord_tmp")
    lat=$(echo "$line" | awk '{print $1}')
    lon=$(echo "$line" | awk '{print $2}')
    distance=$(python3 ./haversine.py "$START_LAT" "$START_LON" "$lat" "$lon")
    distance_int=$(printf "%.0f" "$distance")

    if [ "$distance_int" -gt "$prev_distance" ]; then
      found_index="$i"
      break
    fi
    prev_distance="$distance_int"
  done

  if [ -z "$found_index" ]; then
    echo "Error: Could not determine a start location close to the given coordinates." >&2
    exit 1
  fi

  curr_index=$((found_index - 1))
  curr_lat=$(sed -n "${found_index}p" "$coord_tmp" | awk '{print $1}')
  curr_lon=$(sed -n "${found_index}p" "$coord_tmp" | awk '{print $2}')
else
  curr_index=1
  curr_lat=$(sed -n "1p" "$coord_tmp" | awk '{print $1}')
  curr_lon=$(sed -n "1p" "$coord_tmp" | awk '{print $2}')
fi



log "SPEED: $SPEED m/s"
log "Interval: $INTERVAL_SECONDS seconds"

log "Starting simulation at $curr_lat $curr_lon"
safe_locsim_start "$curr_lat" "$curr_lon"
echo "Sleeping for $INTERVAL_SECONDS seconds before starting the simulation."
sleep "$INTERVAL_SECONDS"

while [ "$curr_index" -lt $((num_points - 1)) ]; do
  start=$(date +%s)
  segment_start_lat="$curr_lat"
  segment_start_lon="$curr_lon"
  distance_needed=$((SPEED * INTERVAL_SECONDS))
  current_interval_seconds=$INTERVAL_SECONDS
  log "Distance needed: $distance_needed meters"

  while [ "$curr_index" -lt $((num_points - 1)) ]; do
    next_line=$(sed -n "$((curr_index + 1))p" "$coord_tmp")
    next_lat=$(echo "$next_line" | awk '{print $1}')
    next_lon=$(echo "$next_line" | awk '{print $2}')
    next_wait=$(echo "$next_line" | awk '{print $3}')
    log "Next line: $next_line"
    log "Next point: $next_lat $next_lon"

    #segment_distance=$(haversine_distance "$segment_start_lat" "$segment_start_lon" "$next_lat" "$next_lon")
    segment_distance=$(python3 ./haversine.py "$segment_start_lat" "$segment_start_lon" "$next_lat" "$next_lon")

    segment_distance_int=$(printf "%.0f" "$segment_distance")
    log "Segment distance: $segment_distance"
    log "Segment distance int: $segment_distance_int meters"

    if [ "$distance_needed" -le "$segment_distance_int" ]; then
      ratio=$(awk -v d="$distance_needed" -v sd="$segment_distance" 'BEGIN { printf "%.8f", d / sd }')
      landing_point=$(interpolate_point "$segment_start_lat" "$segment_start_lon" "$next_lat" "$next_lon" "$ratio")
      landing_lat=$(echo "$landing_point" | awk '{print $1}')
      landing_lon=$(echo "$landing_point" | awk '{print $2}')
      log "segment $segment_start_lat $segment_start_lon"
      log "landing $landing_lat $landing_lon"
      log "current $curr_lat $curr_lon"

      log "Triggering locsim at $landing_lat $landing_lon"
      safe_locsim_start "$landing_lat" "$landing_lon"
      end=$(date +%s)
      elapsed=$((end - start))
      # Subtract, ensuring no negative result
      if [ "$elapsed" -gt "$current_interval_seconds" ]; then
        current_interval_seconds=0
      else
        current_interval_seconds=$((current_interval_seconds - elapsed))
      fi
      sleep "$current_interval_seconds"
      curr_lat="$landing_lat"
      curr_lon="$landing_lon"
      break
    else
      if [ -n "$next_wait" ]; then
        echo "Triggering locsim at $next_lat $next_lon for pause"
        safe_locsim_start "$next_lat" "$next_lon"
        echo "Sleeping for $next_wait seconds at $next_lat $next_lon for pause"
        end=$(date +%s)
        sleep "$next_wait"
        distance_needed=$((SPEED * INTERVAL_SECONDS))
        segment_start_lat="$next_lat"
        segment_start_lon="$next_lon"
        curr_index=$((curr_index + 1))
      else
        distance_needed=$((distance_needed - segment_distance_int))
        segment_start_lat="$next_lat"
        segment_start_lon="$next_lon"
        curr_index=$((curr_index + 1))
      fi
    fi
  done

  if [ "$curr_index" -ge $((num_points - 1)) ]; then
    final_lat="$segment_start_lat"
    final_lon="$segment_start_lon"
    last_distance=$(haversine_distance "$curr_lat" "$curr_lon" "$final_lat" "$final_lon")
    last_seconds=$(awk -v d="$last_distance" -v s="$SPEED" 'BEGIN { printf "%.0f", d / s }')
    log "Final leg: sleeping $last_seconds seconds, then triggering final point $final_lat $final_lon"
    sleep "$last_seconds"
    safe_locsim_start "$final_lat" "$final_lon"
    break
  fi
done

rm -f "$coord_tmp"
log "Simulation complete."
