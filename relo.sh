#!/bin/bash

# Function to normalize coordinates like 48,18889° N or 11,57444° E
normalize_coord() {
input="$1"

# Replace comma with dot
coord=$(echo "$input" | sed 's/,/./')

# Extract numeric part and direction
value=$(echo "$coord" | grep -oE '[0-9.]+')
direction=$(echo "$coord" | grep -oE '[NSEW]')

# Apply negative sign for South or West
if [[ "$direction" == "S" || "$direction" == "W" ]]; then
value="-$value"
fi

echo "$value"
}

# Check for a single input argument
if [ $# -ne 1 ]; then
echo "Usage: ./relo.sh \"<latitude>, <longitude>\""
echo "Example: ./relo.sh \"48,18889° N, 11,57444° E\""
exit 1
fi

# Split input by the first comma
IFS=',' read -r lat_input lon_input <<< "$1"

# Trim leading/trailing whitespace from both
lat_input=$(echo "$lat_input" | sed 's/^[ \t]*//;s/[ \t]*$//')
lon_input=$(echo "$lon_input" | sed 's/^[ \t]*//;s/[ \t]*$//')

# Normalize
latitude=$(normalize_coord "$lat_input")
longitude=$(normalize_coord "$lon_input")

# Show results
echo "Latitude: $latitude"
echo "Longitude: $longitude"

# Run LocSim
locsim start "$latitude" "$longitude"