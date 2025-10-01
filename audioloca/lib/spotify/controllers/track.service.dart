import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:audioloca/environment.dart';
import 'package:audioloca/spotify/models/track.model.dart';

final log = Logger();

class ApiEndpoints {
  static const String locationAudio = '/spotify/audio/location';
}

class TrackServices {
  final http.Client client;

  TrackServices({http.Client? client}) : client = client ?? http.Client();

  Future<List<SpotifyTrack>> fetchSpotifyTracksMetadata(
    String accessToken,
    List<String> spotifyIds,
  ) async {
    final url = Uri.https('api.spotify.com', '/v1/tracks', {
      'ids': spotifyIds.join(','),
    });

    try {
      final response = await client.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['tracks'] is List) {
          return (data['tracks'] as List)
              .map((json) => SpotifyTrack.fromJson(json))
              .toList();
        } else {
          throw const FormatException('Unexpected Spotify API format');
        }
      }

      String message = 'Request failed with status: ${response.statusCode}.';

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('detail')) {
          message = decoded['detail'];
        } else if (decoded is Map && decoded.containsKey('message')) {
          message = decoded['message'];
        }
      } catch (_) {
        message = response.body.toString();
      }

      throw Exception(message);
    } catch (e, stackTrace) {
      log.e('[Flutter] Spotify API error: $e $stackTrace');
      rethrow;
    }
  }

  Future<List<SpotifyTrack>> searchSpotifyTracks(
    String accessToken,
    String query,
  ) async {
    final url = Uri.https('api.spotify.com', '/v1/search', {
      'q': query,
      'type': 'track',
      'limit': '10',
    });

    try {
      final response = await client.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['tracks']?['items'];
        if (items is List) {
          return items.map((json) => SpotifyTrack.fromJson(json)).toList();
        } else {
          throw const FormatException('Unexpected Spotify API format');
        }
      }

      String message = 'Request failed with status: ${response.statusCode}.';

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('detail')) {
          message = decoded['detail'];
        } else if (decoded is Map && decoded.containsKey('message')) {
          message = decoded['message'];
        }
      } catch (_) {
        message = response.body.toString();
      }

      throw Exception(message);
    } catch (e, stackTrace) {
      log.e('[Flutter] Spotify search error: $e $stackTrace');
      rethrow;
    }
  }

  Future<List<SpotifyTrack>> fetchSpotifyAudioLocation(
    double latitude,
    double longitude,
  ) async {
    return _post<List<SpotifyTrack>>(
      ApiEndpoints.locationAudio,
      headers: {'Content-Type': 'application/json'},
      body: {'latitude': latitude, 'longitude': longitude},
      parser: (data) {
        if (data is List) {
          return data.map((json) => SpotifyTrack.fromJson(json)).toList();
        }
        throw FormatException('Unexpected audio location format.');
      },
    );
  }

  Future<T> _post<T>(
    String endpoint, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required T Function(dynamic) parser,
  }) async {
    final url = Uri.parse('${Environment.audiolocaBaseUrl}$endpoint');
    try {
      final response = await client.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return parser(jsonDecode(response.body));
      }

      String message = 'Request failed with status: ${response.statusCode}.';

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('detail')) {
          message = decoded['detail'];
        } else if (decoded is Map && decoded.containsKey('message')) {
          message = decoded['message'];
        }
      } catch (_) {
        message = response.body.toString();
      }

      throw Exception(message);
    } catch (e, stackTrace) {
      log.e('[Flutter] POST $endpoint error $e $stackTrace');
      rethrow;
    }
  }
}
