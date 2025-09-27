class SpotifyTrack {
  final String id;
  final String name;
  final String artist;
  final String? previewUrl;
  final String externalUrl;
  final String? albumImageUrl;
  final int durationMs;

  // Local enrichment
  final int? streamCount;
  final String? type;

  SpotifyTrack({
    required this.id,
    required this.name,
    required this.artist,
    required this.previewUrl,
    required this.externalUrl,
    required this.albumImageUrl,
    required this.durationMs,
    this.streamCount,
    this.type,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    return SpotifyTrack(
      id: json['id'] ?? json['spotify_id'], // support both formats
      name: json['name'] ?? '',
      artist: (json['artists'] != null)
          ? (json['artists'] as List).map((a) => a['name']).join(', ')
          : '',
      previewUrl: json['preview_url'],
      externalUrl: json['external_urls']?['spotify'] ?? '',
      albumImageUrl:
          (json['album']?['images'] != null &&
              (json['album']['images'] as List).isNotEmpty)
          ? json['album']['images'][0]['url']
          : null,
      durationMs: json['duration_ms'] ?? 0,
      streamCount: json['stream_count'], // from local DB
      type: json['type'], // from local DB
    );
  }
}
