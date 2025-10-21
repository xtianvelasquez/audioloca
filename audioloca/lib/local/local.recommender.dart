import 'dart:math';
import 'package:logger/logger.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/local/controllers/audio.service.dart';
import 'package:audioloca/local/models/audio.model.dart';

final log = Logger();
final storage = SecureStorageService();
final random = Random();
final audioServices = AudioServices();

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
      final audios = await audioServices.readAudioLocation(latitude, longitude);
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

    final normalizedMood = lastMood.trim().toLowerCase();
    List<int>? genreIds = moodToGenreIds[normalizedMood];

    if (genreIds == null || genreIds.isEmpty) {
      final fallbackMood = normalizedMood.split(' ').last;
      genreIds = moodToGenreIds[fallbackMood];
      if (genreIds == null || genreIds.isEmpty) {
        log.w('[Flutter] No mapped genres for mood "$lastMood".');
        return [];
      } else {
        log.w('[Flutter] Using fallback mood "$fallbackMood" for "$lastMood"');
      }
    }

    try {
      final tracks = await audioServices.readAudioByGenres(
        genreIds.toSet().toList(),
      );
      if (tracks.isEmpty) {
        log.w('[Flutter] No local tracks found for mood "$lastMood".');
        return [];
      }

      final seenAudioIds = <int>{};
      final uniqueTracks = <Audio>[];
      for (final track in tracks) {
        if (!seenAudioIds.contains(track.audioId)) {
          seenAudioIds.add(track.audioId);
          uniqueTracks.add(track);
        }
      }

      uniqueTracks.shuffle(random);
      cachedMood = lastMood;
      cachedTracks = uniqueTracks;

      log.i(
        '[Flutter] Returning ${uniqueTracks.length} local tracks for mood "$lastMood".',
      );
      return uniqueTracks;
    } catch (e, st) {
      log.e('[Flutter] Error fetching tracks for genres $genreIds: $e\n$st');
      return [];
    }
  }

  Future<List<Audio>> fetchGlobalRecommendationsFromLocal() async {
    final allTracks = <Audio>[];

    try {
      final audios = await audioServices.readGlobalAudios();
      allTracks.addAll(audios);
    } catch (e, st) {
      log.e('[Flutter] Error fetching location-based audio: $e $st');
    }

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
    'happily surprised': [1, 7, 12], // pop, latin/world, electronic
    'happily disgusted': [10, 3, 2], // experimental, rock, hip-hop/rap
    'sadly fearful': [8, 5, 4], // ambient/chill, classical, jazz/blues
    'sadly angry': [9, 3, 2], // metal, rock, hip-hop/rap
    'sadly surprised': [6, 4, 5], // folk/acoustic, jazz/blues, classical
    'sadly disgusted': [3, 10, 9], // rock, experimental, metal
    'fearfully angry': [9, 2, 10], // metal, hip-hop/rap, experimental
    'fearfully surprised': [8, 12, 5], // ambient/chill, electronic, classical
    'angrily surprised': [3, 9, 2], // rock, metal, hip-hop/rap
    'angrily disgusted': [9, 3, 10], // metal, rock, experimental
    'disgustedly surprised': [10, 12, 1], // experimental, electronic, pop
  };
}
