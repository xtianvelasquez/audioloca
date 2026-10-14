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
    final title = media?.title ?? 'No Track Playing';
    final subtitle = media?.subtitle ?? 'Unknown Artist';
    final imageUrl = media?.imageUrl ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgMid,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight;
            // Dynamically scale artwork based on screen height
            final artSize = (screenHeight * 0.36).clamp(180.0, 260.0);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 10),

                          // Top Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ClayCircleButton(
                                icon: Icons.keyboard_arrow_down_rounded,
                                size: 42,
                                iconSize: 26,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const Text(
                                "Now Playing",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dark,
                                ),
                              ),
                              const SizedBox(width: 42), // Balance spacing
                            ],
                          ),

                          SizedBox(height: screenHeight < 680 ? 12 : 20),

                          // Responsive Clay Cover Art Frame
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: ClayDecorations.card(radius: 28),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        height: artSize,
                                        width: artSize,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          height: artSize,
                                          width: artSize,
                                          color: AppColors.pillBg,
                                          child: const Icon(
                                            Icons.music_note_rounded,
                                            size: 70,
                                            color: AppColors.color2,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: artSize,
                                        width: artSize,
                                        color: AppColors.pillBg,
                                        child: const Icon(
                                          Icons.music_note_rounded,
                                          size: 70,
                                          color: AppColors.color2,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          SizedBox(height: screenHeight < 680 ? 14 : 22),

                          // Track Title & Artist
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.dark,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      // Playback Slider & Controls
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 20),
                        child: StreamBuilder<PlaybackStateData>(
                          stream: _stateStream,
                          builder: (context, snapshot) {
                            final data = snapshot.data;
                            final position = data?.position ?? Duration.zero;
                            final duration = data?.duration ?? Duration.zero;
                            final playing = data?.playerState.playing ?? false;

                            final max = duration.inMilliseconds.toDouble();
                            final value = position.inMilliseconds
                                .toDouble()
                                .clamp(0.0, max);

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Slider
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: AppColors.primaryPurple,
                                    inactiveTrackColor: AppColors.pillBg,
                                    thumbColor: AppColors.primaryPurple,
                                    trackHeight: 5,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 7,
                                    ),
                                    overlayColor: AppColors.primaryPurple
                                        .withValues(alpha: 0.2),
                                  ),
                                  child: Slider(
                                    min: 0,
                                    max: max > 0 ? max : 1,
                                    value: value,
                                    onChanged: (val) {
                                      final target =
                                          Duration(milliseconds: val.toInt());
                                      useSpotify
                                          ? spotify.seek(target)
                                          : local.seek(target);
                                    },
                                  ),
                                ),

                                // Time Labels
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        formatTime(position),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        formatTime(duration),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Circular Clay Playback Controls
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ClayCircleButton(
                                      icon: Icons.replay_10_rounded,
                                      size: 46,
                                      iconSize: 22,
                                      onPressed: () => useSpotify
                                          ? spotify.rewind10()
                                          : local.rewind10(),
                                    ),
                                    const SizedBox(width: 22),
                                    ClayCircleButton(
                                      icon: playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 64,
                                      iconSize: 34,
                                      isPrimary: true,
                                      onPressed: () {
                                        if (playing) {
                                          useSpotify
                                              ? spotify.pause()
                                              : local.pause();
                                        } else {
                                          useSpotify
                                              ? spotify.resume()
                                              : local.player
                                                  .play()
                                                  .catchError((e) {
                                                  debugPrint(
                                                      'Local play error: $e');
                                                });
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 22),
                                    ClayCircleButton(
                                      icon: Icons.forward_10_rounded,
                                      size: 46,
                                      iconSize: 22,
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
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
