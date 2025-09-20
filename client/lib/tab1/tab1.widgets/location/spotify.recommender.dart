import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/player/player.manager.dart';
import 'package:audioloca/player/controllers/local.player.dart';
import 'package:audioloca/player/controllers/spotify.player.dart';
import 'package:audioloca/services/stream.service.dart';
import 'package:audioloca/spotify/models/track.model.dart';

final storage = SecureStorageService();
final streamServices = StreamServices();

class AudioListItem extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final String duration;
  final VoidCallback onTap;

  const AudioListItem({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            imageUrl: imageUrl,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(
                color: AppColors.color1,
                strokeWidth: 2,
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey[300],
              child: Icon(
                Icons.broken_image,
                size: 40,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Text(duration),
      ),
    );
  }
}

class LocationSpotifyListView extends StatefulWidget {
  final List<SpotifyTrack> allTracks;

  const LocationSpotifyListView({super.key, required this.allTracks});

  @override
  State<LocationSpotifyListView> createState() =>
      LocationSpotifyListViewState();
}

class LocationSpotifyListViewState extends State<LocationSpotifyListView> {
  static const int initialLimit = 10;
  static const int increment = 10;

  late List<SpotifyTrack> visibleTracks;
  bool isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    visibleTracks = widget.allTracks.take(initialLimit).toList();
  }

  void loadMore() async {
    if (isLoadingMore) return;
    setState(() => isLoadingMore = true);

    await Future.delayed(const Duration(milliseconds: 300));
    final nextLimit = visibleTracks.length + increment;
    setState(() {
      visibleTracks = widget.allTracks
          .take(nextLimit.clamp(0, widget.allTracks.length))
          .toList();
      isLoadingMore = false;
    });
  }

  Future<void> handleTrackTap(SpotifyTrack track, {String? imageUrl}) async {
    final spotify = SpotifyPlayerService();
    final manager = NowPlayingManager();
    final uri = 'spotify:track:${track.id}';

    bool shouldSendStream = false;

    try {
      await spotify.playTrackUri(
        spotifyUri: uri,
        title: track.name,
        subtitle: track.artist,
        imageUrl: imageUrl ?? '',
      );
      manager.useSpotify();
      shouldSendStream = true;
    } catch (e) {
      if (track.previewUrl != null) {
        await LocalPlayerService().playFromUrl(
          url: track.previewUrl!,
          title: track.name,
          subtitle: track.artist,
          imageUrl: imageUrl ?? '',
        );
        manager.useLocal();
        shouldSendStream = true;
      } else {
        final uri = Uri.parse(track.externalUrl);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to play. Opening in Spotify…')),
        );

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          shouldSendStream = true;
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Spotify link.')),
          );
        }
      }
    }

    if (shouldSendStream && context.mounted) {
      final jwtToken = await storage.getAccessToken();
      if (jwtToken != null) {
        if (!mounted) return;
        await streamServices.sendStream(
          context,
          jwtToken,
          spotifyId: track.id,
          type: "spotify",
        );
      }
    }
  }

  String formatDuration(int ms) {
    final seconds = (ms / 1000).round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: visibleTracks.length,
            itemBuilder: (context, index) {
              final track = visibleTracks[index];
              return AudioListItem(
                imageUrl:
                    track.albumImageUrl ?? 'https://via.placeholder.com/50',
                title: track.name,
                subtitle: track.artist,
                duration: formatDuration(track.durationMs),
                onTap: () => handleTrackTap(track),
              );
            },
          ),
        ),
        if (visibleTracks.length < widget.allTracks.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: isLoadingMore
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.color1,
                      strokeWidth: 2,
                    ),
                  )
                : GestureDetector(
                    onTap: loadMore,
                    child: const Text(
                      'Load More',
                      style: TextStyle(
                        color: AppColors.color1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}
