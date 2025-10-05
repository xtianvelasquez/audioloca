import math

def haversine(lat1, lon1, lat2, lon2):
    """
    Calculate the great-circle distance between two points on Earth using the Haversine formula.

    Parameters:
        lat1, lon1: Latitude and longitude of point 1 (in decimal degrees)
        lat2, lon2: Latitude and longitude of point 2 (in decimal degrees)

    Returns:
        Distance between the two points in meters.
    """
    # Radius of Earth in meters
    R = 6371000  # 6371 km = 6,371,000 meters

    # Convert latitude and longitude from degrees to radians
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    # Haversine formula
    a = (math.sin(delta_phi / 2) ** 2 +
         math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2)

    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    # Distance in meters
    distance = R * c
    return distance


# Example usage:
if __name__ == "__main__":
    lat1, lon1 = 14.591835, 120.973346
    lat2, lon2 = 14.590700, 120.972000

    dist_meters = haversine(lat1, lon1, lat2, lon2)
    print(f"Distance: {dist_meters:.2f} meters")
