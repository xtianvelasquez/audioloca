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
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          height: 66,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowDark.withValues(alpha: 0.22),
                offset: const Offset(0, 6),
                blurRadius: 16,
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
              // Cover image
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 10.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: AppColors.pillBg,
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: AppColors.pillBg,
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                ),
              ),

              // Title & subtitle
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FullPlayerScreen(),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
                      Text(
                        formatDuration(position),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: ClayCircleButton(
                          icon: playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 38,
                          iconSize: 22,
                          isPrimary: true,
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
