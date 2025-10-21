import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:audioloca/environment.dart';

final log = Logger();

class LocationServices {
  final bool useMockLocation;
  final double? mockLatitude;
  final double? mockLongitude;

  LocationServices({
    this.useMockLocation = false,
    this.mockLatitude,
    this.mockLongitude,
  });

  StreamSubscription<Position>? positionStream;
  DateTime? lastUpdate;

  Future<bool> ensureLocationReady(BuildContext context) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final position = await getUserPosition();
      log.i(
        '[Flutter] Position acquired: ${position.latitude}, ${position.longitude}',
      );
      return true;
    } catch (e, stackTrace) {
      log.w('[Flutter] Location error: $e $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return false;
    }
  }

  Future<Position> getUserPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw 'Please enable location services in settings.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permission denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw 'Location permission permanently denied. Enable it in app settings.';
    }

    if (useMockLocation) {
      log.i('[Flutter] Using mock location: $mockLatitude, $mockLongitude');
      return Position(
        latitude: mockLatitude!,
        longitude: mockLongitude!,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
      );
    }

    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    return await Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );
  }

  void startRealtimeTracking({
    required void Function(Position position) onLocationUpdate,
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 100,
  }) {
    if (useMockLocation) {
      final mockPosition = Position(
        latitude: mockLatitude!,
        longitude: mockLongitude!,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
        altitudeAccuracy: 1.0,
      );

      log.i('[Flutter] Using mock location: $mockLatitude, $mockLongitude');
      onLocationUpdate(mockPosition);
      return;
    }

    final locationSettings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );

    positionStream =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          final now = DateTime.now();

          if (lastUpdate != null &&
              now.difference(lastUpdate!) < const Duration(minutes: 1)) {
            return;
          }

          lastUpdate = now;

          log.i(
            '[Flutter] Real-time location: ${position.latitude}, ${position.longitude}',
          );

          onLocationUpdate(position);
        });
  }

  Future<String?> getLocationIQAddress(
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse(
      '${Environment.locationIQBaseUrl}/reverse?key=${Environment.locationIQAccessToken}&lat=$latitude&lon=$longitude&format=json&',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data["name"] ?? data["display_name"];

        log.i(
          "[Flutter] Latitude: $latitude, Longitude: $longitude, Location Address: $address",
        );

        return address;
      } else {
        log.i('Error: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] LocationIQ error: $e $stackTrace');
      return null;
    }
  }

  void stopRealtimeTracking() {
    positionStream?.cancel();
    positionStream = null;
  }
}
