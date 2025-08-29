import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioloca/models/audio.model.dart';

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
            placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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

class AudioListView extends StatefulWidget {
  final List<SpotifyTrack> allTracks;

  const AudioListView({super.key, required this.allTracks});

  @override
  State<AudioListView> createState() => _AudioListViewState();
}

class _AudioListViewState extends State<AudioListView> {
  static const int initialLimit = 10;
  static const int increment = 10;

  late List<SpotifyTrack> visibleTracks;
  bool _isLoadingMore = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    visibleTracks = widget.allTracks.take(initialLimit).toList();
  }

  void _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    await Future.delayed(const Duration(milliseconds: 300));
    final nextLimit = visibleTracks.length + increment;
    setState(() {
      visibleTracks = widget.allTracks
          .take(nextLimit.clamp(0, widget.allTracks.length))
          .toList();
      _isLoadingMore = false;
    });
  }

  void _handleTrackTap(SpotifyTrack track) {
    if (track.previewUrl != null) {
      _audioPlayer.setUrl(track.previewUrl!);
      _audioPlayer.play();
    } else {
      launchUrl(Uri.parse(track.externalUrl));
    }
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return "$minutes:${remainingSeconds.toString().padLeft(2, '0')}";
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
                duration: _formatDuration(track.durationMs),
                onTap: () => _handleTrackTap(track),
              );
            },
          ),
        ),
        if (visibleTracks.length < widget.allTracks.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _isLoadingMore
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : GestureDetector(
                    onTap: _loadMore,
                    child: const Text(
                      "Load More",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}
