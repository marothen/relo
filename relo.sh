#!/bin/bash

# Get clipboard contents
CLIPBOARD=$(pbpaste)

# Check for decimal format: "37.7749, -122.4194"
if [[ $CLIPBOARD =~ ^([+-]?[0-9]+(\.[0-9]+)?)\s*,\s*([+-]?[0-9]+(\.[0-9]+)?)$ ]]; then
LAT=${BASH_REMATCH[1]}
LON=${BASH_REMATCH[3]}

# Check for format with ° and direction: "37.7749° N, 122.4194° W"
elif [[ $CLIPBOARD =~ ^([0-9]+(\.[0-9]+)?)°?\s*([NnSs]),\s*([0-9]+(\.[0-9]+)?)°?\s*([EeWw])$ ]]; then
LAT=${BASH_REMATCH[1]}
LON=${BASH_REMATCH[4]}

# Apply direction
[[ "${BASH_REMATCH[3]}" =~ [Ss] ]] && LAT="-$LAT"
[[ "${BASH_REMATCH[6]}" =~ [Ww] ]] && LON="-$LON"

else
echo "Invalid format. Please copy coordinates like '37.7749, -122.4194'"
exit 1
fi

# Trigger LocSim
echo "Spoofing location to: $LAT, $LON"
locsim start "$LAT" "$LON"