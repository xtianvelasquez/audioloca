import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:logger/logger.dart';
import 'package:audioloca/environment.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/services/audio.player.service.dart';
import 'package:audioloca/models/player.model.dart';

final log = Logger();
final storage = SecureStorageService();

class SpotifyPlayerService {
  SpotifyPlayerService._internal();
  static final SpotifyPlayerService _instance =
      SpotifyPlayerService._internal();
  factory SpotifyPlayerService() => _instance;

  final currentMedia = ValueNotifier<Map<String, dynamic>?>(null);

  final _stateCtrl = StreamController<PlaybackStateData>.broadcast();
  Stream<PlaybackStateData> get playbackStateStream => _stateCtrl.stream;

  int _lastPlaybackPositionMs = 0;
  int _lastDurationMs = 0;
  bool _connected = false;
  StreamSubscription<PlayerState>? _playerSub;

  Future<void> _ensureConnected() async {
    if (_connected) return;

    final token = await storage.getAccessToken();

    try {
      _connected = await SpotifySdk.connectToSpotifyRemote(
        clientId: Environment.spotifyClientId,
        redirectUrl: Environment.spotifyRedirectUri,
        accessToken: token,
      );
      log.i('[Spotify] Connected: $_connected');

      _playerSub?.cancel();
      _playerSub = SpotifySdk.subscribePlayerState().listen((state) {
        final track = state.track;
        _lastPlaybackPositionMs = state.playbackPosition;
        _lastDurationMs = track?.duration ?? 0;
        final isPlaying = !state.isPaused;

        if (track != null && currentMedia.value == null) {
          currentMedia.value = {
            'title': track.name,
            'subtitle': track.artist.name,
            'imageUrl': '',
          };
        }

        _stateCtrl.add(
          PlaybackStateData(
            position: Duration(milliseconds: _lastPlaybackPositionMs),
            bufferedPosition: Duration(milliseconds: _lastPlaybackPositionMs),
            duration: Duration(milliseconds: _lastDurationMs),
            playerState: PlayerStateInfo(playing: isPlaying),
          ),
        );
      }, onError: (err) => log.e('[Spotify] player state error: $err'));
    } catch (e, st) {
      log.e('[Spotify] connect error: $e\n$st');
    }
  }

  Future<void> playTrackUri({
    required String spotifyUri,
    String? title,
    String? subtitle,
    String? imageUrl,
  }) async {
    await _ensureConnected();

    try {
      await AudioPlayerService().pause();
    } catch (_) {}

    currentMedia.value = {
      'title': title ?? '',
      'subtitle': subtitle ?? '',
      'imageUrl': imageUrl ?? '',
    };

    await SpotifySdk.play(spotifyUri: spotifyUri);
  }

  Future<void> pause() async {
    await _ensureConnected();
    await SpotifySdk.pause();
  }

  Future<void> resume() async {
    await _ensureConnected();
    await SpotifySdk.resume();
  }

  Future<void> stop() async {
    await pause();
  }

  Future<void> seek(Duration position) async {
    await _ensureConnected();
    await SpotifySdk.seekTo(positionedMilliseconds: position.inMilliseconds);
  }

  Future<void> rewind10() async {
    final prev =
        Duration(milliseconds: _lastPlaybackPositionMs) -
        const Duration(seconds: 10);
    await seek(prev < Duration.zero ? Duration.zero : prev);
  }

  Future<void> forward10() async {
    final next =
        Duration(milliseconds: _lastPlaybackPositionMs) +
        const Duration(seconds: 10);
    final max = Duration(milliseconds: _lastDurationMs);
    await seek(next > max ? max : next);
  }

  Future<void> disconnect() async {
    try {
      await SpotifySdk.disconnect();
    } catch (_) {}
    _connected = false;
  }

  void dispose() {
    _playerSub?.cancel();
    _stateCtrl.close();
  }
}
