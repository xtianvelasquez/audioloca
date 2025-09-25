class SpotifyAudioLocation {
  final String spotifyId;
  final int streamCount;
  final String type;

  SpotifyAudioLocation({
    required this.spotifyId,
    required this.streamCount,
    required this.type,
  });

  factory SpotifyAudioLocation.fromJson(Map<String, dynamic> json) {
    return SpotifyAudioLocation(
      spotifyId: json['spotify_id'],
      streamCount: json['stream_count'],
      type: json['type'],
    );
  }
}

class SpotifyTrack {
  final String id;
  final String name;
  final String artist;
  final String? previewUrl;
  final String externalUrl;
  final String? albumImageUrl;
  final int durationMs;

  SpotifyTrack({
    required this.id,
    required this.name,
    required this.artist,
    required this.previewUrl,
    required this.externalUrl,
    required this.albumImageUrl,
    required this.durationMs,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    return SpotifyTrack(
      id: json['id'],
      name: json['name'],
      artist: (json['artists'] as List)
          .map((artist) => artist['name'])
          .join(', '),
      previewUrl: json['preview_url'],
      externalUrl: json['external_urls']['spotify'],
      albumImageUrl:
          (json['album']['images'] != null &&
              (json['album']['images'] as List).isNotEmpty)
          ? json['album']['images'][0]['url']
          : null,
      durationMs: json['duration_ms'],
    );
  }
}
