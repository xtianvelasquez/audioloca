import os
import json
import random
import numpy as np

zone_coords = {
    'north': (14.594301, 120.970374),   # Fort Santiago
    'west': (14.589317, 120.975216),    # San Agustin Church
    'east': (14.587068, 120.976201),    # University of the City of Manila
    'south': (14.587429, 120.974754),   # Santa Lucia Barracks
    'center': (14.591835, 120.9733458), # Manila Cathedral
}

zones = list(zone_coords.keys())
zone_pool = zones * 20
random.shuffle(zone_pool)

base_dir = os.path.dirname(__file__)
metadata_path = os.path.abspath(os.path.join(base_dir, "metadata.json"))

try:
    with open(metadata_path, "r", encoding="utf-8") as f:
        metadata = json.load(f)
except FileNotFoundError:
    print(f"File not found: {metadata_path}")
    exit(1)

if len(metadata) != 100:
    print(f"Expected 100 songs, but found {len(metadata)}")
    exit(1)

def random_vicinity(lat, lon, radius_m=100):
    radius_deg = radius_m / 111_320
    lat_offset = random.uniform(-radius_deg, radius_deg)
    lon_offset = random.uniform(-radius_deg, radius_deg)
    return lat + lat_offset, lon + lon_offset

enriched_data = []
for song, zone in zip(metadata, zone_pool):
    stream_count = int(np.random.zipf(a=2.0) * 200)
    base_lat, base_lon = zone_coords[zone]
    lat, lon = random_vicinity(base_lat, base_lon)

    song.update({
        "zone": zone,
        "stream_count": stream_count,
        "latitude": lat,
        "longitude": lon
    })
    enriched_data.append(song)

output_path = os.path.join(base_dir, "updated_metadata.json")
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(enriched_data, f, indent=2)

print(f"Updated metadata saved to: {output_path}")
