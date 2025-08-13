import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';

/// A small class that holds combined streams for UI convenience.
class PlaybackStateData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
  final PlayerState playerState;

  PlaybackStateData({
    required this.position,
    required this.bufferedPosition,
    required this.duration,
    required this.playerState,
  });
}

class AudioPlayerService {
  AudioPlayerService._internal() {
    _init();
  }

  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  final _player = AudioPlayer();
  // Expose player publicly if needed:
  AudioPlayer get player => _player;

  // Simple notifier to expose the current media metadata (title, image, subtitle)
  final ValueNotifier<Map<String, dynamic>?> currentMedia = ValueNotifier(null);

  // Combined stream: position + buffered + duration + state
  Stream<PlaybackStateData> get playbackStateStream =>
      Rx.combineLatest4<
        Duration,
        Duration,
        Duration?,
        PlayerState,
        PlaybackStateData
      >(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        _player.playerStateStream,
        (position, buffered, duration, state) {
          return PlaybackStateData(
            position: position,
            bufferedPosition: buffered,
            duration: duration,
            playerState: state,
          );
        },
      );

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());
    // optional: handle audio interruptions automatically:
    _player.playbackEventStream.listen(
      (event) {},
      onError: (e, st) {
        // log or handle errors
      },
    );
  }

  /// Play a url. Also update metadata for UI.
  Future<void> playFromUrl({
    required String url,
    String? title,
    String? subtitle,
    String? imageUrl,
  }) async {
    try {
      currentMedia.value = {
        'url': url,
        'title': title ?? '',
        'subtitle': subtitle ?? '',
        'imageUrl': imageUrl ?? '',
      };

      // If same url and already playing/paused, just call play() or seek(0)
      final current = _player.audioSource;
      final same =
          current is ProgressiveAudioSource && current.uri.toString() == url;
      if (same) {
        await _player.play();
        return;
      }

      // Set source and play
      await _player.setUrl(url); // streams from your FastAPI endpoint
      await _player.play();
    } catch (e) {
      // handle error: show a snackbar on caller side
      rethrow;
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> rewind10() async {
    final pos = _player.position;
    final target = pos - const Duration(seconds: 10);
    await _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> forward10() async {
    final pos = _player.position;
    final dur = _player.duration ?? Duration.zero;
    final target = pos + const Duration(seconds: 10);
    await _player.seek(target > dur ? dur : target);
  }
}
