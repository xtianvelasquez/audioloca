import 'dart:async';
import 'package:logger/logger.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:flutter/foundation.dart';

import 'package:audioloca/environment.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/player/controllers/local.player.dart';
import 'package:audioloca/player/models/player.model.dart';

final log = Logger();
final storage = SecureStorageService();

class SpotifyPlayerService {
  SpotifyPlayerService._internal();
  static final SpotifyPlayerService _instance =
      SpotifyPlayerService._internal();
  factory SpotifyPlayerService() => _instance;

  final ValueNotifier<MediaMetadata?> currentMedia = ValueNotifier(null);
  final _stateCtrl = StreamController<PlaybackStateData>.broadcast();
  Stream<PlaybackStateData> get playbackStateStream => _stateCtrl.stream;

  int lastPlaybackPositionMs = 0;
  int lastDurationMs = 0;
  bool connected = false;
  StreamSubscription<PlayerState>? _playerSub;

  Future<void> _ensureConnected() async {
    if (connected) return;

    final token = await storage.getAccessToken();
    if (token == null || token.isEmpty) {
      log.e('[Spotify Player] Missing access token.');
      throw 'Spotify access token is missing.';
    }

    try {
      connected = await SpotifySdk.connectToSpotifyRemote(
        clientId: Environment.spotifyClientId,
        redirectUrl: Environment.spotifyRedirectUri,
      );
      log.i('[Spotify Player] Connected: $connected');

      _playerSub?.cancel();
      _playerSub = SpotifySdk.subscribePlayerState().listen(
        _handlePlayerState,
        onError: (err) => log.e('[Spotify Player] player state error: $err'),
      );
    } catch (e, stackTrace) {
      log.e('[Spotify] connect error: $e');
      log.e(stackTrace.toString());
      connected = false;
      rethrow;
    }
  }

  void _handlePlayerState(PlayerState state) {
    final track = state.track;
    lastPlaybackPositionMs = state.playbackPosition;
    lastDurationMs = track?.duration ?? 0;
    final isPlaying = !state.isPaused;

    if (track != null && currentMedia.value == null) {
      currentMedia.value = MediaMetadata(
        title: track.name,
        subtitle: track.artist.name!,
        imageUrl: '',
      );
    }

    _stateCtrl.add(
      PlaybackStateData(
        position: Duration(milliseconds: lastPlaybackPositionMs),
        bufferedPosition: Duration(milliseconds: lastPlaybackPositionMs),
        duration: Duration(milliseconds: lastDurationMs),
        playerState: PlayerStateInfo(playing: isPlaying),
      ),
    );
  }

  Future<void> playTrackUri({
    required String spotifyUri,
    String? title,
    String? subtitle,
    String? imageUrl,
  }) async {
    await _ensureConnected();

    try {
      await LocalPlayerService().pause();
    } catch (e) {
      log.w('[Spotify] Failed to pause local player: $e');
    }

    currentMedia.value = MediaMetadata(
      title: title ?? '',
      subtitle: subtitle ?? '',
      imageUrl: imageUrl ?? '',
    );

    try {
      await SpotifySdk.play(spotifyUri: spotifyUri);
    } catch (e, st) {
      log.e('[Spotify] play error: $e');
      log.e(st.toString());
      throw 'Failed to play track';
    }
  }

  Future<void> pause() async {
    await _ensureConnected();
    try {
      await SpotifySdk.pause();
    } catch (e) {
      log.e('[Spotify] pause error: $e');
    }
  }

  Future<void> resume() async {
    await _ensureConnected();
    try {
      await SpotifySdk.resume();
    } catch (e) {
      log.e('[Spotify] resume error: $e');
    }
  }

  Future<void> stop() async => pause();

  Future<void> seek(Duration position) async {
    await _ensureConnected();
    try {
      await SpotifySdk.seekTo(positionedMilliseconds: position.inMilliseconds);
    } catch (e) {
      log.e('[Spotify] seek error: $e');
    }
  }

  Future<void> rewind10() async {
    final prev =
        Duration(milliseconds: lastPlaybackPositionMs) -
        const Duration(seconds: 10);
    await seek(prev < Duration.zero ? Duration.zero : prev);
  }

  Future<void> forward10() async {
    final next =
        Duration(milliseconds: lastPlaybackPositionMs) +
        const Duration(seconds: 10);
    final max = Duration(milliseconds: lastDurationMs);
    await seek(next > max ? max : next);
  }

  Future<void> disconnect() async {
    try {
      await SpotifySdk.disconnect();
    } catch (e) {
      log.w('[Spotify] disconnect error: $e');
    }
    connected = false;
  }

  void dispose() {
    _playerSub?.cancel();
    _stateCtrl.close();
  }
}
