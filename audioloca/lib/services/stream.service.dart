import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:audioloca/environment.dart';

final log = Logger();

class ApiEndpoints {
  static const String streamAudio = '/audioloca/audio/stream';
}

class StreamServices {
  final http.Client client;

  StreamServices({http.Client? client}) : client = client ?? http.Client();

  // =======================
  // POST user stream
  // =======================
  Future<bool> sendStream(
    String jwtToken, {
    required Position position,
    int? audioId,
    String? spotifyId,
    required String type,
  }) async {
    final url = Uri.parse(
      '${Environment.audiolocaBaseUrl}${ApiEndpoints.streamAudio}',
    );

    final body = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'type': type,
    };

    if (type == 'local' && audioId != null) {
      body['audio_id'] = audioId;
    } else if (type == 'spotify' && spotifyId != null) {
      body['spotify_id'] = spotifyId;
    }

    log.i('[Flutter] Sending stream with body: $body');

    try {
      final response = await client.post(
        url,
        headers: _headers(jwtToken),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        log.i('[Flutter] Stream sent successfully.');
        return true;
      } else {
        log.w(
          '[Flutter] Failed to send stream. Status: ${response.statusCode}. Body: ${response.body}',
        );
        return false;
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] Error sending stream: $e $stackTrace');
      return false;
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
