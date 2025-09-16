import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioloca/services/local.player.service.dart';
import 'package:audioloca/services/stream.location.service.dart';
import 'package:audioloca/global/player.manager.dart';
import 'package:audioloca/models/audio.model.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/theme.dart';

final storage = SecureStorageService();
final streamLocationServices = StreamLocationServices();

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

class LocationLocalListView extends StatefulWidget {
  final List<LocalAudioLocation> allTracks;

  const LocationLocalListView({super.key, required this.allTracks});

  @override
  State<LocationLocalListView> createState() => LocationLocalListViewState();
}

class LocationLocalListViewState extends State<LocationLocalListView> {
  static const int initialLimit = 10;
  static const int increment = 10;

  late List<LocalAudioLocation> visibleTracks;
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

  Future<void> handleTrackTap(LocalAudioLocation audio) async {
    final localPlayer = LocalPlayerService();
    final manager = NowPlayingManager();

    try {
      await localPlayer.playFromUrl(
        url: audio.audioRecord ?? '',
        title: audio.audioTitle,
        subtitle: audio.username,
        imageUrl: audio.albumCover,
      );
      manager.useLocal();

      final jwtToken = await storage.getAccessToken();
      if (jwtToken != null) {
        await streamLocationServices.sendStream(
          jwtToken,
          audioId: audio.audioId,
          type: "local",
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play ${audio.audioTitle}')),
      );
    }
  }

  String formatDuration(String rawDuration) {
    try {
      final parts = rawDuration.split(':');
      final minutes = int.parse(parts[1]);
      final seconds = int.parse(parts[2].split('+')[0]);
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return rawDuration;
    }
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
              final audio = visibleTracks[index];
              return AudioListItem(
                imageUrl: audio.albumCover,
                title: audio.audioTitle,
                subtitle: audio.username,
                duration: formatDuration(audio.duration),
                onTap: () => handleTrackTap(audio),
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
