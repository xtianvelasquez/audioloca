import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:audioloca/models/audio.model.dart';

final log = Logger();

class SpotifyServices {
  final http.Client client;

  SpotifyServices({http.Client? client}) : client = client ?? http.Client();

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
      } else {
        throw Exception(
          'Spotify API failed: ${response.statusCode}, body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] Spotify API error: $e $stackTrace');
      rethrow;
    }
  }
}
