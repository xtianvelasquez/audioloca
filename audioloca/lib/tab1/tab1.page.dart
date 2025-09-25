import 'dart:async';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/business/emotion.recognition.dart';
import 'package:audioloca/business/location.services.dart';
import 'package:audioloca/player/views/mini.player.dart';
import 'package:audioloca/local/local.recommender.dart';
import 'package:audioloca/spotify/spotify.recommender.dart';
import 'package:audioloca/tab1/tab1.widgets/emotion/local.recommender.dart';
import 'package:audioloca/tab1/tab1.widgets/location/local.recommender.dart';
import 'package:audioloca/tab1/tab1.widgets/emotion/spotify.recommender.dart';
import 'package:audioloca/local/models/audio.model.dart';
import 'package:audioloca/spotify/controllers/track.service.dart';
import 'package:audioloca/spotify/models/track.model.dart';

final log = Logger();
final storage = SecureStorageService();
final emotionRecognition = EmotionRecognition();
final localRecommender = LocalRecommender();
final spotifyRecommender = SpotifyRecommender();
final locationServices = LocationServices();
final trackServices = TrackServices();

class Tab1 extends StatefulWidget {
  const Tab1({super.key});
  @override
  State<Tab1> createState() => Tab1State();
}

class Tab1State extends State<Tab1> with SingleTickerProviderStateMixin {
  String? detectedMood;

  List<SpotifyTrack> spotifyTracks = [];
  List<Audio> localTracks = [];
  List<LocalAudioLocation> localAudioLocationTracks = [];
  List<SpotifyTrack> spotifyAudioLocationTracks = [];

  bool isLoading = true;
  late TabController tabController;

  StreamSubscription<Position>? locationStream;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);
    initTracks();
  }

  Future<void> initTracks({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
      spotifyTracks = [];
      localTracks = [];
      spotifyAudioLocationTracks = [];
      localAudioLocationTracks = [];
    });

    locationServices.stopRealtimeTracking();

    final locationReady = await locationServices.ensureLocationReady(context);
    if (!locationReady) {
      log.w(
        '[Flutter] Location not ready. Skipping location-based recommendations.',
      );
      setState(() => isLoading = false);
      return;
    }

    final accessToken = await spotifyRecommender.getValidAccessToken();

    try {
      final local = await localRecommender.fetchMoodRecommendationsFromLocal();

      locationServices.startRealtimeTracking(
        distanceFilter: 100,
        onLocationUpdate: (position) async {
          final roundedLat = double.parse(position.latitude.toStringAsFixed(3));
          final roundedLng = double.parse(
            position.longitude.toStringAsFixed(3),
          );

          final localRecommendations = await localRecommender
              .fetchLocationRecommendationFromLocal(
                latitude: roundedLat,
                longitude: roundedLng,
              );

          List<SpotifyTrack> spotifyLocationRecommendations = [];

          if (accessToken != null) {
            spotifyLocationRecommendations = await spotifyRecommender
                .fetchLocationRecommendationsFromSpotify(
                  latitude: roundedLat,
                  longitude: roundedLng,
                );
          }

          if (mounted) {
            setState(() {
              localAudioLocationTracks = localRecommendations;
              spotifyAudioLocationTracks = spotifyLocationRecommendations;
            });
          }
        },
      );

      List<SpotifyTrack> spotify = [];
      if (accessToken != null) {
        final rawSpotify = await spotifyRecommender
            .fetchMoodRecommendationsFromSpotify(forceRefresh: forceRefresh);

        spotify = rawSpotify
            .map((json) => SpotifyTrack.fromJson(json))
            .toList();
      } else {
        log.i("[Flutter] No Spotify access token. Local only.");
      }

      if (mounted) {
        setState(() {
          localTracks = local;
          spotifyTracks = spotify;
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      log.e("Failed to fetch recommendations: $e $stackTrace");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    locationServices.stopRealtimeTracking();
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AudioLoca',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: "Spotify"),
            Tab(text: "Local"),
            Tab(text: "Spotify Location"),
            Tab(text: "Local Location"),
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
                final result = await emotionRecognition
                    .requestCameraPermission();

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
                    await initTracks(forceRefresh: true);
                  }
                } else {
                  log.i('[Flutter] Error: ${result.errorMessage}');
                  if (context.mounted) {
                    CustomAlertDialog.failed(context, result.errorMessage!);
                  }
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
                            : EmotionSpotifyListView(allTracks: spotifyTracks),

                        // Tab 2: Local
                        localTracks.isEmpty
                            ? const Center(child: Text("No local tracks"))
                            : EmotionLocalListView(allTracks: localTracks),

                        // Tab 2: Local
                        spotifyAudioLocationTracks.isEmpty
                            ? const Center(
                                child: Text("No spotify location tracks"),
                              )
                            : EmotionSpotifyListView(
                                allTracks: spotifyAudioLocationTracks,
                              ),

                        // Tab 4: Local location
                        localAudioLocationTracks.isEmpty
                            ? const Center(
                                child: Text("No local location tracks"),
                              )
                            : LocationLocalListView(
                                allTracks: localAudioLocationTracks,
                              ),
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
