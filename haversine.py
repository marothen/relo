#!/usr/bin/env python3
import math
import sys

if len(sys.argv) != 5:
    print("Usage: haversine.py lat1 lon1 lat2 lon2", file=sys.stderr)
    sys.exit(1)

try:
    lat1, lon1, lat2, lon2 = map(float, sys.argv[1:])
except ValueError:
    print("Invalid coordinates", file=sys.stderr)
    sys.exit(1)

R = 6371000  # Radius of Earth in meters
phi1 = math.radians(lat1)
phi2 = math.radians(lat2)
dphi = math.radians(lat2 - lat1)
dlambda = math.radians(lon2 - lon1)

a = math.sin(dphi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda/2)**2
c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
print(f"{R * c:.6f}")
