import 'package:audioloca/local/models/genres.model.dart';

class Audio {
  final List<Genres>? genres; // Optional for local
  final int albumId;
  final String? visibility; // Optional for local
  final String? audioRecord;
  final String audioTitle;
  final String duration;
  final int audioId;
  final String username;
  final String albumCover;
  final int streamCount;
  final DateTime? createdAt; // Optional for local
  final DateTime? modifiedAt; // Optional for local
  final String? type; // "local", "remote", etc.

  Audio({
    this.genres,
    required this.albumId,
    this.visibility,
    required this.audioRecord,
    required this.audioTitle,
    required this.duration,
    required this.audioId,
    required this.username,
    required this.albumCover,
    required this.streamCount,
    this.createdAt,
    this.modifiedAt,
    this.type,
  });

  factory Audio.fromJson(Map<String, dynamic> json) {
    return Audio(
      genres: json['genres'] != null
          ? (json['genres'] as List<dynamic>)
                .map((g) => Genres.fromJson(g))
                .toList()
          : null,
      albumId: json['album_id'],
      visibility: json['visibility'],
      audioRecord: json['audio_record'],
      audioTitle: json['audio_title'],
      duration: json['duration'],
      audioId: json['audio_id'],
      username: json['username'],
      albumCover: json['album_cover'],
      streamCount: json['stream_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      modifiedAt: json['modified_at'] != null
          ? DateTime.parse(json['modified_at'])
          : null,
      type: json['type'],
    );
  }
}
