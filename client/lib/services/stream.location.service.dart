import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioloca/environment.dart';
import 'package:http/http.dart' as http;
import 'package:audioloca/models/audio.model.dart';

final log = Logger();

class ApiEndpoints {
  static const String streamAudio = '/audioloca/audio/stream';
  static const String localAudioLocation = '/audioloca/audio/location';
  static const String spotifyAudioLocation = '/spotify/audio/location';
}

// =======================
// USER LOCATION
// =======================
Future<Position> getUserLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied.');
    }
  }
  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permissions are permanently denied.');
  }

  final locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
  );

  return await Geolocator.getCurrentPosition(
    locationSettings: locationSettings,
  );
}

class StreamLocationServices {
  final http.Client client;

  StreamLocationServices({http.Client? client})
    : client = client ?? http.Client();

  // =======================
  // POST user stream
  // =======================
  Future<bool> sendStream(
    String jwtToken, {
    int? audioId,
    String? spotifyId,
    required String type,
  }) async {
    final pos = await getUserLocation();

    log.e('[Flutter] latitude ${pos.latitude} longitude ${pos.longitude}');

    final url = Uri.parse(
      '${Environment.audiolocaBaseUrl}${ApiEndpoints.streamAudio}',
    );

    try {
      final body = {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'type': type,
      };

      if (type == "local" && audioId != null) {
        body['audio_id'] = audioId;
      } else if (type == "spotify" && spotifyId != null) {
        body['spotify_id'] = spotifyId;
      }

      final response = await client.post(
        url,
        headers: _headers(jwtToken),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        throw Exception(
          'Failed to send stream. Status: ${response.statusCode}. Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] error $e $stackTrace');
      rethrow;
    }
  }

  // =======================
  // GET local audio location
  // =======================
  Future<List<LocalAudioLocation>> fetchLocalAudioLocation() async {
    final pos = await getUserLocation();

    final url = Uri.parse(
      '${Environment.audiolocaBaseUrl}${ApiEndpoints.localAudioLocation}'
      '?latitude=${pos.latitude}&longitude=${pos.longitude}',
    );

    try {
      final response = await client.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((json) => LocalAudioLocation.fromJson(json)).toList();
        }
        throw FormatException('Unexpected audio list format.');
      } else {
        throw Exception(
          'Failed to fetch audio by location. Status: ${response.statusCode}. Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] error $e $stackTrace');
      rethrow;
    }
  }

  // =======================
  // GET spotify audio location
  // =======================
  Future<List<SpotifyAudioLocation>> fetchSpotifyAudioLocation() async {
    final pos = await getUserLocation();

    final url = Uri.parse(
      '${Environment.audiolocaBaseUrl}${ApiEndpoints.spotifyAudioLocation}'
      '?latitude=${pos.latitude}&longitude=${pos.longitude}',
    );

    try {
      final response = await client.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .map((json) => SpotifyAudioLocation.fromJson(json))
              .toList();
        }
        throw FormatException('Unexpected audio list format.');
      } else {
        throw Exception(
          'Failed to fetch audio by location. Status: ${response.statusCode}. Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] error $e $stackTrace');
      rethrow;
    }
  }

  // =======================
  // Helpers
  // =======================
  Map<String, String> _headers(String jwtToken) => {
    'Authorization': 'Bearer $jwtToken',
    'Content-Type': 'application/json',
  };
}
