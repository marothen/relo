#!/bin/bash

# Check for a single argument
if [ $# -ne 1 ]; then
echo "Usage: ./relo.sh \"(latitude, longitude)\""
echo "Example: ./relo.sh \"(48.5108286, 12.6189519)\""
exit 1
fi

# Extract latitude and longitude using regex
input="$1"
cleaned=$(echo "$input" | sed -E 's/[^0-9.,-]//g') # remove parentheses and extra characters
IFS=',' read -r latitude longitude <<< "$cleaned"

# Trim whitespace (just in case)
latitude=$(echo "$latitude" | xargs)
longitude=$(echo "$longitude" | xargs)

# Optional: Show what was extracted
echo "Latitude: $latitude"
echo "Longitude: $longitude"

# Start LocSim
locsim start "$latitude" "$longitude"