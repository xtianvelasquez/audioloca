import 'package:flutter/material.dart';
import 'package:audioloca/player/controllers/local.player.dart';
import 'package:audioloca/player/controllers/spotify.player.dart';
import 'package:audioloca/player/player.manager.dart';
import 'package:audioloca/player/models/player.model.dart';
import 'package:audioloca/theme.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});
  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  final local = LocalPlayerService();
  final spotify = SpotifyPlayerService();
  final manager = NowPlayingManager();

  late Stream<PlaybackStateData> _stateStream;
  late ValueNotifier<MediaMetadata?> _currentMedia;
  late bool useSpotify;

  @override
  void initState() {
    super.initState();
    useSpotify = manager.notifier.value == NowPlayingSource.spotify;
    _stateStream = useSpotify
        ? spotify.playbackStateStream
        : local.playbackStateStream;
    _currentMedia = useSpotify ? spotify.currentMedia : local.currentMedia;
  }

  String formatTime(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours;
    if (hh > 0) return '$hh:$mm:$ss';
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final media = _currentMedia.value;
    final title = media?.title ?? '';
    final subtitle = media?.subtitle ?? '';
    final imageUrl = media?.imageUrl ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.subtitle),
        backgroundColor: AppColors.color1,
        foregroundColor: AppColors.light,
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),

          // Cover image
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 300,
                      width: 300,
                      fit: BoxFit.cover,
                    )
                  : Container(height: 300, width: 300, color: Colors.grey[300]),
            ),
          ),

          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.title.copyWith(fontSize: 20)),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.keyword),

          const Spacer(),

          // Playback slider + time labels
          StreamBuilder<PlaybackStateData>(
            stream: _stateStream,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final position = data?.position ?? Duration.zero;
              final buffered = data?.bufferedPosition ?? Duration.zero;
              final duration = data?.duration ?? Duration.zero;
              final playing = data?.playerState.playing ?? false;

              final max = duration.inMilliseconds.toDouble();
              final value = position.inMilliseconds.toDouble().clamp(0.0, max);
              final bufferedValue = buffered.inMilliseconds.toDouble().clamp(
                0.0,
                max,
              );

              return Column(
                children: [
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Buffered track
                      Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: max > 0 ? bufferedValue / max : 0,
                          child: Container(color: Colors.grey.shade400),
                        ),
                      ),

                      // Main slider
                      Slider(
                        min: 0,
                        max: max > 0 ? max : 1,
                        value: value,
                        onChanged: (val) {
                          final target = Duration(milliseconds: val.toInt());
                          useSpotify
                              ? spotify.seek(target)
                              : local.seek(target);
                        },
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatTime(position),
                          style: AppTextStyles.keyword,
                        ),
                        Text(
                          formatTime(duration),
                          style: AppTextStyles.keyword,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Playback controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.replay_10),
                        onPressed: () =>
                            useSpotify ? spotify.rewind10() : local.rewind10(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        iconSize: 56,
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
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
                      const SizedBox(width: 8),
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.forward_10),
                        onPressed: () => useSpotify
                            ? spotify.forward10()
                            : local.forward10(),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
