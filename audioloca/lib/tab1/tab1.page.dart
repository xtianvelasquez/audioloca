import 'dart:async';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

import 'package:audioloca/theme.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/business/emotion.recognition.dart';
import 'package:audioloca/business/location.services.dart';
import 'package:audioloca/local/local.recommender.dart';
import 'package:audioloca/local/models/audio.model.dart';
import 'package:audioloca/spotify/spotify.recommender.dart';
import 'package:audioloca/tab1/tab1.widgets/local.recommender.dart';
import 'package:audioloca/tab1/tab1.widgets/spotify.recommender.dart';
import 'package:audioloca/spotify/controllers/track.service.dart';
import 'package:audioloca/spotify/models/track.model.dart';
import 'package:audioloca/player/views/mini.player.dart';

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

class Tab1State extends State<Tab1> {
  String? detectedMood;
  String? detectedLocation;
  String? accessToken;

  List<Audio> localTracks = [];
  List<Audio> localAudioLocationTracks = [];

  List<SpotifyTrack> spotifyTracks = [];
  List<SpotifyTrack> spotifyAudioLocationTracks = [];

  bool isLoading = true;
  bool isLoadingMood = false;
  StreamSubscription<Position>? locationStream;

  @override
  void initState() {
    super.initState();
    loadLastMood();
    initTracks();
  }

  Future<void> loadLastMood() async {
    try {
      final lastMood = await storage.getLastMood();
      if (mounted) setState(() => detectedMood = lastMood);
    } catch (e) {
      log.e("[Flutter] Failed to load last mood: $e");
    }
  }

  Future<void> initTracks() async {
    setState(() => isLoading = true);

    locationServices.stopRealtimeTracking();

    final locationReady = await locationServices.ensureLocationReady(context);
    if (!locationReady) {
      log.w('[Flutter] Location not ready.');
      setState(() => isLoading = false);
      return;
    }

    accessToken = await spotifyRecommender.getValidAccessToken();

    await loadMoodRecommendations();
    await loadLocationRecommendations();

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> loadMoodRecommendations({bool forceRefresh = false}) async {
    setState(() => isLoadingMood = true);
    try {
      final local = await localRecommender.fetchMoodRecommendationsFromLocal();

      List<SpotifyTrack> spotify = [];
      if (accessToken != null) {
        final rawSpotify = await spotifyRecommender
            .fetchMoodRecommendationsFromSpotify(forceRefresh: forceRefresh);
        spotify = rawSpotify
            .map((json) => SpotifyTrack.fromJson(json))
            .toList();
      }

      if (mounted) {
        setState(() {
          localTracks = local;
          spotifyTracks = spotify;
        });
      }
    } catch (e, st) {
      log.e("Failed to fetch mood recos: $e $st");
    } finally {
      if (mounted) setState(() => isLoadingMood = false);
    }
  }

  Future<void> loadLocationRecommendations() async {
    locationServices.startRealtimeTracking(
      distanceFilter: 100,
      onLocationUpdate: (position) async {
        final roundedLat = double.parse(position.latitude.toStringAsFixed(3));
        final roundedLng = double.parse(position.longitude.toStringAsFixed(3));

        final localRecommendations = await localRecommender
            .fetchLocationRecommendationFromLocal(
              latitude: roundedLat,
              longitude: roundedLng,
            );

        final locationAddress = await locationServices.getLocationIQAddress(
          roundedLat,
          roundedLng,
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
            detectedLocation = locationAddress;
            localAudioLocationTracks = localRecommendations;
            spotifyAudioLocationTracks = spotifyLocationRecommendations;
          });
        }
      },
    );
  }

  Future<void> scanMood() async {
    final result = await emotionRecognition.requestCameraPermission();

    if (result.isSuccess) {
      log.i('[Flutter] Label: ${result.emotionLabel}');
      log.i(
        '[Flutter] Confidence: ${result.confidenceScore?.toStringAsFixed(4)}',
      );

      if (result.emotionLabel != null) {
        await storage.saveLastMood(result.emotionLabel!);
        setState(() => detectedMood = result.emotionLabel!);
        await loadMoodRecommendations(
          forceRefresh: true,
        ); // ✅ refresh only mood recos
      }
    } else {
      log.i('[Flutter] Error: ${result.errorMessage}');
      if (!mounted) return;
      CustomAlertDialog.failed(context, result.errorMessage!);
    }
  }

  @override
  void dispose() {
    locationServices.stopRealtimeTracking();
    locationStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("AudioLoca"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ElevatedButton(
                  onPressed: scanMood,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.color1,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("SCAN MY MOOD"),
                ),
                const SizedBox(height: 10),

                const Text("Local Recommendations", style: sectionStyle),

                Text(
                  "Detected Mood: ${detectedMood ?? 'No mood detected yet'}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),

                const SizedBox(height: 10),

                if (isLoadingMood)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  localTracks.isEmpty
                      ? const Text("No local tracks")
                      : LocalListView(allTracks: localTracks),

                  if (accessToken != null) ...[
                    const SizedBox(height: 20),
                    const Text("Spotify Recommendations", style: sectionStyle),
                    spotifyTracks.isEmpty
                        ? const Text("No Spotify tracks")
                        : SpotifyListView(allTracks: spotifyTracks),
                  ],
                ],

                const SizedBox(height: 20),
                const Text("Local Location-Based Tracks", style: sectionStyle),

                if (detectedLocation != null)
                  Text(
                    "Detected Location: $detectedLocation",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),

                localAudioLocationTracks.isEmpty
                    ? const Text("No local location tracks")
                    : LocalListView(allTracks: localAudioLocationTracks),

                if (accessToken != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    "Spotify Location-Based Tracks",
                    style: sectionStyle,
                  ),
                  spotifyAudioLocationTracks.isEmpty
                      ? const Text("No Spotify location tracks")
                      : SpotifyListView(allTracks: spotifyAudioLocationTracks),
                ],
              ],
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

const sectionStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
