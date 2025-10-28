class Album {
  final int albumId;
  final String albumName;
  final String? albumCover;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Album({
    required this.albumId,
    required this.albumName,
    required this.albumCover,
    required this.createdAt,
    required this.modifiedAt,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      albumId: json['album_id'] ?? 0,
      albumName: json['album_name'] ?? '',
      albumCover: json['album_cover'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.fromMillisecondsSinceEpoch(0),
      modifiedAt: json['modified_at'] != null
          ? DateTime.parse(json['modified_at'])
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
  static Album empty() {
    return Album(
      albumId: 0,
      albumName: '',
      albumCover: null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
