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

# Haversine distance function in awk (no bc, radians inside awk)
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

# Interpolates a point between (lat1, lon1) and (lat2, lon2) at given ratio (0..1)
interpolate_point() {
  awk -v lat1="$1" -v lon1="$2" -v lat2="$3" -v lon2="$4" -v ratio="$5" '
  BEGIN {
    lat = lat1 + (lat2 - lat1) * ratio
    lon = lon1 + (lon2 - lon1) * ratio
    printf "%.6f %.6f", lat, lon
  }'
}

# Step 1: Select subdirectory
log "Choose a subdirectory under './rou':"
subdirs=$(find ./rou -mindepth 1 -maxdepth 1 -type d)
i=1
for dir in $subdirs; do
  echo "$i) $dir"
  i=$((i + 1))
done

read -rp "Enter the number corresponding to the subdirectory: " subdir_index
subdir=$(echo "$subdirs" | sed -n "${subdir_index}p")

# Step 2: Select GPX file
log "Choose a GPX file in '$subdir':"
gpx_files=$(find "$subdir" -type f -name "*.gpx")
i=1
for file in $gpx_files; do
  echo "$i) $file"
  i=$((i + 1))
done

read -rp "Enter the number corresponding to the GPX file: " gpx_file_index
gpx_file=$(echo "$gpx_files" | sed -n "${gpx_file_index}p")

# Step 3: Get speed
read -rp "Enter speed in km/h: " SPEED_KMH
SPEED=$(expr "$SPEED_KMH" \* 1000 / 3600)

# Step 4: Interval in minutes or seconds
echo "Choose the interval unit:"
echo "1) Minutes"
echo "2) Seconds"
read -rp "Enter 1 for minutes or 2 for seconds: " interval_choice
if [ "$interval_choice" -eq 1 ]; then
  read -rp "Enter wait interval in minutes: " TRIGGER_INTERVAL
  INTERVAL_SECONDS=$((TRIGGER_INTERVAL * 60))
elif [ "$interval_choice" -eq 2 ]; then
  read -rp "Enter wait interval in seconds: " INTERVAL_SECONDS
else
  echo "Invalid choice." >&2
  exit 1
fi

# Step 5: Parse coordinates
coords=$(awk -F'"' '/<trkpt / { print $2, $4 }' "$gpx_file")
if [ -z "$coords" ]; then
  echo "No coordinates found in GPX file. Exiting." >&2
  exit 1
fi

# Load into array
IFS='
'
coord_array=($coords)
unset IFS
num_points=${#coord_array[@]}

# Initialize simulation
curr_index=0
read lat lon <<EOF
${coord_array[$curr_index]}
EOF
curr_lat="$lat"
curr_lon="$lon"

log "Starting simulation at $curr_lat $curr_lon"
safe_locsim_start "$curr_lat" "$curr_lon"
echo "Sleeping for $INTERVAL_SECONDS seconds before starting the simulation."
sleep "$INTERVAL_SECONDS"

while [ "$curr_index" -lt $((num_points - 1)) ]; do
  distance_needed=$((SPEED * INTERVAL_SECONDS))
  segment_start_lat="$curr_lat"
  segment_start_lon="$curr_lon"

  # Traverse until we find the segment we're landing in
  while [ "$curr_index" -lt $((num_points - 1)) ]; do
    read next_lat next_lon <<EOF
${coord_array[$((curr_index + 1))]}
EOF

    segment_distance=$(haversine_distance "$segment_start_lat" "$segment_start_lon" "$next_lat" "$next_lon")
    segment_distance_int=$(printf "%.0f" "$segment_distance")

    if [ "$distance_needed" -le "$segment_distance_int" ]; then
      # Interpolate and break
      ratio=$(awk -v d="$distance_needed" -v sd="$segment_distance" 'BEGIN { printf "%.8f", d / sd }')
      read landing_lat landing_lon <<EOF
$(interpolate_point "$segment_start_lat" "$segment_start_lon" "$next_lat" "$next_lon" "$ratio")
EOF
      log "Triggering locsim at $landing_lat $landing_lon"
      safe_locsim_start "$landing_lat" "$landing_lon"
      sleep "$INTERVAL_SECONDS"
      curr_lat="$landing_lat"
      curr_lon="$landing_lon"
      break
    else
      distance_needed=$((distance_needed - segment_distance_int))
      segment_start_lat="$next_lat"
      segment_start_lon="$next_lon"
      curr_index=$((curr_index + 1))
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

log "Simulation complete."
