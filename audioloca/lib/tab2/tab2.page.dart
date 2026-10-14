import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/core/utils.dart';
import 'package:audioloca/local/services/audio.service.dart';
import 'package:audioloca/spotify/services/track.service.dart';
import 'package:audioloca/local/models/audio.model.dart';
import 'package:audioloca/spotify/models/track.model.dart';
import 'package:audioloca/controller/tap.controller.dart';
import 'package:audioloca/view/audio.card.dart';
import 'package:audioloca/player/views/mini.player.dart';
import 'package:audioloca/tabs/tabs.routing.dart';

final log = Logger();
final storage = SecureStorageService();
final audioServices = AudioServices();
final tapController = TapController();

class Tab2 extends StatefulWidget {
  const Tab2({super.key});
  @override
  State<Tab2> createState() => Tab2State();
}

class Tab2State extends State<Tab2> {
  final searchController = TextEditingController();
  List<Audio> localResults = [];
  List<SpotifyTrack> spotifyResults = [];
  bool isSearching = false;
  String? accessToken;

  final List<String> suggestions = const [
    "Adele",
    "Hello",
    "Pop",
    "Acoustic",
    "Rock",
  ];
  String? selectedSuggestion;

  @override
  void initState() {
    super.initState();
    loadAccessToken();
  }

  Future<void> loadAccessToken() async {
    final token = await storage.getAccessToken();
    if (mounted) setState(() => accessToken = token);
  }

  Future<void> handleSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      isSearching = true;
      localResults = [];
      spotifyResults = [];
    });

    try {
      final local = await audioServices.searchForAudio(trimmed);
      List<SpotifyTrack> spotify = [];

      if (accessToken != null) {
        spotify = await TrackServices().searchSpotifyTracks(
          accessToken!,
          trimmed,
        );
      }

      if (mounted) {
        setState(() {
          localResults = local;
          spotifyResults = spotify;
          isSearching = false;
        });
      }
    } catch (e, stackTrace) {
      log.e('[Flutter] Search error: $e $stackTrace');
      if (mounted) {
        setState(() => isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search failed. Please try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMid,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Back button and Clay Search Capsule
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  ClayCircleButton(
                    icon: Icons.arrow_back_rounded,
                    size: 42,
                    onPressed: () {
                      TabsRouting.of(context)?.setTab(0);
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowDark.withValues(alpha: 0.18),
                            offset: const Offset(0, 5),
                            blurRadius: 12,
                          ),
                          const BoxShadow(
                            color: Colors.white,
                            offset: Offset(0, -2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.primaryPurple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              onSubmitted: handleSearch,
                              textInputAction: TextInputAction.search,
                              style: const TextStyle(
                                color: AppColors.dark,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                hintText: "Search tracks, artists...",
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                searchController.clear();
                                setState(() {
                                  localResults = [];
                                  spotifyResults = [];
                                  selectedSuggestion = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.pillBg,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: isSearching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryPurple,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      children: [
                        // Suggested Chips Section (matching reference design)
                        const SizedBox(height: 6),
                        const Text(
                          "Suggested",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: suggestions.map((chip) {
                              final isSelected = selectedSuggestion == chip;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClayPillChip(
                                  label: chip,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() => selectedSuggestion = chip);
                                    searchController.text = chip;
                                    handleSearch(chip);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Spotify Results Section
                        if (spotifyResults.isNotEmpty) ...[
                          Row(
                            children: const [
                              Icon(
                                Icons.graphic_eq_rounded,
                                color: AppColors.primaryPurple,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Spotify Results",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...spotifyResults.map(
                            (track) => AudioListItem(
                              imageUrl: resolveImageUrl(track.albumImageUrl),
                              title: track.name,
                              subtitle: track.artist,
                              streamCount: track.streamCount ?? 0,
                              duration: formatSpotifyTrackDuration(
                                track.durationMs,
                              ),
                              onTap: () => tapController.handleSpotifyTrackTap(
                                track,
                                context,
                                context.mounted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Local Results Section
                        if (localResults.isNotEmpty) ...[
                          const Text(
                            "Local Results",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.dark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...localResults.map(
                            (audio) => AudioListItem(
                              imageUrl: resolveImageUrl(audio.albumCover),
                              title: audio.audioTitle,
                              subtitle: audio.username,
                              streamCount: audio.streamCount,
                              duration: formatLocalTrackDuration(
                                audio.duration,
                              ),
                              onTap: () => tapController.handleLocalTrackTap(
                                audio,
                                context,
                                context.mounted,
                              ),
                            ),
                          ),
                        ],

                        // Empty State
                        if (localResults.isEmpty && spotifyResults.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: ClayCard(
                              radius: 20,
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                children: const [
                                  Icon(
                                    Icons.search_rounded,
                                    size: 48,
                                    color: AppColors.color2,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    "Search for your favorite tracks or artists",
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 80),
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
