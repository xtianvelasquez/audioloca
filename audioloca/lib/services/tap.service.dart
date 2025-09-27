import 'package:geolocator/geolocator.dart';
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

class TapServices {
  Future<void> handleLocalTrackTap(
    Audio audio,
    BuildContext context,
    bool mounted,
  ) async {
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

      final jwtToken = await storage.getJwtToken();
      if (jwtToken != null) {
        if (!context.mounted) return;

        final locationReady = await locationServices.ensureLocationReady(
          context,
        );
        if (!locationReady) {
          log.w('[Flutter] Location not ready. Skipping stream logging.');
          return;
        }

        Position position;
        try {
          position = await locationServices.getUserPosition();
        } catch (e, stackTrace) {
          log.e('[Flutter] Failed to get position: $e $stackTrace');
          return;
        }

        await streamServices.sendStream(
          jwtToken,
          position: position,
          audioId: audio.audioId,
          type: "local",
        );
      }
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
    final spotify = SpotifyPlayerService();
    final manager = NowPlayingManager();
    final uri = 'spotify:track:${track.id}';

    bool shouldSendStream = false;

    try {
      await spotify.playTrackUri(
        spotifyUri: uri,
        title: track.name,
        subtitle: track.artist,
        imageUrl: imageUrl ?? '',
      );
      manager.useSpotify();
      shouldSendStream = true;
    } catch (e) {
      if (track.previewUrl != null) {
        await LocalPlayerService().playFromUrl(
          url: track.previewUrl!,
          title: track.name,
          subtitle: track.artist,
          imageUrl: imageUrl ?? '',
        );
        manager.useLocal();
        shouldSendStream = true;
      } else {
        final uri = Uri.parse(track.externalUrl);
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to play. Opening in Spotify…')),
        );

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          shouldSendStream = true;
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Spotify link.')),
          );
        }
      }
    }

    if (shouldSendStream && context.mounted) {
      final jwtToken = await storage.getAccessToken();
      if (jwtToken != null) {
        if (!context.mounted) return;

        final locationReady = await locationServices.ensureLocationReady(
          context,
        );
        if (!locationReady) {
          log.w('[Flutter] Location not ready. Skipping stream logging.');
          return;
        }

        Position position;
        try {
          position = await locationServices.getUserPosition();
        } catch (e, stackTrace) {
          log.e('[Flutter] Failed to get position: $e $stackTrace');
          return;
        }

        await streamServices.sendStream(
          jwtToken,
          position: position,
          spotifyId: track.id,
          type: "spotify",
        );
      }
    }
  }
}
