class AudioType {
  final int audioTypeId;
  final String typeName;

  AudioType({required this.audioTypeId, required this.typeName});

  factory AudioType.fromJson(Map<String, dynamic> json) {
    return AudioType(
      audioTypeId: json['audio_type_id'],
      typeName: json['type_name'],
    );
  }
}

class Audio {
  final int audioTypeId;
  final int albumId;
  final int emotionId;
  final String visibility;
  final String audioTitle;
  final String description;
  final String duration;
  final String? audioPhoto;
  final String? audioRecord;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Audio({
    required this.audioTypeId,
    required this.albumId,
    required this.emotionId,
    required this.visibility,
    required this.audioTitle,
    required this.description,
    required this.duration,
    required this.audioPhoto,
    required this.audioRecord,
    required this.createdAt,
    required this.modifiedAt,
  });

  factory Audio.fromJson(Map<String, dynamic> json) {
    return Audio(
      audioTypeId: json['audio_type_id'],
      albumId: json['album_id'],
      emotionId: json['emotion_id'],
      visibility: json['visibility'],
      audioTitle: json['audio_title'],
      description: json['description'],
      duration: json['duration'],
      audioPhoto: json['audio_photo'],
      audioRecord: json['audio_record'],
      createdAt: DateTime.parse(json['created_at']),
      modifiedAt: DateTime.parse(json['modified_at']),
    );
  }
}
