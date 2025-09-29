import 'package:flutter/material.dart';
import 'package:audioloca/player/controllers/local.player.dart';
import 'package:audioloca/player/controllers/spotify.player.dart';
import 'package:audioloca/player/models/player.model.dart';
import 'package:audioloca/player/views/full.player.dart';
import 'package:audioloca/player/player.manager.dart';
import 'package:audioloca/theme.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => MiniPlayerState();
}

class MiniPlayerState extends State<MiniPlayer> {
  final local = LocalPlayerService();
  final spotify = SpotifyPlayerService();
  final manager = NowPlayingManager();

  Stream<PlaybackStateData> stateStream = const Stream.empty();
  ValueNotifier<MediaMetadata?> currentMedia = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    bindToActive();
    manager.notifier.addListener(bindToActive);
  }

  void bindToActive() {
    final useSpotify = manager.notifier.value == NowPlayingSource.spotify;
    final newStream = useSpotify
        ? spotify.playbackStateStream
        : local.playbackStateStream;
    final newMedia = useSpotify ? spotify.currentMedia : local.currentMedia;

    if (stateStream != newStream || currentMedia != newMedia) {
      setState(() {
        stateStream = newStream;
        currentMedia = newMedia;
      });
    }
  }

  @override
  void dispose() {
    manager.notifier.removeListener(bindToActive);
    super.dispose();
  }

  String formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MediaMetadata?>(
      valueListenable: currentMedia,
      builder: (context, media, child) {
        if (media == null) return const SizedBox.shrink();

        final title = media.title;
        final subtitle = media.subtitle;
        final imageUrl = media.imageUrl;
        final useSpotify = manager.notifier.value == NowPlayingSource.spotify;

        return Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.color3,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              // Cover image
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey[300],
                        ),
                ),
              ),

              // Title & subtitle
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FullPlayerScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.keyword.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppTextStyles.keyword.copyWith(
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Playback controls
              StreamBuilder<PlaybackStateData>(
                stream: stateStream,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final position = data?.position ?? Duration.zero;
                  final playing = data?.playerState.playing ?? false;

                  return Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          size: 36,
                        ),
                        onPressed: () {
                          if (playing) {
                            useSpotify ? spotify.pause() : local.pause();
                          } else {
                            useSpotify
                                ? spotify.resume()
                                : local.player.play().catchError((e) {
                                    debugPrint('Local play error: $e');
                                  });
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          formatDuration(position),
                          style: AppTextStyles.keyword,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
