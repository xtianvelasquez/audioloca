import 'package:audioloca/local/models/genres.model.dart';

class Audio {
  final List<Genres> genres;
  final int albumId;
  final String visibility;
  final String? audioRecord;
  final String audioTitle;
  final String duration;
  final int audioId;
  final String username;
  final String albumCover;
  final int streamCount;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Audio({
    required this.genres,
    required this.albumId,
    required this.visibility,
    required this.audioRecord,
    required this.audioTitle,
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
      genres: (json['genres'] as List<dynamic>)
          .map((g) => Genres.fromJson(g))
          .toList(),
      albumId: json['album_id'],
      visibility: json['visibility'],
      audioRecord: json['audio_record'],
      audioTitle: json['audio_title'],
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
      duration: json['duration'],
      type: json['type'],
    );
  }
}
