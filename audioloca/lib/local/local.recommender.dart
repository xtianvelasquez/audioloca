import 'dart:math';
import 'package:logger/logger.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/local/controllers/audio.service.dart';
import 'package:audioloca/local/models/audio.model.dart';

final log = Logger();
final storage = SecureStorageService();
final random = Random();

class LocalRecommender {
  String? cachedMood;
  List<dynamic> cachedTracks = [];

  /// ---- LOCAL FALLBACK ----
  Future<List<Audio>> fetchLocationRecommendationFromLocal({
    required double latitude,
    required double longitude,
  }) async {
    final allTracks = <Audio>[];

    try {
      final audios = await AudioServices().readAudioLocation(
        latitude,
        longitude,
      );
      allTracks.addAll(audios);
    } catch (e, st) {
      log.e('[Flutter] Error fetching location-based audio: $e $st');
    }

    return allTracks;
  }

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
        final tracks = await AudioServices().readAudioGenre(genreId);
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
