import 'package:flutter/material.dart';
import 'package:audioloca/services/audio.player.service.dart';
import 'package:audioloca/theme.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});
  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  final _service = AudioPlayerService();
  late final Stream<PlaybackStateData> _stateStream;

  @override
  void initState() {
    super.initState();
    _stateStream = _service.playbackStateStream;
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
    final media = _service.currentMedia.value;
    final title = media?['title'] ?? '';
    final subtitle = media?['subtitle'] ?? '';
    final imageUrl = media?['imageUrl'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.subtitle),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          // cover
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null && imageUrl != ''
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
          Text(subtitle, style: AppTextStyles.bodySmall),

          const Spacer(),

          // playback slider + times
          StreamBuilder<PlaybackStateData>(
            stream: _stateStream,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final position = data?.position ?? Duration.zero;
              final buffered = data?.bufferedPosition ?? Duration.zero;
              final duration = data?.duration ?? Duration.zero;
              final playing = data?.playerState.playing ?? false;

              final max = duration.inMilliseconds.toDouble();
              final value = position.inMilliseconds.toDouble().clamp(
                0.0,
                max > 0 ? max : 0.0,
              );
              final bufferedValue = buffered.inMilliseconds.toDouble().clamp(
                0.0,
                max > 0 ? max : 0.0,
              );

              return Column(
                children: [
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // buffered track (thin)
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
                      // main slider (transparent track)
                      Slider(
                        min: 0,
                        max: max > 0 ? max : 1,
                        value: value,
                        onChanged: (val) {
                          _service.seek(Duration(milliseconds: val.toInt()));
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
                          style: AppTextStyles.bodySmall,
                        ),
                        Text(
                          formatTime(duration),
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.replay_10),
                        onPressed: () => _service.rewind10(),
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
                            _service.pause();
                          } else {
                            _service.player.play();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.forward_10),
                        onPressed: () => _service.forward10(),
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
