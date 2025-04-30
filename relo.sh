#!/bin/bash

# Function to convert degrees, minutes, seconds to decimal
dms_to_decimal() {
# Example: 37° 46' 30" N -> 37.7750
# Example: 122° 25' 9" W -> -122.4192

# Check if the input is in the format "dd° mm' ss''" or "dd° mm'"
regex="^([0-9]+)°\s*([0-9]+)'?\s*([0-9]*\.?[0-9]+)?\"?\s*([NSWE])$"
if [[ "$1" =~ $regex ]]; then
degrees="${BASH_REMATCH[1]}"
minutes="${BASH_REMATCH[2]}"
seconds="${BASH_REMATCH[3]:-0}" # Default to 0 if no seconds are provided
direction="${BASH_REMATCH[4]}"

# Convert DMS to decimal
decimal=$(echo "scale=6; $degrees + $minutes / 60 + $seconds / 3600" | bc)

# Apply negative sign if the direction is South or West
if [[ "$direction" == "S" || "$direction" == "W" ]]; then
decimal=$(echo "$decimal * -1" | bc)
fi

echo "$decimal"
else
echo "Invalid DMS format: $1"
exit 1
fi
}

# Check if there are exactly two arguments (latitude and longitude)
if [ $# -ne 2 ]; then
echo "Usage: ./relo.sh <latitude> <longitude>"
exit 1
fi

# Get the latitude and longitude inputs
latitude_input=$1
longitude_input=$2

# Convert the latitude and longitude to decimal format if needed
latitude_decimal=$(dms_to_decimal "$latitude_input")
longitude_decimal=$(dms_to_decimal "$longitude_input")

# Display the converted coordinates (optional)
echo "Latitude: $latitude_decimal"
echo "Longitude: $longitude_decimal"

# Start LocSim with the provided coordinates
locsim start $latitude_decimal $longitude_decimal