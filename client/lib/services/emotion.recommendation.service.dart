import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/services/genres.service.dart';
import 'package:audioloca/services/audio.service.dart';
import 'package:audioloca/models/genres.model.dart';
import 'package:audioloca/models/audio.model.dart';

final log = Logger();
final storage = SecureStorageService();
final random = Random();

class EmotionRecommendationService {
  String? cachedMood;
  List<dynamic> cachedTracks = [];

  /// ---- TOKEN HANDLING ----
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

  /// ---- GET GENRES ----
  Future<List<Genres>> fetchAllGenres() async {
    try {
      final genres = await GenreServices().readGenres();
      return genres;
    } catch (e, stackTrace) {
      log.e('Failed to fetch genres: $e $stackTrace');
      return [];
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

  /// ---- LOCAL FALLBACK ----
  Future<List<Audio>> fetchMoodRecommendationsFromLocal() async {
    final jwtToken = await storage.getJwtToken();
    final lastMood = await storage.getLastMood();

    if (jwtToken == null || lastMood == null) {
      log.e('[Flutter] Missing JWT token or mood for local fetch.');
      return [];
    }

    final genreIds = moodToGenreIds[lastMood.toLowerCase()];
    if (genreIds == null || genreIds.isEmpty) {
      log.w('[Flutter] No mapped genres for mood "$lastMood"');
      return [];
    }

    final allTracks = <Audio>[];

    for (final genreId in genreIds) {
      try {
        final tracks = await AudioServices().readAudioGenre(jwtToken, genreId);
        allTracks.addAll(tracks);
      } catch (e, st) {
        log.e('[Flutter] Error fetching genre $genreId: $e $st');
      }
    }

    if (allTracks.isEmpty) {
      log.w('[Flutter] No local tracks found for mood "$lastMood".');
      return [];
    }

    allTracks.shuffle(random);

    cachedMood = lastMood;
    cachedTracks = allTracks;

    log.i(
      '[Flutter] Returning ${allTracks.length} local tracks for mood "$lastMood".',
    );

    return allTracks;
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

  static const Map<String, List<int>> moodToGenreIds = {
    'happiness': [1, 3, 12], // pop, rock, electronic
    'sadness': [4, 6, 5], // jazz/blues, folk/acoustic, classical
    'anger': [9, 2, 3], // metal, hip-hop/rap, rock
    'fear': [8, 10, 5], // ambient/chill, experimental, classical
    'disgust': [10, 9, 3], // experimental, metal, rock
    'surprise': [1, 12, 7], // pop, electronic, latin/world
    'neutral': [8, 6, 11], // ambient/chill, folk/acoustic, country
    'happily surprised': [1, 7, 12],
    'happily disgusted': [10, 3, 2],
    'sadly fearful': [8, 5, 4],
    'sadly angry': [9, 3, 2],
    'sadly surprised': [6, 4, 5],
    'sadly disgusted': [3, 10, 9],
    'fearfully angry': [9, 2, 10],
    'fearfully surprised': [8, 12, 5],
    'angrily surprised': [3, 9, 2],
    'angrily disgusted': [9, 3, 10],
    'disgustedly surprised': [10, 12, 1],
  };
}
