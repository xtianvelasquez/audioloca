import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/core/emotion.recognition.dart';
import 'package:audioloca/services/emotion.recommendation.service.dart';
import 'package:audioloca/tab1/tab1.widgets/spotify.recommender.dart';
import 'package:audioloca/tab1/tab1.widgets/local.recommender.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/models/audio.model.dart';
import 'package:audioloca/global/mini.player.dart';

final log = Logger();
final storage = SecureStorageService();
final emotion = EmotionService();

class Tab1 extends StatefulWidget {
  const Tab1({super.key});
  @override
  State<Tab1> createState() => Tab1State();
}

class Tab1State extends State<Tab1> with SingleTickerProviderStateMixin {
  String? detectedMood;

  List<SpotifyTrack> spotifyTracks = [];
  List<Audio> localTracks = [];

  bool isLoading = true;
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    _initTracks();
  }

  Future<void> _initTracks({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
      spotifyTracks = [];
      localTracks = [];
    });

    final service = EmotionRecommendationService();
    final accessToken = await service.getValidAccessToken();

    try {
      // Always load local
      final local = await service.fetchMoodRecommendationsFromLocal();

      // Conditionally load Spotify
      List<SpotifyTrack> spotify = [];
      if (accessToken != null) {
        final rawSpotify = await service.fetchMoodRecommendationsFromSpotify(
          forceRefresh: forceRefresh,
        );

        spotify = rawSpotify
            .map((json) => SpotifyTrack.fromJson(json))
            .toList();
      } else {
        log.i("[Flutter] No Spotify access token → local only.");
      }

      setState(() {
        localTracks = local;
        spotifyTracks = spotify;
        isLoading = false;
      });
    } catch (e) {
      log.e("Failed to fetch recommendations: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tab 1'),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: "Spotify"),
            Tab(text: "Local"),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final result = await emotionService.requestCameraPermission();

                if (result.isSuccess) {
                  log.i('[Flutter] Label: ${result.emotionLabel}');
                  log.i(
                    '[Flutter] Confidence: ${result.confidenceScore?.toStringAsFixed(4)}',
                  );

                  if (result.emotionLabel != null) {
                    await storage.saveLastMood(result.emotionLabel!);
                    setState(() {
                      detectedMood = result.emotionLabel!;
                    });
                    await _initTracks(forceRefresh: true);
                  }
                } else {
                  log.i('[Flutter] Error: ${result.errorMessage}');
                }
              },
              child: const Text('SCAN MY MOOD'),
            ),
            const SizedBox(height: 20),
            if (detectedMood != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Detected Mood: ${detectedMood!.toUpperCase()}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: tabController,
                      children: [
                        // Tab 1: Spotify
                        spotifyTracks.isEmpty
                            ? const Center(child: Text("No Spotify tracks"))
                            : SpotifyListView(allTracks: spotifyTracks),

                        // Tab 2: Local
                        localTracks.isEmpty
                            ? const Center(child: Text("No local tracks"))
                            : LocalListView(allTracks: localTracks),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
