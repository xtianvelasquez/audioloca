import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart';
import 'package:audioloca/player/models/player.model.dart';

class LocalPlayerService {
  LocalPlayerService._internal() {
    init();
  }

  static final LocalPlayerService instance = LocalPlayerService._internal();
  factory LocalPlayerService() => instance;

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  final ValueNotifier<MediaMetadata?> currentMedia = ValueNotifier(null);
  final BehaviorSubject<String?> _errorController = BehaviorSubject<String?>();
  Stream<String?> get errorStream => _errorController.stream;

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
            duration: duration ?? Duration.zero,
            playerState: PlayerStateInfo(playing: state.playing),
          );
        },
      );

  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.music());

      _player.playbackEventStream.listen(
        (event) {},
        onError: (e, st) => _handleError(e, st, 'playbackEventStream'),
      );
    } catch (e, st) {
      _handleError(e, st, 'init');
    }
  }

  Future<void> playFromUrl({
    required String url,
    String? title,
    String? subtitle,
    String? imageUrl,
  }) async {
    if (url.isEmpty || !(Uri.tryParse(url)?.hasAbsolutePath ?? false)) {
      _errorController.add('Invalid or empty URL');
      throw ArgumentError('Invalid or empty URL');
    }

    try {
      final metadata = MediaMetadata(
        url: url,
        title: title ?? '',
        subtitle: subtitle ?? '',
        imageUrl: imageUrl ?? '',
      );
      currentMedia.value = metadata;

      final current = _player.audioSource;
      final same =
          current is ProgressiveAudioSource && current.uri.toString() == url;

      if (same) {
        await _player.play();
        return;
      }

      await _trySetUrl(url);
      await _player.play();
    } catch (e, st) {
      _handleError(e, st, 'playFromUrl');
      rethrow;
    }
  }

  Future<void> _trySetUrl(String url, {int retries = 1}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        await _player.setUrl(url);
        return;
      } on PlayerException catch (e, st) {
        if (i == retries) {
          _handleError(e, st, 'setUrl (PlayerException)');
          throw Exception('Failed to load audio: ${e.message}');
        }
      } catch (e, st) {
        if (i == retries) {
          _handleError(e, st, 'setUrl (generic)');
          throw Exception('Unexpected error while loading audio.');
        }
      }
    }
  }

  void _handleError(Object error, StackTrace stackTrace, [String? context]) {
    final message =
        'AudioPlayerService Error${context != null ? ' in $context' : ''}: $error';
    debugPrint(message);
    debugPrintStack(stackTrace: stackTrace);
    _errorController.add(message);
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

  void dispose() {
    _errorController.close();
    _player.dispose();
  }
}
