import 'dart:convert';
import 'dart:math';
import 'package:audioloca/spotify/models/track.model.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/spotify/controllers/track.service.dart';

final log = Logger();
final storage = SecureStorageService();
final random = Random();
final trackServices = TrackServices();

class SpotifyRecommender {
  String? cachedMood;
  List<dynamic> cachedTracks = [];

  /// ---- TOKEN HANDLING ----
  Future<List<SpotifyTrack>> fetchLocationRecommendationsFromSpotify({
    required double latitude,
    required double longitude,
  }) async {
    final jwtToken = await storage.getJwtToken();
    final accessToken = await storage.getAccessToken();
    final lastMood = await storage.getLastMood();

    if (jwtToken == null || lastMood == null) {
      log.e('[Flutter] Missing JWT token or mood for Spotify fetch.');
      return [];
    }

    final locationResults = await trackServices.fetchSpotifyAudioLocation(
      latitude,
      longitude,
    );

    final spotifyIds = locationResults
        .map((location) => location.id)
        .whereType<String>()
        .toList();

    if (spotifyIds.isEmpty) {
      log.i('[Flutter] No Spotify IDs found for location.');
      return [];
    }

    try {
      final tracks = await trackServices.fetchSpotifyTracksMetadata(
        accessToken!,
        spotifyIds,
      );
      return tracks;
    } catch (e, st) {
      log.e('[Flutter] Failed to fetch Spotify metadata: $e\n$st');
      return [];
    }
  }

  Future<String?> getValidAccessToken() async {
    final accessToken = await storage.getAccessToken();
    final refreshToken = await storage.getRefreshToken();
    final expiryRaw = await storage.getExpiresAt();

    DateTime? expiry;
    if (expiryRaw != null) {
      expiry = DateTime.tryParse(expiryRaw)?.toUtc();
      if (expiry == null) {
        log.w('[Flutter] Failed to parse expiry: $expiryRaw');
      }
    }

    if (accessToken != null &&
        expiry != null &&
        DateTime.now().toUtc().isBefore(expiry)) {
      return accessToken;
    }

    if (refreshToken != null) {
      return await refreshAccessToken(refreshToken);
    }

    log.w('[Flutter] Missing refresh token or access token expired.');
    return null;
  }

  Future<String?> refreshAccessToken(String refreshToken) async {
    final credentials = base64Encode(
      utf8.encode(
        '${Environment.spotifyClientId}:${Environment.spotifyClientSecret}',
      ),
    );

    final response = await http.post(
      Uri.parse(Environment.spotifyTokenUrl),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newAccessToken = data['access_token'];
      final expiresIn = data['expires_in'];

      if (newAccessToken == null || expiresIn == null) {
        log.e('[Flutter] Invalid token refresh response: $data');
        return null;
      }

      final expiry = DateTime.now().add(Duration(seconds: expiresIn));
      await storage.saveAccessToken(newAccessToken);
      await storage.saveExpiresAt(expiry.toIso8601String());

      return newAccessToken;
    } else {
      log.e('[Flutter] Token refresh failed: ${response.body}');
      return null;
    }
  }

  /// ---- SPOTIFY FETCH ----
  Future<List<Map<String, dynamic>>> fetchMoodRecommendationsFromSpotify({
    bool forceRefresh = false,
  }) async {
    final lastMood = await storage.getLastMood();
    final accessToken = await getValidAccessToken();

    if (lastMood == null || accessToken == null) {
      log.i('[Flutter] No mood detected or no valid access token.');
      return [];
    }

    if (!forceRefresh && cachedMood == lastMood && cachedTracks.isNotEmpty) {
      log.i('[Flutter] Returning cached Spotify tracks for mood "$lastMood"');
      return List<Map<String, dynamic>>.from(cachedTracks);
    }

    final queries = moodToQueries[lastMood.toLowerCase()] ?? ['feel good'];
    final query = queries[random.nextInt(queries.length)];

    final offset = random.nextInt(5) * 50;
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse(
      '${Environment.spotifyApiBase}/search?q=$encodedQuery&type=track&limit=50&offset=$offset',
    );

    log.i('[Flutter] Searching tracks for mood "$lastMood" → query "$query"');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data['tracks']?['items'];

      if (items == null) {
        log.w('[Flutter] Spotify returned no tracks for query "$query"');
        return [];
      }

      final tracks = List<Map<String, dynamic>>.from(items);
      tracks.shuffle(random);

      cachedMood = lastMood;
      cachedTracks = tracks;

      log.i('[Flutter] Returning ${tracks.length} Spotify tracks.');
      return tracks;
    } else {
      log.e('[Flutter] Spotify search failed → ${response.body}');
      return [];
    }
  }

  Future<List<SpotifyTrack>> fetchGlobalRecommendationsFromSpotify() async {
    final accessToken = await getValidAccessToken();
    if (accessToken == null) {
      throw 'Access token is null. Cannot fetch recommendations.';
    }
    return await trackServices.fetchGlobalRecommendation(accessToken);
  }

  /// ---- STATIC MAPPINGS ----
  static const Map<String, List<String>> moodToQueries = {
    'happiness': ['energetic', 'upbeat', 'party', 'dance'],
    'anger': ['energetic', 'upbeat', 'party', 'dance'],
    'sadness': ['uplifting', 'healing', 'comfort', 'emotional'],
    'fear': ['calm', 'ambient', 'soothing'],
    'disgust': ['serene', 'relaxing', 'peaceful'],
    'surprise': ['exciting', 'unexpected', 'novelty'],
    'neutral': ['chill', 'lofi', 'mellow'],
    'happily surprised': ['joyful', 'celebratory', 'fun'],
    'happily disgusted': ['ironic', 'quirky', 'indie'],
    'sadly fearful': ['melancholic', 'dark ambient', 'introspective'],
    'sadly angry': ['emotional rock', 'post-punk', 'emo'],
    'sadly surprised': ['nostalgic', 'bittersweet', 'soul'],
    'sadly disgusted': ['haunting', 'grunge', 'alt rock'],
    'fearfully angry': ['intense', 'metal', 'dark rap'],
    'fearfully surprised': ['mystical', 'cinematic', 'epic'],
    'angrily surprised': ['aggressive', 'punk', 'rap'],
    'angrily disgusted': ['hard rock', 'industrial', 'edgy'],
    'disgustedly surprised': ['experimental', 'weird pop', 'avant-garde'],
  };
}
