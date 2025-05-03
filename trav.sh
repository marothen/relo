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
  lat1="$1"
  lon1="$2"
  lat2="$3"
  lon2="$4"
  R="$5"
  
  pi="3.141592653589793"
  
  # Calculate change in latitude and longitude
  dlat=$(echo "$lat2 - $lat1" | awk '{print $1}')
  dlon=$(echo "$lon2 - $lon1" | awk '{print $1}')
  
  # Convert to radians
  dlat_rad=$(echo "$dlat * $pi / 180" | awk '{print $1}')
  dlon_rad=$(echo "$dlon * $pi / 180" | awk '{print $1}')
  
  # Haversine formula (simplified for compatibility)
  a=$(echo "s($dlat_rad / 2)^2 + c($lat1 * $pi / 180) * c($lat2 * $pi / 180) * s($dlon_rad / 2)^2" | awk '{print $1}')
  c=$(echo "2 * a( sqrt($a), sqrt(1 - $a) )" | awk '{print $1}')
  distance=$(echo "$R * $c" | awk '{print $1}')
  
  echo $distance
}

# Get the list of subdirectories under ./rou
echo "📂 Choose a subdirectory under './rou':"
subdirs=$(find ./rou -mindepth 1 -maxdepth 1 -type d)
i=1
for dir in $subdirs; do
  echo "$i) $dir"
  i=$((i + 1))
done

read -p "Enter the number corresponding to the subdirectory: " subdir_index
subdir=$(echo "$subdirs" | sed -n "${subdir_index}p")

# Get the list of GPX files in the chosen subdirectory
echo "📂 Choose a GPX file in '$subdir':"
gpx_files=$(find "$subdir" -type f -name "*.gpx")
i=1
for file in $gpx_files; do
  echo "$i) $file"
  i=$((i + 1))
done

read -p "Enter the number corresponding to the GPX file: " gpx_file_index
gpx_file=$(echo "$gpx_files" | sed -n "${gpx_file_index}p")

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
  TRIGGER_INTERVAL_SECONDS=$((TRIGGER_INTERVAL * 60))
elif [ "$interval_choice" -eq 2 ]; then
  read -p "Enter the interval between locsim triggers in seconds: " TRIGGER_INTERVAL_SECONDS
else
  echo "Invalid choice. Exiting."
  exit 1
fi

# Derived values (using integer arithmetic)
SPEED=$(($SPEED_KMH * 1000 / 3600))  # Convert speed to meters per second
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
    dist=$(haversine_distance "$prev_lat" "$prev_lon" "$lat" "$lon" "$EARTH_RADIUS")
    step_time=$((dist / SPEED))  # Calculate step time in seconds (integer division)
    simulated_time=$((simulated_time + step_time))  # Add step time to the total simulated time
    time_since_last_trigger=$((time_since_last_trigger + step_time))  # Increment time since last trigger

    # Trigger locsim if enough time has passed
    if [ "$time_since_last_trigger" -ge "$TRIGGER_INTERVAL_SECONDS" ]; then
      echo "[🚀] Triggering locsim at simulated time $simulated_time s → $lat $lon"
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
