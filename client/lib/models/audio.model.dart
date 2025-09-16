class Audio {
  final int genreId;
  final int albumId;
  final String visibility;
  final String? audioRecord;
  final String audioTitle;
  final String description;
  final String duration;
  final int audioId;
  final String username;
  final String albumCover;
  final int streamCount;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Audio({
    required this.genreId,
    required this.albumId,
    required this.visibility,
    required this.audioRecord,
    required this.audioTitle,
    required this.description,
    required this.duration,
    required this.audioId,
    required this.username,
    required this.albumCover,
    required this.streamCount,
    required this.createdAt,
    required this.modifiedAt,
  });

  factory Audio.fromJson(Map<String, dynamic> json) {
    return Audio(
      genreId: json['genre_id'],
      albumId: json['album_id'],
      visibility: json['visibility'],
      audioRecord: json['audio_record'],
      audioTitle: json['audio_title'],
      description: json['description'],
      duration: json['duration'],
      audioId: json['audio_id'],
      username: json['username'],
      albumCover: json['album_cover'],
      streamCount: json['stream_count'],
      createdAt: DateTime.parse(json['created_at']),
      modifiedAt: DateTime.parse(json['modified_at']),
    );
  }
}

class LocalAudioLocation {
  final int audioId;
  final String username;
  final String albumCover;
  final int streamCount;
  final int albumId;
  final String? audioRecord;
  final String audioTitle;
  final String description;
  final String duration;
  final String type;

  LocalAudioLocation({
    required this.audioId,
    required this.username,
    required this.albumCover,
    required this.streamCount,
    required this.albumId,
    required this.audioRecord,
    required this.audioTitle,
    required this.description,
    required this.duration,
    required this.type,
  });

  factory LocalAudioLocation.fromJson(Map<String, dynamic> json) {
    return LocalAudioLocation(
      audioId: json['audio_id'],
      username: json['username'],
      albumCover: json['album_cover'],
      streamCount: json['stream_count'],
      albumId: json['album_id'],
      audioRecord: json['audio_record'],
      audioTitle: json['audio_title'],
      description: json['description'],
      duration: json['duration'],
      type: json['type'],
    );
  }
}

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
