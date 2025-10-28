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

  @override
  void initState() {
    super.initState();
    loadAccessToken();
  }

  Future<void> loadAccessToken() async {
    final token = await storage.getAccessToken();
    setState(() => accessToken = token);
  }

  Future<void> handleSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      isSearching = true;
      localResults = [];
      spotifyResults = [];
    });

    try {
      final local = await audioServices.searchForAudio(query);
      List<SpotifyTrack> spotify = [];

      if (accessToken != null) {
        spotify = await TrackServices().searchSpotifyTracks(
          accessToken!,
          query,
        );
      }

      setState(() {
        localResults = local;
        spotifyResults = spotify;
        isSearching = false;
      });
    } catch (e, stackTrace) {
      log.e('[Flutter] Search error: $e $stackTrace');
      setState(() => isSearching = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search failed. Please try again.')),
      );
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.color1,
        title: TextField(
          controller: searchController,
          onSubmitted: handleSearch,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: "Search songs...",
            border: InputBorder.none,
            hintStyle: TextStyle(color: AppColors.light),
            prefixIcon: Icon(Icons.search, color: AppColors.light),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: isSearching
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (localResults.isNotEmpty) ...[
                  const Text("Local Results", style: sectionStyle),
                  const SizedBox(height: 8),
                  ...localResults.map(
                    (audio) => AudioListItem(
                      imageUrl: resolveImageUrl(audio.albumCover),
                      title: audio.audioTitle,
                      subtitle: audio.username,
                      streamCount: audio.streamCount,
                      duration: formatLocalTrackDuration(audio.duration),
                      onTap: () => tapController.handleLocalTrackTap(
                        audio,
                        context,
                        context.mounted,
                      ),
                    ),
                  ),
                ],
                if (spotifyResults.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text("Spotify Results", style: sectionStyle),
                  const SizedBox(height: 8),
                  ...spotifyResults.map(
                    (track) => AudioListItem(
                      imageUrl: resolveImageUrl(track.albumImageUrl),
                      title: track.name,
                      subtitle: track.artist,
                      streamCount: track.streamCount ?? 0,
                      duration: formatSpotifyTrackDuration(track.durationMs),
                      onTap: () => tapController.handleSpotifyTrackTap(
                        track,
                        context,
                        context.mounted,
                      ),
                    ),
                  ),
                ],
                if (localResults.isEmpty && spotifyResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text("No results found")),
                  ),
              ],
            ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

const sectionStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
