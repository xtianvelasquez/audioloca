import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';

import 'package:audioloca/environment.dart';
import 'package:audioloca/theme.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/player/player.manager.dart';
import 'package:audioloca/player/controllers/local.player.dart';
import 'package:audioloca/services/stream.service.dart';
import 'package:audioloca/business/location.services.dart';
import 'package:audioloca/local/models/audio.model.dart';

final log = Logger();
final storage = SecureStorageService();
final streamServices = StreamServices();
final locationServices = LocationServices();

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
            imageUrl: "${Environment.audiolocaBaseUrl}/$imageUrl",
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

class EmotionLocalListView extends StatefulWidget {
  final List<Audio> allTracks;

  const EmotionLocalListView({super.key, required this.allTracks});

  @override
  State<EmotionLocalListView> createState() => EmotionLocalListViewState();
}

class EmotionLocalListViewState extends State<EmotionLocalListView> {
  static const int initialLimit = 10;
  static const int increment = 10;

  late List<Audio> visibleTracks;
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

  Future<void> handleTrackTap(Audio audio) async {
    final localPlayer = LocalPlayerService();
    final manager = NowPlayingManager();

    final audioUrl = "${Environment.audiolocaBaseUrl}/${audio.audioRecord}";
    final photoUrl = "${Environment.audiolocaBaseUrl}/${audio.albumCover}";

    try {
      await localPlayer.playFromUrl(
        url: audioUrl,
        title: audio.audioTitle,
        subtitle: audio.username,
        imageUrl: photoUrl,
      );
      manager.useLocal();

      final jwtToken = await storage.getJwtToken();
      log.i('[Flutter] sendStream() $jwtToken');

      if (jwtToken != null) {
        if (!mounted) return;

        final locationReady = await locationServices.ensureLocationReady(
          context,
        );
        if (!locationReady) {
          log.w('[Flutter] Location not ready. Skipping stream logging.');
          return;
        }

        Position position;
        try {
          position = await locationServices.getUserPosition();
        } catch (e, stackTrace) {
          log.e('[Flutter] Failed to get position: $e $stackTrace');
          return;
        }

        await streamServices.sendStream(
          jwtToken,
          position: position,
          audioId: audio.audioId,
          type: "local",
        );

        log.i('[Flutter] sendStream() called');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to play ${audio.audioTitle}. Please try again later.',
          ),
        ),
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
