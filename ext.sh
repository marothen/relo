#!/bin/sh

# Input GPX file
input_file="./rou/long/elc_muc.gpx"

# Check for input
if [ ! -f "$input_file" ]; then
  echo "File not found: $input_file"
  exit 1
fi

# Get output filename: strip .gpx and add _ext.gpx
base=$(basename "$input_file" .gpx)
dir=$(dirname "$input_file")
output_file="$dir/${base}_ext.gpx"

# Process file with awk (portable version)
awk '
function haversine(lat1, lon1, lat2, lon2,    pi, R, dlat, dlon, a, c) {
    pi = 3.141592653589793
    R = 6371000
    dlat = (lat2 - lat1) * pi / 180
    dlon = (lon2 - lon1) * pi / 180
    lat1 = lat1 * pi / 180
    lat2 = lat2 * pi / 180
    a = sin(dlat/2)^2 + cos(lat1) * cos(lat2) * sin(dlon/2)^2
    c = 2 * atan2(sqrt(a), sqrt(1-a))
    return R * c
}

BEGIN {
  total = 0
}

/<trkpt / {
  match($0, /lat="([^"]+)"/, a)
  match($0, /lon="([^"]+)"/, b)
  lat = a[1]
  lon = b[1]

  if (lat0 != "") {
    d = haversine(lat0, lon0, lat, lon)
    total += d
  }

  lat0 = lat
  lon0 = lon

  print
  printf("  <extensions><distance>%.2f</distance></extensions>\n", d)
  next
}

{ print }
' "$input_file" > "$output_file"

echo "New file written: $output_file"
