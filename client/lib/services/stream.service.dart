import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:audioloca/environment.dart';
import 'package:audioloca/business/location.services.dart';

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
    BuildContext context,
    String jwtToken, {
    int? audioId,
    String? spotifyId,
    required String type,
  }) async {
    final locationService = LocationServices();

    // Ensure location is ready
    final locationReady = await locationService.ensureLocationReady(context);
    if (!locationReady) return false;

    // Get current position
    Position pos;
    try {
      pos = await locationService.getUserPosition();
    } catch (e, stackTrace) {
      log.e('[Flutter] Failed to get position: $e $stackTrace');
      return false;
    }

    log.i('[Flutter] latitude ${pos.latitude} longitude ${pos.longitude}');

    final url = Uri.parse(
      '${Environment.audiolocaBaseUrl}${ApiEndpoints.streamAudio}',
    );

    final body = {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'type': type,
    };

    if (type == 'local' && audioId != null) {
      body['audio_id'] = audioId;
    } else if (type == 'spotify' && spotifyId != null) {
      body['spotify_id'] = spotifyId;
    }

    log.i('[Flutter] body $body');

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
