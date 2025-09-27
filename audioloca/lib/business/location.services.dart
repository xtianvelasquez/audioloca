import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:audioloca/environment.dart';

final log = Logger();

class LocationServices {
  StreamSubscription<Position>? positionStream;

  Future<bool> ensureLocationReady(BuildContext context) async {
    try {
      final position = await getUserPosition();
      log.i(
        '[Flutter] Position acquired: ${position.latitude}, ${position.longitude}',
      );
      return true;
    } catch (e) {
      log.w('[Flutter] Location error: $e');
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
      throw Exception('Please enable location services in settings.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw Exception(
        'Location permission permanently denied. Enable it in app settings.',
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

  Future<Position?> getLastKnownPosition() async {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      log.i(
        '[Flutter] Last known position: ${lastKnown.latitude}, ${lastKnown.longitude}',
      );
    }
    return lastKnown;
  }

  void startRealtimeTracking({
    required void Function(Position position) onLocationUpdate,
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 100,
  }) {
    final locationSettings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );

    positionStream =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
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

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['display_name'];
    } else {
      log.i('Error: ${response.body}');
      return null;
    }
  }

  void stopRealtimeTracking() {
    positionStream?.cancel();
    positionStream = null;
  }
}
