import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:audioloca/environment.dart';
import 'package:audioloca/core/secure.storage.dart';
import 'package:audioloca/services/stream.service.dart';
import 'package:audioloca/business/location.services.dart';
import 'package:audioloca/local/models/audio.model.dart';
import 'package:audioloca/spotify/models/track.model.dart';
import 'package:audioloca/player/controllers/local.player.dart';
import 'package:audioloca/player/controllers/spotify.player.dart';
import 'package:audioloca/player/player.manager.dart';

final log = Logger();
final storage = SecureStorageService();
final streamServices = StreamServices();
final locationServices = LocationServices();

class TapController {
  Future<void> handleLocalTrackTap(
    Audio audio,
    BuildContext context,
    bool mounted,
  ) async {
    final jwtToken = await storage.getJwtToken();
    if (jwtToken == null || !context.mounted) return;

    final locationReady = await locationServices.ensureLocationReady(context);
    if (!locationReady) {
      log.w('[Flutter] Location not ready. Skipping stream logging.');
      return;
    }

    Future.microtask(
      () => _logStreamCount(
        jwtToken: jwtToken,
        type: "local",
        audioId: audio.audioId,
      ),
    );

    final localPlayer = LocalPlayerService();
    final manager = NowPlayingManager();

    final audioUrl = "${Environment.audiolocaBaseUrl}/${audio.audioRecord}";
    final photoUrl = "${Environment.audiolocaBaseUrl}/${audio.albumCover}";

    try {
      await localPlayer.playFromUrl(
        url: audioUrl,
        title: audio.audioTitle,
        subtitle: audio.username,
        imageUrl: photoUrl,
      );
      manager.useLocal();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to play ${audio.audioTitle}. Please try again later.',
          ),
        ),
      );
    }
  }

  Future<void> handleSpotifyTrackTap(
    SpotifyTrack track,
    BuildContext context,
    bool mounted, {
    String? imageUrl,
  }) async {
    final jwtToken = await storage.getJwtToken();
    if (jwtToken == null || !context.mounted) return;

    final locationReady = await locationServices.ensureLocationReady(context);
    if (!locationReady) {
      log.w('[Flutter] Location not ready. Skipping stream logging.');
      return;
    }

    await _logStreamCount(
      jwtToken: jwtToken,
      type: "spotify",
      spotifyId: track.id,
    );

    final spotify = SpotifyPlayerService();
    final manager = NowPlayingManager();
    final uri = 'spotify:track:${track.id}';

    try {
      await spotify.playTrackUri(
        spotifyUri: uri,
        title: track.name,
        subtitle: track.artist,
        imageUrl: imageUrl ?? '',
      );
      manager.useSpotify();
    } catch (e) {
      if (track.previewUrl != null) {
        await LocalPlayerService().playFromUrl(
          url: track.previewUrl!,
          title: track.name,
          subtitle: track.artist,
          imageUrl: imageUrl ?? '',
        );
        manager.useLocal();
      } else {
        final uri = Uri.parse(track.externalUrl);
        if (!context.mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Opening in Spotify…')));

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Spotify link.')),
          );
        }
      }
    }
  }

  Future<void> _logStreamCount({
    required String jwtToken,
    required String type,
    int? audioId,
    String? spotifyId,
  }) async {
    try {
      final position = await locationServices.getUserPosition();
      await streamServices.sendStream(
        jwtToken,
        position: position,
        audioId: audioId,
        spotifyId: spotifyId,
        type: type,
      );
    } catch (e, stackTrace) {
      log.e('[Flutter] Failed to log stream: $e $stackTrace');
    }
  }
}
