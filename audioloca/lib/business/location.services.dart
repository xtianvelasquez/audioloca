import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:audioloca/environment.dart';

final log = Logger();

class LocationServices {
  static LocationServices? _instance;

  final bool useMockLocation;
  final double? mockLatitude;
  final double? mockLongitude;

  StreamSubscription<Position>? _positionStream;
  DateTime? _lastUpdate;

  LocationServices._internal({
    this.useMockLocation = false,
    this.mockLatitude,
    this.mockLongitude,
  });

  factory LocationServices({
    bool useMockLocation = false,
    double? mockLatitude,
    double? mockLongitude,
  }) {
    _instance ??= LocationServices._internal(
      useMockLocation: useMockLocation,
      mockLatitude: mockLatitude,
      mockLongitude: mockLongitude,
    );
    return _instance!;
  }

  static void disposeInstance() {
    _instance?._dispose();
    _instance = null;
  }

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
    stopRealtimeTracking();

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

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          final now = DateTime.now();
          if (_lastUpdate != null &&
              now.difference(_lastUpdate!) < const Duration(minutes: 1)) {
            return;
          }
          _lastUpdate = now;
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
    if (_positionStream != null) {
      log.i('[Flutter] Stopping real-time tracking...');
      _positionStream?.cancel();
      _positionStream = null;
      _lastUpdate = null;
    } else {
      log.i('[Flutter] No active position stream to stop.');
    }
  }

  void _dispose() {
    stopRealtimeTracking();
    log.i('[Flutter] Location service disposed.');
  }
}
