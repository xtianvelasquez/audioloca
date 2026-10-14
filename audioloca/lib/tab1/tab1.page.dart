import 'dart:async';
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

import 'package:audioloca/theme.dart';
import 'package:audioloca/core/secure.storage.dart';
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
  String? detectedLocation;
  String? accessToken;
  LatLng? currentLatLng;

  List<Audio> globalLocalTracks = [];
  List<SpotifyTrack> globalSpotifyTracks = [];

  List<Audio> localAudioLocationTracks = [];
  List<SpotifyTrack> spotifyAudioLocationTracks = [];

  bool isLoading = true;
  StreamSubscription<Position>? locationStream;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
                  // Categories All, Emotion, and Location under Home tab
                  _buildHomeHeader(),

                  // Sub-tab pages
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // 1. Home / All tab
                        _buildHomeTab(),

                        // 2. Location & Map Recos
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
  Widget _buildHomeHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (_activeSubTab > 0) ...[
                    ClayCircleButton(
                      icon: Icons.arrow_back_rounded,
                      size: 36,
                      onPressed: () {
                        _tabController.animateTo(0);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowDark.withValues(alpha: 0.18),
                          offset: const Offset(1, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/audioloca.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "AudioLoca",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => TabsRouting.of(context)?.setTab(4),
                child: Container(
                  width: 38,
                  height: 38,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withValues(alpha: 0.25),
                        offset: const Offset(1, 4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/audioloca.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
          _buildSegmentItem(1, "Location"),
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

              const SizedBox(height: 20),

              // Discover / Local Tracks Section
              Row(
                children: const [
                  Icon(
                    Icons.audiotrack_rounded,
                    color: AppColors.primaryPurple,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Discover picks for you",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Local Tracks",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 12),

              // Local Tracks List
              if (globalLocalTracks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: ClayDecorations.card(radius: 20),
                  child: const Center(
                    child: Text(
                      "No local tracks available.",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                LocalListView(allTracks: globalLocalTracks),

              // Spotify Section if available
              if (accessToken != null && globalSpotifyTracks.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: const [
                    Icon(
                      Icons.graphic_eq_rounded,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Spotify Tracks",
                      style: TextStyle(
                        fontSize: 18,
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

  // Hero Banner with headline and 3D headphone graphic
  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 22),
      decoration: BoxDecoration(
        gradient: AppGradients.headerBanner,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x35552AA8),
            offset: Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Headline and text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Discover Your Sound",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Music connects people, places and moments.",
                  style: TextStyle(
                    fontSize: 12,
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
