import 'dart:async';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

import 'package:audioloca/theme.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/alert.dialog.dart';
import 'package:audioloca/business/emotion.recognition.dart';
import 'package:audioloca/business/location.services.dart';
import 'package:audioloca/local/local.recommender.dart';
import 'package:audioloca/local/models/audio.model.dart';
import 'package:audioloca/spotify/spotify.recommender.dart';
import 'package:audioloca/spotify/models/track.model.dart';
import 'package:audioloca/tab1/tab1.widgets/local.recommender.dart';
import 'package:audioloca/tab1/tab1.widgets/spotify.recommender.dart';
import 'package:audioloca/spotify/controllers/track.service.dart';
import 'package:audioloca/player/views/mini.player.dart';

final log = Logger();
final storage = SecureStorageService();
final emotionRecognition = EmotionRecognition();
final locationServices = LocationServices(
  useMockLocation: true,
  mockLatitude: 14.591835,
  mockLongitude: 120.9733458,
);
final localRecommender = LocalRecommender();
final spotifyRecommender = SpotifyRecommender();
final trackServices = TrackServices();

class Tab1 extends StatefulWidget {
  const Tab1({super.key});
  @override
  State<Tab1> createState() => Tab1State();
}

class Tab1State extends State<Tab1> with TickerProviderStateMixin {
  String? detectedMood;
  String? detectedLocation;
  String? accessToken;
  LatLng? currentLatLng;

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
    } catch (e, stackTrace) {
      log.e("[Flutter] Failed to load last mood: $e $stackTrace");
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
    } catch (e, stackTrace) {
      log.e("Failed to fetch mood recos: $e $stackTrace");
    } finally {
      if (mounted) setState(() => isLoadingMood = false);
    }
  }

  Future<void> loadLocationRecommendations() async {
    locationServices.startRealtimeTracking(
      distanceFilter: 100,
      onLocationUpdate: (position) async {
        final roundedLat = double.parse(position.latitude.toStringAsFixed(6));
        final roundedLng = double.parse(position.longitude.toStringAsFixed(6));

        final localRecommendations = await localRecommender
            .fetchLocationRecommendationFromLocal(
              latitude: position.latitude,
              longitude: position.longitude,
            );

        final locationAddress = await locationServices.getLocationIQAddress(
          roundedLat,
          roundedLng,
        );

        List<SpotifyTrack> spotifyLocationRecommendations = [];
        if (accessToken != null) {
          spotifyLocationRecommendations = await spotifyRecommender
              .fetchLocationRecommendationsFromSpotify(
                latitude: position.latitude,
                longitude: position.longitude,
              );
        }

        if (mounted) {
          setState(() {
            detectedLocation = locationAddress;
            localAudioLocationTracks = localRecommendations;
            spotifyAudioLocationTracks = spotifyLocationRecommendations;
            currentLatLng = LatLng(roundedLat, roundedLng); // ✅ Store here
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
        await loadMoodRecommendations(forceRefresh: true);
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
    return DefaultTabController(
      length: 3, // three sub-tabs
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text("AudioLoca"),
          backgroundColor: AppColors.color1,
          foregroundColor: AppColors.light,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Empty"),
              Tab(text: "Emotion"),
              Tab(text: "Location"),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // 1 Empty Tab
                  const Center(child: Text("This tab is empty for now.")),

                  // 2️ Emotion Recognition + Mood Recos
                  ListView(
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.mood, color: Colors.deepPurple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Detected Mood: ${detectedMood ?? 'No mood detected yet'}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Mood-Based Recommendations",
                        style: sectionStyle,
                      ),
                      const SizedBox(height: 12),

                      if (isLoadingMood)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        localTracks.isEmpty
                            ? const Text("No local tracks available.")
                            : LocalListView(allTracks: localTracks),

                        if (accessToken != null) ...[
                          const SizedBox(height: 16),
                          const Text(
                            "Spotify Recommendations",
                            style: sectionStyle,
                          ),
                          spotifyTracks.isEmpty
                              ? const Text("No Spotify tracks available.")
                              : SpotifyListView(allTracks: spotifyTracks),
                        ],
                      ],
                    ],
                  ),

                  // 3️ Location + Map + Location Recommendations
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 🔹 Placeholder for Map
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter:
                                  currentLatLng ??
                                  const LatLng(14.5995, 120.9842),
                              initialZoom: 15,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.example.audioloca', // replace with your real package name
                              ),
                              if (currentLatLng != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: currentLatLng!,
                                      width: 50,
                                      height: 50,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Colors.red,
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "$detectedLocation ?? Unknown",
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.color1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Location-Based Recommendations",
                        style: sectionStyle,
                      ),
                      const SizedBox(height: 12),

                      localAudioLocationTracks.isEmpty
                          ? const Text("No local location tracks available.")
                          : LocalListView(allTracks: localAudioLocationTracks),

                      if (accessToken != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "Spotify Location-Based Tracks",
                          style: sectionStyle,
                        ),
                        spotifyAudioLocationTracks.isEmpty
                            ? const Text(
                                "No Spotify location tracks available.",
                              )
                            : SpotifyListView(
                                allTracks: spotifyAudioLocationTracks,
                              ),
                      ],
                    ],
                  ),
                ],
              ),
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }
}

const sectionStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
