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
import 'package:audioloca/spotify/services/track.service.dart';
import 'package:audioloca/player/views/mini.player.dart';
import 'package:audioloca/tabs/tabs.routing.dart';

final log = Logger();
final storage = SecureStorageService();
final emotionRecognition = EmotionRecognition();
final locationServices = LocationServices();
final localRecommender = LocalRecommender();
final spotifyRecommender = SpotifyRecommender();
final trackServices = TrackServices();

class Tab1 extends StatefulWidget {
  const Tab1({super.key});
  @override
  State<Tab1> createState() => Tab1State();
}

class Tab1State extends State<Tab1> with TickerProviderStateMixin {
  late TabController _tabController;
  int _activeSubTab = 0;

  String? detectedMood;
  String? detectedEmotionConfidence;
  String? detectedLocation;
  String? accessToken;
  LatLng? currentLatLng;

  List<Audio> globalLocalTracks = [];
  List<SpotifyTrack> globalSpotifyTracks = [];

  List<Audio> localTracks = [];
  List<Audio> localAudioLocationTracks = [];

  List<SpotifyTrack> spotifyTracks = [];
  List<SpotifyTrack> spotifyAudioLocationTracks = [];

  bool isLoading = true;
  bool isLoadingMood = false;
  StreamSubscription<Position>? locationStream;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _activeSubTab) {
        setState(() {
          _activeSubTab = _tabController.index;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadLastMood();
      initTracks();
    });
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

    await loadGlobalRecommendations();
    await loadMoodRecommendations();
    await loadLocationRecommendations();

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> loadGlobalRecommendations() async {
    try {
      final globalLocal =
          await localRecommender.fetchGlobalRecommendationsFromLocal();

      List<SpotifyTrack> globalSpotify = [];
      if (accessToken != null) {
        globalSpotify =
            await spotifyRecommender.fetchGlobalRecommendationsFromSpotify();
      }

      if (mounted) {
        setState(() {
          globalLocalTracks = globalLocal;
          globalSpotifyTracks = globalSpotify;
        });
      }
    } catch (e, stackTrace) {
      log.e("Failed to global recos: $e $stackTrace");
    }
  }

  Future<void> loadMoodRecommendations({bool forceRefresh = false}) async {
    setState(() => isLoadingMood = true);
    try {
      final local =
          await localRecommender.fetchMoodRecommendationsFromLocal();

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

        final localRecommendations =
            await localRecommender.fetchLocationRecommendationFromLocal(
          latitude: position.latitude,
          longitude: position.longitude,
        );

        localRecommendations.sort(
          (a, b) => b.streamCount.compareTo(a.streamCount),
        );

        final locationAddress =
            await locationServices.getLocationIQAddress(roundedLat, roundedLng);

        List<SpotifyTrack> spotifyLocationRecommendations = [];
        if (accessToken != null) {
          spotifyLocationRecommendations =
              await spotifyRecommender.fetchLocationRecommendationsFromSpotify(
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }

        if (mounted) {
          setState(() {
            detectedLocation = locationAddress;
            localAudioLocationTracks = localRecommendations;
            spotifyAudioLocationTracks = spotifyLocationRecommendations;
            currentLatLng = LatLng(roundedLat, roundedLng);
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
        setState(() {
          detectedMood = result.emotionLabel!;
          detectedEmotionConfidence = result.confidenceScore?.toStringAsFixed(4);
        });
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
    _tabController.dispose();
    locationServices.stopRealtimeTracking();
    locationStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMid,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryPurple,
                ),
              )
            : Column(
                children: [
                  // App Bar / Segmented Switcher for Emotion & Location
                  if (_activeSubTab > 0) _buildSubTabHeader(),

                  // Sub-tab pages
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // 1. Home / All tab
                        _buildHomeTab(),

                        // 2. Emotion Recognition & Mood Recos
                        _buildEmotionTab(),

                        // 3. Location & Map Recos
                        _buildLocationTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  // Segmented Pill Navigation Bar [All] [Emotion] [Location]
  Widget _buildSubTabHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              ClayCircleButton(
                icon: Icons.arrow_back_rounded,
                size: 38,
                onPressed: () {
                  _tabController.animateTo(0);
                },
              ),
              const SizedBox(width: 12),
              const Text(
                "AudioLoca",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSegmentedPills(),
        ],
      ),
    );
  }

  Widget _buildSegmentedPills() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5DCF8),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark.withValues(alpha: 0.12),
            offset: const Offset(1, 3),
            blurRadius: 6,
          ),
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-1, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSegmentItem(0, "All"),
          _buildSegmentItem(1, "Emotion"),
          _buildSegmentItem(2, "Location"),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(int index, String label) {
    final isSelected = _activeSubTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: isSelected
              ? BoxDecoration(
                  gradient: AppGradients.primaryButton,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.35),
                      offset: const Offset(1, 3),
                      blurRadius: 8,
                    ),
                  ],
                )
              : const BoxDecoration(),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.primaryPurple,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: HOME / ALL
  // -------------------------------------------------------------
  Widget _buildHomeTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Top Header Banner matching Reference Design
        _buildHeroBanner(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Search Bar Capsule
              _buildSearchBarCapsule(),

              const SizedBox(height: 18),

              // Quick Actions Row (Search, Camera, Map, Profile)
              _buildQuickActionsRow(),

              const SizedBox(height: 22),

              // Recently Played Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recently Played",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _tabController.animateTo(1);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.pillBg.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Local Tracks List
              if (globalLocalTracks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: ClayDecorations.card(radius: 20),
                  child: const Center(
                    child: Text(
                      "No tracks available yet.",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                LocalListView(allTracks: globalLocalTracks),

              // Spotify Section if available
              if (accessToken != null && globalSpotifyTracks.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Spotify Results",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SpotifyListView(allTracks: globalSpotifyTracks),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  // Hero Banner with AudioLoca title, subtitle and 3D headphone graphic
  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        gradient: AppGradients.headerBanner,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x35552AA8),
            offset: Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Logo and text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/audioloca.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "AudioLoca",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Music connects people, places and moments.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Right: 3D Headphones Graphic
          _build3DHeadphoneGraphic(),
        ],
      ),
    );
  }

  // Soft clay 3D headphone illustration
  Widget _build3DHeadphoneGraphic() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFFBCA6FB),
            Color(0xFF7A4EE5),
            Color(0xFF552CA3),
          ],
          center: Alignment(-0.3, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(3, 8),
            blurRadius: 14,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.4),
            offset: const Offset(-2, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.headphones_rounded,
          size: 44,
          color: Colors.white,
        ),
      ),
    );
  }

  // Claymorphic Search Capsule
  Widget _buildSearchBarCapsule() {
    return GestureDetector(
      onTap: () {
        TabsRouting.of(context)?.setTab(1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDark.withValues(alpha: 0.18),
              offset: const Offset(0, 6),
              blurRadius: 14,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(0, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: const [
            Icon(
              Icons.search_rounded,
              color: AppColors.primaryPurple,
              size: 22,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Search for users, tracks, artists, or places...",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quick Action Buttons Row (Search, Camera, Map, Profile)
  Widget _buildQuickActionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionTile(
          icon: Icons.music_note_rounded,
          label: "Search",
          isPrimary: true,
          onTap: () => TabsRouting.of(context)?.setTab(1),
        ),
        _buildActionTile(
          icon: Icons.photo_camera_rounded,
          label: "Camera",
          onTap: () => TabsRouting.of(context)?.setTab(2),
        ),
        _buildActionTile(
          icon: Icons.location_on_rounded,
          label: "Map",
          onTap: () => _tabController.animateTo(2),
        ),
        _buildActionTile(
          icon: Icons.person_rounded,
          label: "Profile",
          onTap: () => TabsRouting.of(context)?.setTab(4),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: isPrimary
                ? BoxDecoration(
                    gradient: AppGradients.primaryButton,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withValues(alpha: 0.38),
                        offset: const Offset(2, 6),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.4),
                        offset: const Offset(-2, -2),
                        blurRadius: 6,
                      ),
                    ],
                  )
                : BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowDark.withValues(alpha: 0.16),
                        offset: const Offset(2, 5),
                        blurRadius: 10,
                      ),
                      const BoxShadow(
                        color: Colors.white,
                        offset: Offset(-2, -2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
            child: Center(
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : AppColors.primaryPurple,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: EMOTION RECOGNITION & MOOD RECOMMENDATIONS
  // -------------------------------------------------------------
  Widget _buildEmotionTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),

        // 3D Mood Character & Scan Hero
        _buildMoodHero(),

        const SizedBox(height: 20),

        // Big Clay Scan Button
        Center(
          child: ClayButton(
            text: "Scan",
            icon: Icons.sentiment_satisfied_alt_rounded,
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 14),
            onPressed: scanMood,
          ),
        ),

        const SizedBox(height: 24),

        // Detected Mood Card
        const Text(
          "Detected Mood",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 10),
        ClayCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.pillBg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowDark.withValues(alpha: 0.12),
                      offset: const Offset(1, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    "😊",
                    style: TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detectedMood ?? "No mood detected yet",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    if (detectedEmotionConfidence != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        "($detectedEmotionConfidence)",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Mood-Based Recommendations
        const Text(
          "Mood-Based Recommendations",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 12),

        if (isLoadingMood)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryPurple,
              ),
            ),
          )
        else ...[
          if (localTracks.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: ClayDecorations.card(radius: 20),
              child: const Center(
                child: Text(
                  "No mood recommendations yet. Tap Scan above!",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            LocalListView(allTracks: localTracks),

          if (accessToken != null && spotifyTracks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "Spotify Recommendations",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 12),
            SpotifyListView(allTracks: spotifyTracks),
          ],
        ],

        const SizedBox(height: 80),
      ],
    );
  }

  // 3D Mood Character Sphere
  Widget _buildMoodHero() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Floating 3D notes
            Positioned(
              top: 0,
              left: 30,
              child: Icon(
                Icons.music_note_rounded,
                size: 26,
                color: AppColors.primaryLight.withValues(alpha: 0.8),
              ),
            ),
            Positioned(
              top: 10,
              right: 30,
              child: Icon(
                Icons.music_note_rounded,
                size: 22,
                color: AppColors.primaryLight.withValues(alpha: 0.8),
              ),
            ),

            // Character Body
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFB59BF8),
                    Color(0xFF865DF2),
                    Color(0xFF5D31BD),
                  ],
                  center: Alignment(-0.35, -0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.35),
                    offset: const Offset(4, 10),
                    blurRadius: 18,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    offset: const Offset(-3, -3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E175E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E175E),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 14,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E175E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          "Scan My Mood",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "How are you feeling today?",
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 3: LOCATION & MAP RECOMMENDATIONS
  // -------------------------------------------------------------
  Widget _buildLocationTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),

        // Info pill card: "Discover music around you and explore local tracks."
        ClayCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.pillBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primaryPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Discover music around you and explore local tracks.",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.dark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Map inside rounded Clay Card
        Container(
          height: 230,
          decoration: ClayDecorations.card(radius: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: currentLatLng ??
                        const LatLng(14.587068, 120.976201),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.audioloca',
                    ),
                    if (currentLatLng != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: currentLatLng!,
                            width: 70,
                            height: 70,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Concentric pulse circle
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryPurple.withValues(
                                      alpha: 0.18,
                                    ),
                                    border: Border.all(
                                      color: AppColors.primaryPurple.withValues(
                                        alpha: 0.35,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppGradients.primaryButton,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x40673AB7),
                                        offset: Offset(0, 3),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Recenter Clay Button on bottom right
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: ClayCircleButton(
                    icon: Icons.my_location_rounded,
                    size: 38,
                    onPressed: () {
                      if (currentLatLng != null) {
                        _mapController.move(currentLatLng!, 15);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Address Card
        ClayCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.primaryPurple,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  detectedLocation ?? "Locating your current place...",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Location-Based Recommendations Header
        const Text(
          "Location-Based Recommendations",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 12),

        if (localAudioLocationTracks.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: ClayDecorations.card(radius: 20),
            child: const Center(
              child: Text(
                "No local tracks found nearby.",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          LocalListView(
            allTracks: localAudioLocationTracks,
            showRank: true,
          ),

        if (accessToken != null &&
            spotifyAudioLocationTracks.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            "Spotify Nearby Recommendations",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 12),
          SpotifyListView(allTracks: spotifyAudioLocationTracks),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}
