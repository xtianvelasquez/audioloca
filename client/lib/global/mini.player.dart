import 'package:flutter/material.dart';
import 'package:audioloca/services/audio.player.service.dart';
import 'package:audioloca/global/full.player.dart';
import 'package:audioloca/theme.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});
  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final _service = AudioPlayerService();
  late final Stream<PlaybackStateData> _stateStream;

  @override
  void initState() {
    super.initState();
    _stateStream = _service.playbackStateStream;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: _service.currentMedia,
      builder: (context, media, child) {
        if (media == null) return const SizedBox.shrink();

        final title = media['title'] as String? ?? '';
        final subtitle = media['subtitle'] as String? ?? '';
        final imageUrl = media['imageUrl'] as String? ?? '';

        return Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              // cover
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

              // title & subtitle + tap to open full player
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullPlayerScreen(),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // play/pause and small progress
              StreamBuilder<PlaybackStateData>(
                stream: _stateStream,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final position = data?.position ?? Duration.zero;
                  final playing = data?.playerState.playing ?? false;

                  String shortTime(Duration d) {
                    final mm = d.inMinutes
                        .remainder(60)
                        .toString()
                        .padLeft(2, '0');
                    final ss = d.inSeconds
                        .remainder(60)
                        .toString()
                        .padLeft(2, '0');
                    return "${d.inHours > 0 ? '${d.inHours}:' : ''}$mm:$ss";
                  }

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
                            _service.pause();
                          } else {
                            _service.player.play();
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          shortTime(position),
                          style: AppTextStyles.bodySmall,
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
