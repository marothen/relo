#!/bin/sh

# Function to safely call locsim
safe_locsim_start() {
  if ! command -v locsim >/dev/null 2>&1; then
    echo "Error: 'locsim' is not installed or not in your PATH."
    return 1
  fi

  locsim start "$@"
}

# Function to compute haversine distance in meters
haversine_distance() {
  awk -v lat1="$1" -v lon1="$2" -v lat2="$3" -v lon2="$4" -v R="$EARTH_RADIUS" '
  BEGIN {
    pi = 3.141592653589793
    dlat = (lat2 - lat1) * pi / 180
    dlon = (lon2 - lon1) * pi / 180
    a = sin(dlat/2)^2 + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dlon/2)^2
    c = 2 * atan2(sqrt(a), sqrt(1-a))
    print R * c
  }'
}

# Get the list of subdirectories under ./rou
echo "📂 Choose a subdirectory under './rou':"
subdirs=$(find ./rou -mindepth 1 -maxdepth 1 -type d)
subdir_list=()
i=1
for dir in $subdirs; do
  echo "$i) $dir"
  subdir_list[$i]="$dir"
  i=$((i + 1))
done

read -p "Enter the number corresponding to the subdirectory: " subdir_index
subdir="${subdir_list[$subdir_index]}"

# Get the list of GPX files in the chosen subdirectory
echo "📂 Choose a GPX file in '$subdir':"
gpx_files=$(find "$subdir" -type f -name "*.gpx")
gpx_file_list=()
i=1
for file in $gpx_files; do
  echo "$i) $file"
  gpx_file_list[$i]="$file"
  i=$((i + 1))
done

read -p "Enter the number corresponding to the GPX file: " gpx_file_index
gpx_file="${gpx_file_list[$gpx_file_index]}"

# Get speed from user
read -p "Enter the speed in km/h: " SPEED_KMH

# Ask the user whether they want the interval in minutes or seconds
echo "⏱️ Choose the interval unit:"
echo "1) Minutes"
echo "2) Seconds"
read -p "Enter 1 for minutes or 2 for seconds: " interval_choice

# Get the interval based on user choice
if [ "$interval_choice" -eq 1 ]; then
  read -p "Enter the interval between locsim triggers in minutes: " TRIGGER_INTERVAL
  TRIGGER_INTERVAL_SECONDS=$(awk -v m="$TRIGGER_INTERVAL" 'BEGIN { print m * 60 }')
elif [ "$interval_choice" -eq 2 ]; then
  read -p "Enter the interval between locsim triggers in seconds: " TRIGGER_INTERVAL_SECONDS
else
  echo "Invalid choice. Exiting."
  exit 1
fi

# Derived values
SPEED=$(awk -v k="$SPEED_KMH" 'BEGIN { print k * 1000 / 3600 }')  # m/s
EARTH_RADIUS=6371000  # meters

# Extract coordinates from the chosen GPX file
coords=$(awk -F'"' '/<trkpt / { print $2, $4 }' "$gpx_file")

if [ -z "$coords" ]; then
  echo "❌ No coordinates found in GPX file. Check the file format." >&2
  exit 1
fi

# Initialization
prev_lat=""
prev_lon=""
simulated_time=0
time_since_last_trigger=0

echo "📍 Starting route simulation"
echo "→ Speed: ${SPEED_KMH} km/h"
echo "→ Trigger interval: every ${TRIGGER_INTERVAL} $([ "$interval_choice" -eq 1 ] && echo "minute(s)" || echo "second(s)") of simulated movement"

# Loop over the coordinates in the GPX file
echo "$coords" | while read -r lat lon; do
  if [ -n "$prev_lat" ]; then
    dist=$(haversine_distance "$prev_lat" "$prev_lon" "$lat" "$lon")
    step_time=$(awk -v d="$dist" -v s="$SPEED" 'BEGIN { print d / s }')
    simulated_time=$(awk -v a="$simulated_time" -v b="$step_time" 'BEGIN { print a + b }')
    time_since_last_trigger=$(awk -v a="$time_since_last_trigger" -v b="$step_time" 'BEGIN { print a + b }')

    if awk -v a="$time_since_last_trigger" -v b="$TRIGGER_INTERVAL_SECONDS" 'BEGIN { exit !(a >= b) }'; then
      echo "[🚀] Triggering locsim at simulated time $(awk -v t="$simulated_time" 'BEGIN { printf "%.0f", t }')s → $lat $lon"
      safe_locsim_start "$lat" "$lon"
      sleep "$TRIGGER_INTERVAL_SECONDS"
      time_since_last_trigger=0
    fi
  else
    echo "[▶️] Setting initial location: $lat $lon"
    safe_locsim_start "$lat" "$lon"
    sleep "$TRIGGER_INTERVAL_SECONDS"
  fi

  prev_lat="$lat"
  prev_lon="$lon"
done

# Make sure the last location is triggered
if [ -n "$prev_lat" ] && [ -n "$prev_lon" ]; then
  echo "[🚀] Triggering locsim for the last location: $prev_lat $prev_lon"
  safe_locsim_start "$prev_lat" "$prev_lon"
fi

echo "✅ Simulation complete. Destination reached."
