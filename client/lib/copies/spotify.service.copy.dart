import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/core/secure.storage.dart';

final log = Logger();
final storage = SecureStorageService();

class SpotifyService {
  static const String _spotifyApiBase = "https://api.spotify.com/v1";
  static const String _spotifyTokenUrl =
      "https://accounts.spotify.com/api/token";

  Future<String?> _getValidAccessToken() async {
    final accessToken = await storage.getAccessToken();
    final refreshToken = await storage.getRefreshToken();
    final expiryRaw = await storage.getExpiresAt();
    final expiry = expiryRaw != null
        ? DateTime.tryParse(expiryRaw)?.toUtc()
        : null;
    if (accessToken != null &&
        expiry != null &&
        DateTime.now().toUtc().isBefore(expiry)) {
      return accessToken;
    }

    if (refreshToken != null) {
      return await _refreshAccessToken(refreshToken);
    }

    log.w("[Flutter] Missing refresh token or access token expired.");
    return null;
  }

  /// Refresh Spotify access token
  Future<String?> _refreshAccessToken(String refreshToken) async {
    final credentials = base64Encode(
      utf8.encode(
        "${Environment.spotifyClientId}:${Environment.spotifyClientSecret}",
      ),
    );

    final response = await http.post(
      Uri.parse(_spotifyTokenUrl),
      headers: {
        "Authorization": "Basic $credentials",
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: {"grant_type": "refresh_token", "refresh_token": refreshToken},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newAccessToken = data["access_token"];
      final expiresIn = data["expires_in"];

      final expiry = DateTime.now().add(Duration(seconds: expiresIn));
      await storage.saveAccessToken(newAccessToken);
      await storage.saveExpiresAt(expiry.toIso8601String());

      return newAccessToken;
    } else {
      log.e("[Flutter] Token refresh failed: ${response.body}");
      return null;
    }
  }

  Future<List<dynamic>> fetchMoodRecommendations() async {
    final lastMood = await storage.getLastMood();
    final accessToken = await _getValidAccessToken();

    if (lastMood == null || accessToken == null) {
      log.i("[SpotifyService] Missing mood or access token.");
      return [];
    }

    final moodToGenre = {
      'sad': 'dance',
      'fear': 'ambient',
      'disgust': 'classical',
      'surprise': 'funk',
      'neutral': 'indie',
      'happy': 'electronic',
    };

    final genre = moodToGenre[lastMood.toLowerCase()] ?? 'pop';

    final url = Uri.parse(
      "$_spotifyApiBase/recommendations?seed_genres=$genre&limit=100",
    );

    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $accessToken"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["tracks"] ?? [];
    } else {
      log.e("[Flutter] Failed to fetch recommendations: ${response.body}");
      return [];
    }
  }
}
