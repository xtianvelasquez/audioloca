class MediaMetadata {
  final String? url;
  final String title;
  final String subtitle;
  final String imageUrl;

  const MediaMetadata({
    this.url,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });
}

class PlayerStateInfo {
  final bool playing;
  const PlayerStateInfo({required this.playing});
}

class PlaybackStateData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final PlayerStateInfo playerState;

  const PlaybackStateData({
    required this.position,
    required this.bufferedPosition,
    required this.duration,
    required this.playerState,
  });
}
