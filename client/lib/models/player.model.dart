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
